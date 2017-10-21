var AragonPayroll = artifacts.require("./AragonPayroll.sol");
var USDToken = artifacts.require("./USDToken.sol");
var ETHToken = artifacts.require("./ETHToken.sol");

contract('AragonPayroll', function(accounts) {
  var owner_account = accounts[0];
  it(" should add an employee", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      var USDToken = instance;
      return ETHToken.deployed();
    }).then(function(instance){
      var ETHToken = instance;
      return aragonPayroll.addEmployee("0x6825487b18c45c507d06b44ec2ba5b5bf3925f27", [USDToken.address, ETHToken.address],[50,50],100000, {from: owner_account})
    }).then(function(result) {
      return aragonPayroll.getEmployeeCount();
    }).then(function(numberOfEmployees){
      assert.equal(numberOfEmployees, 1);
    });
  });
  it(" should add an other employee and get the information from the first one", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      var USDToken = instance;
      return ETHToken.deployed();
    }).then(function(instance){
      var ETHToken = instance;
        return aragonPayroll.addEmployee("0x6825487b18c45c507d06b44ec2ba5b5bf3925f28", [USDToken.address, ETHToken.address],[25,75],100000, {from: owner_account})
    }).then(function() {
      return aragonPayroll.getEmployeeCount();
    }).then(function(numberOfEmployees){
      assert.equal(numberOfEmployees, 2);
      return aragonPayroll.getEmployee(0);
    }).then(function(result){
      assert.equal(result[0], "0x6825487b18c45c507d06b44ec2ba5b5bf3925f27");
    });
  });

  it(" shouldn't add an other employee because token allocation exceeds 100%", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      var USDToken = instance;
      return ETHToken.deployed();
    }).then(function(instance){
      var ETHToken = instance;
      return aragonPayroll.addEmployee("0x6825487b18c45c507d06b44ec2ba5b5bf3925f30", [USDToken.address, ETHToken.address],[26,75],100000, {from: owner_account})
    }).then(function() {
      return aragonPayroll.getEmployeeCount();
    }).then(function(numberOfEmployees){
      assert.equal(numberOfEmployees, 2);
    });
  });
  it(" should remove the first employee", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return aragonPayroll.removeEmployee(0, {from: owner_account})
    }).then(function(result) {
      return aragonPayroll.getEmployeeCount();
    }).then(function(numberOfEmployees){
      assert.equal(numberOfEmployees, 1);
    });
  });
  it(" should add a new employee with id 0", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      var USDToken = instance;
      return ETHToken.deployed();
    }).then(function(instance){
      var ETHToken = instance;
      return aragonPayroll.addEmployee("0x3b1dcdd52d595aa43b7df2ebf30b78d263da32a8", [USDToken.address, ETHToken.address],[75,25],100000, {from: owner_account})
    }).then(function(result) {
      return aragonPayroll.getEmployee(0);
    }).then(function(result){
      assert.equal(result[0], "0x3b1dcdd52d595aa43b7df2ebf30b78d263da32a8");
    });
  });
  it(" should change the salary of the employee with id 0", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return aragonPayroll.setEmployeeSalary(0, 120000, {from: owner_account})
    }).then(function(result) {
      return aragonPayroll.getEmployee(0);
    }).then(function(result){
      assert.equal(result[3].toString(), "120000");
    });
  });
  it(" should add funds to the contract", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      assert.equal(web3.eth.getBalance(aragonPayroll.address), 0);
      return aragonPayroll.addFunds({from: owner_account, value: web3.toWei(1000, "ether")})
    }).then(function(result) {
      assert.equal(web3.fromWei(web3.eth.getBalance(aragonPayroll.address), "ether").toString(), "1000");
    });
  });
  it(" should return the total amount expended in salaries every month (18333USD)", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return aragonPayroll.calculatePayrollBurnrate();
    }).then(function(result) {
      assert.equal(result, 18333);
    });
  });
  it(" should return the number of days till run out of funds", function() {
    var aragonPayroll;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      var USDToken = instance;
      return USDToken.mint(aragonPayroll.address, "200000")
    }).then(function(instance){
      return ETHToken.deployed();
    }).then(function(instance){
      var ETHToken = instance;
      return ETHToken.mint(aragonPayroll.address, "59000000000000000000")
    }).then(function(instance){
      return aragonPayroll.addTokens([USDToken.address, ETHToken.address]);
    }).then(function(){
      return aragonPayroll.setExchangeRate(USDToken.address,1);
    }).then(function(){
      return aragonPayroll.setExchangeRate(ETHToken.address,3333333333333333); // 300USD = 1 ETH =>  1 USD = 3333... Weis
    }).then(function(){
      return aragonPayroll.calculatePayrollRunway();
    }).then(function(result){
      var days=parseInt(result.toString())
      // Depending when this test is executed may differ
      assert.isTrue(days >= 38 && days <= 41);
    });
  });
  it(" should pay to employee with id 0 the first salary", function() {
    var aragonPayroll;
    var usd_token;
    var eth_token;
    return AragonPayroll.deployed().then(function(instance) {
      aragonPayroll =  instance;
      return USDToken.deployed();
    }).then(function(instance) {
      usd_token = instance;
      return usd_token.balanceOf(accounts[1])
    }).then(function(result){
      var initial_uds = parseInt(result.toString());
      assert.equal(initial_uds, 0);
      return ETHToken.deployed();
    }).then(function(instance) {
      eth_token = instance;
      return eth_token.balanceOf(accounts[1])
    }).then(function(result){
      var initial_eth = parseInt(result.toString());
      assert.equal(initial_eth, 0);
      return aragonPayroll.payday({from: accounts[1]});
    }).then(function(){
      return usd_token.balanceOf(accounts[1]);
    }).then(function(result){
        assert.equal(parseInt(result.toString()), 7500);
        return eth_token.balanceOf(accounts[1]);
    }).then(function(result){
        assert.equal(parseInt(result.toString()), 8333333333333333000);
    });
  });
});
