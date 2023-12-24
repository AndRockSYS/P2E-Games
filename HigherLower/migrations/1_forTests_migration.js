const Test = artifacts.require('Test');

module.exports = (deployer, accounts) => {
    deployer.deploy(Test, 10);
    accounts = web3.eth.getAccounts();
}