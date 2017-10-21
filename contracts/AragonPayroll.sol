pragma solidity ^0.4.11;

import "./Calendar.sol";

// For the sake of simplicity lets assume USD is a ERC20 token
// Also lets assume we can 100% trust the exchange rate oracle
contract PayrollInterface {
  /* OWNER ONLY */
  function addEmployee(address accountAddress, address[] acceptedTokens, uint256[] salaryAllocationByToken, uint256 initialYearlyUSDSalary);

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary);
  function removeEmployee(uint256 employeeId);

  function addFunds() payable;
  function scapeHatch();
  // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

  function getEmployeeCount() constant returns (uint256);
  function getEmployee(uint256 employeeId) constant returns (address employee, address[] employeeTokens, uint256[] salaryAllocationByToken, uint256 yearlyUSDSalary, uint256 lastPayment, uint256 lastTokenAllocation); // Return all important info too

  function calculatePayrollBurnrate() constant returns (uint256); // Monthly usd amount spent in salaries
  function calculatePayrollRunway() constant returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution); // only callable once every 6 months
  function payday(); // only callable once a month

  /* ORACLE ONLY */
  function setExchangeRate(address token, uint256 usdExchangeRate); // uses decimals from token
}

contract ERC20 {
    function totalSupply() public constant returns (uint supply);
    function balanceOf(address _owner) public constant returns (uint balance);
    function transfer(address _to, uint _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint _value) public returns (bool success);
    function approve(address _spender, uint _value) public returns (bool success);
    function allowance(address _owner, address _spender) public constant returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract AragonPayroll is PayrollInterface {
    address owner;
    struct Employee{
        address accountAddress;
        address[] acceptedTokens;
        uint256[] salaryAllocationByToken;
        uint256 yearlyUSDSalary;
        uint256 lastPayment;
        uint256 lastTokenAllocation;
    }

    mapping (uint256 => Employee) employees;
    mapping (address => uint256) employees_id;
    uint256[] public nextAvailableId = [0];
    uint256 numberOfEmployees = 0;
    address[] allowedTokens;
    mapping(address => uint256) exchangeRates;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function isTokenAlreadyAvailable(address token) private constant returns (bool){
        for (uint i = 0; i < allowedTokens.length; ++i)
            if (allowedTokens[i] == token)
                return true;
        return false;
    }

    function scapeHatch() public {
        // Pass all the token funds to the owner
        for (uint i = 0; i < allowedTokens.length; ++i)
        {
          ERC20 token = ERC20(allowedTokens[i]);
          uint256 tokenBalance = token.balanceOf(this);
          token.transfer(owner, tokenBalance);
        }
        selfdestruct(owner);
    }

    function addToken(address token) public onlyOwner {
        require(isTokenAlreadyAvailable(token) == false);
        allowedTokens.push(token);
    }
    function AragonPayroll() public {
        owner = msg.sender;
    }

    function isSalaryAllocationCorrect(uint256[] salaryAllocationByToken) private constant returns (bool){
        uint256 sum = 0;
        for (uint256 i = 0; i < salaryAllocationByToken.length;++i){
            sum += salaryAllocationByToken[i];
            if (sum > 100) return false;
        }
        return true;
    }
    function addEmployee(address accountAddress, address[] acceptedTokens, uint256[] salaryAllocationByToken, uint256 initialYearlyUSDSalary) public onlyOwner {
        require(isSalaryAllocationCorrect(salaryAllocationByToken) == true);
        uint256 newEmployeeId = nextAvailableId[nextAvailableId.length-1];
        employees[newEmployeeId] = Employee(accountAddress, acceptedTokens, salaryAllocationByToken, initialYearlyUSDSalary, 0, now);
        employees_id[accountAddress] = newEmployeeId;
        if (nextAvailableId.length == 1 /* We have consumed the last available id*/)
            nextAvailableId[0] = nextAvailableId[0] + 1;
        else
            nextAvailableId.length -= 1;
        numberOfEmployees++;
    }
    function removeEmployee(uint256 employeeId) public onlyOwner {
        delete employees[employeeId];
        nextAvailableId.push(employeeId);
        numberOfEmployees--;
    }

    function getEmployee(uint256 employeeId) public constant returns (address employee, address[] employeeTokens, uint256[] salaryAllocationByToken, uint256 yearlyUSDSalary, uint256 lastPayment, uint256 lastTokenAllocation){
        return (employees[employeeId].accountAddress, employees[employeeId].acceptedTokens, employees[employeeId].salaryAllocationByToken, employees[employeeId].yearlyUSDSalary, employees[employeeId].lastPayment, employees[employeeId].lastTokenAllocation);
    }

    function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public onlyOwner{
        employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
    }

    function getEmployeeCount() public constant returns (uint256) {
        return numberOfEmployees;
    }

    function addFunds() public payable{}

    function calculatePayrollBurnrate() public constant returns (uint256) {
        uint256 toPayEveryMonthInUSD = 0;
        for (uint i = 0; i < numberOfEmployees; ++i){
            toPayEveryMonthInUSD += employees[i].yearlyUSDSalary/12;
        }
        return toPayEveryMonthInUSD;
    }

    function monthlySalaryInToken(uint256 empl, uint256 tokenIndex) public constant returns (uint256){
        Employee memory employee = employees[empl];
        address token = employee.acceptedTokens[tokenIndex];
        return employee.yearlyUSDSalary/12 * employee.salaryAllocationByToken[tokenIndex]/100*exchangeRates[token];
    }
    function accumulativeHavings(uint256 empl, uint256 token) public constant returns (uint256){
        Employee memory employee = employees[empl];
        if (employee.lastPayment == 0)
          return monthlySalaryInToken(empl, token);
        return Calendar.getDistanceInMonth(employee.lastPayment, now) * monthlySalaryInToken(empl, token);
    }

    function calculateTokenPayrollRunway(address token) private constant returns (uint256){
        uint256 tokenBalance = ERC20(token).balanceOf(this);

        uint256 partialPayments = 0;
        for (uint i = 0; i < numberOfEmployees; ++i){
            for (uint j = 0; j < employees[i].acceptedTokens.length; ++j){
                address empl_token = employees[i].acceptedTokens[j];
                if (empl_token == token)
                    partialPayments += accumulativeHavings(employees_id[employees[i].accountAddress], j);
            }
        }

        tokenBalance -= partialPayments;
        if (tokenBalance <= 0) return 0; // We are in danger. Employees can execute payday today and let the contract out of funds

        // After we have calculated all employees havings, we forecast monthly payments
        uint256 totalToBePaidMonthly = 0;
        for (i = 0; i < numberOfEmployees; ++i){
            for (j = 0; j < employees[i].acceptedTokens.length; ++j){
                empl_token = employees[i].acceptedTokens[j];
                if (empl_token == token)
                    totalToBePaidMonthly += monthlySalaryInToken(employees_id[employees[i].accountAddress], j);
            }
        }

        require (totalToBePaidMonthly > 0);
        uint256 numberOfMonths = tokenBalance / totalToBePaidMonthly + 1;
        return convertMonthToDaysFromNow(numberOfMonths);
    }

    function convertMonthToDaysFromNow(uint256 numberOfMonths) private constant returns (uint256){
      uint256 daysCurrentMonth = Calendar.getDaysInMonth(Calendar.getMonth(now), Calendar.getYear(now));
      uint256 daysTillTheEndOfMonth = daysCurrentMonth - Calendar.getDay(now);

      var monthsLeft = (Calendar.getMonth(now)-1 + numberOfMonths);
      uint8 monthWhenOutOfFundsWillOccur = (uint8)(monthsLeft%12 + 1);
      uint16 yearWhenOutOfFundsWillOccur =  (uint16)(Calendar.getYear(now) + ((Calendar.getMonth(now)-1 + numberOfMonths)/12));

      // Returns distanceOnDays from the 1 of the next month to the 1 of the out of funds month
      return daysTillTheEndOfMonth + Calendar.distanceOnDays(now + daysTillTheEndOfMonth*24*60*60, Calendar.toTimestamp(yearWhenOutOfFundsWillOccur, monthWhenOutOfFundsWillOccur, 1));
    }

    function calculatePayrollRunway() public constant returns (uint256) {
        uint256 minimumDays = 0;
        bool first = true;
        for  (uint i = 0; i < allowedTokens.length; ++i){
            uint256 daysTillRunway = calculateTokenPayrollRunway(allowedTokens[i]);
            if (daysTillRunway < minimumDays || first)
                minimumDays = daysTillRunway;
            first = false;
        }
        return minimumDays;
    }

    function payday() public {
        uint employee_id = employees_id[msg.sender];
        uint lastPayment = employees[employee_id].lastPayment;
        bool yearChange = Calendar.getYear(now) > Calendar.getYear(lastPayment);
        uint currentMonth = Calendar.getMonth(now);
        if (yearChange)
          currentMonth += 12;
        uint monthDistance = Calendar.getDistanceInMonth(lastPayment, now);
        if (monthDistance == 0) return;
        for (uint i = 0; i < employees[employee_id].acceptedTokens.length; ++i){
            ERC20 token = ERC20(allowedTokens[i]);
            uint256 totalToBePaid = accumulativeHavings(employee_id, i);
            token.transfer(msg.sender, totalToBePaid);
        }
        employees[employee_id].lastPayment = now;
    } // only callable once a month

    function determineAllocation(address[] tokens, uint256[] distribution)  public {
      uint employee_id = employees_id[msg.sender];
      uint lastPayment = employees[employee_id].lastPayment;
      bool yearChange = Calendar.getYear(now) > Calendar.getYear(lastPayment);
      uint currentMonth = Calendar.getMonth(now);
      if (yearChange)
        currentMonth += 12;
      uint monthDistance = Calendar.getDistanceInMonth(lastPayment, now);
      if (monthDistance < 6) return;
      employees[employee_id].acceptedTokens = tokens;
      employees[employee_id].salaryAllocationByToken = distribution;
    }

    function setExchangeRate(address token, uint256 usdExchangeRate) public{
      // The rate is multiplied by 100, ie, if 1 ETH == 340USD => usdExchangeRate = 34000
      exchangeRates[token] = usdExchangeRate;
    }

    function addTokens(address[] tokens) public {
      for (uint i = 0;i < tokens.length; ++i){
          allowedTokens.push(tokens[i]);
      }
    }
}
