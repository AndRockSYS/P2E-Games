const Duels = artifacts.require("Duels");

module.exports = function (deployer, accounts) {
  deployer.deploy(Duels, 10);
  accounts = web3.eth.getAccounts();
};