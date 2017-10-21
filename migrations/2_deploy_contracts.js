var Calendar = artifacts.require("./Calendar");
var AragonPayroll = artifacts.require("./AragonPayroll");
var USDToken = artifacts.require("./USDToken");
var ETHToken = artifacts.require("./ETHToken");

module.exports = function(deployer) {
  deployer.deploy(Calendar);
  deployer.link(Calendar, AragonPayroll);
  deployer.deploy(USDToken);
  deployer.deploy(ETHToken);
  deployer.deploy(AragonPayroll);
};
