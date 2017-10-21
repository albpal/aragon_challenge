# Aragon Challenge
Truffle testing is very slow on a go client but all return OK. On a testrpc client, 3th test (shoudn't add an other employe...) fails because required() function returns an invalid op code (just ingnore it).

A valid command to run testrpc is:

```$ testrpc network-id 15 --unlock 0 --unlock 1 --account="0xac12fe17ec058f5028dd369a3fb0df657d5ed4e1b5faff19d78ea9c8c019fdd8,10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" --account="0x7e5606ea558aff0140ffef1fb817d1858a0daf5168c15fb1f371e1e378d1c2b2,10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"```

Public keys are:

        (0) 0x386f42f3d7eae2adc2cb7bba87ef1260d35bea4f
        
        (1) 0x3b1dcdd52d595aa43b7df2ebf30b78d263da32a8

Contract: AragonPayroll

    ✓  should add an employee (31862ms)
    
    ✓  should add an other employee and get the information from the first one (6760ms)
    
    ✓  shouldn't add an other employee because token allocation exceeds 100% (23281ms)
    
    ✓  should remove the first employee (1319ms)
    
    ✓  should add a new employee with id 0 (4472ms)
    
    ✓  should change the salary of the employee with id 0 (17385ms)
    
    ✓  should add funds to the contract (29557ms)

    ✓  should return the total amount expended in salaries every month (18333USD) (96ms)
    
    ✓  should return the number of days till run out of funds (157960ms)
    
    ✓  should pay to employee with id 0 the first salary (26856ms)


  10 passing (5m)
