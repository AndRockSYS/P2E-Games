const WheelTest = artifacts.require("WheelTest");

module.exports = function (deployer, accounts) {
    deployer.deploy(WheelTest, 10);
    accounts = web3.eth.getAccounts();
  };