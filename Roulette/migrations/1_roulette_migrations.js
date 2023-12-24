const RouletteTest = artifacts.require("RouletteTest");

module.exports = (deployer, accounts) => {
    deployer.deploy (RouletteTest, 10);
    accounts = web3.eth.getAccounts();
}