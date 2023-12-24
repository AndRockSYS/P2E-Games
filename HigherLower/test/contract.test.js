const Test = artifacts.require('Test');
const truffle = require('truffle-assertions');

contract('HigherOrLower', (accounts) => {
    let hol;
    beforeEach(async () => {
        hol = await Test.new(10);
    });

    it('Should create new round by the owner only', async() => {
        await truffle.reverts(hol.createRound({from: accounts[1]}), "You are not the owner");
        
        await hol.createRound();
        let num = await hol.currentRound();
        num = num.toNumber();
        let round = await hol.rounds(num);

        assert.equal(round.startPrice, 250);
    });

    it('Should not enter the round with uncorrect bet', async() => {
        await hol.createRound();

        await truffle.reverts(hol.enterRound(0, {value: web3.utils.toWei('0.0049', 'ether')}), "Your bet is not correct");
        await truffle.reverts(hol.enterRound(0, {value: web3.utils.toWei('1001', 'ether')}), "Your bet is not correct");
    });

    it(`Should enter the lobby, add money to total pool and subtract money from player's balance`, async() => {
        await hol.createRound();

        let balanceBefore = await web3.eth.getBalance(accounts[0]);

        await hol.enterRound(0, {value: web3.utils.toWei('1', 'ether')});

        let balanceAfter = await web3.eth.getBalance(accounts[0]);
        let dif = balanceBefore - balanceAfter;
        dif = await web3.utils.fromWei(dif.toString(), 'ether');
        dif = Math.round(dif);

        let num = await hol.currentRound();
        num = num.toNumber();
        let round = await hol.rounds(num);

        assert.equal(round.totalPool, web3.utils.toWei('1','ether'));
        assert.equal(dif, 1);
    });

    it('Should close the lobby, pay to the winner and send comission to owner', async() => {
        await hol.createRound();

        await hol.enterRound(0, {from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        await hol.enterRound(1, {from: accounts[2], value: web3.utils.toWei('1', 'ether')});

        let ownerBefore = await web3.eth.getBalance(accounts[0]);
        let winnerBefore = await web3.eth.getBalance(accounts[1]);

        await hol.closeRound();

        let ownerAfter = await web3.eth.getBalance(accounts[0]);
        let winnerAfter = await web3.eth.getBalance(accounts[1]);

        let num = await hol.currentRound();
        num = num.toNumber();
        let round = await hol.rounds(num - 1);
        assert.equal(round.endPrice, 300);
        assert.equal(round.higherOrLower, 0);

        let ownerDif = await web3.utils.fromWei((ownerAfter-ownerBefore).toString(), 'ether');
        let winnerDif = await web3.utils.fromWei((winnerAfter-winnerBefore).toString(), 'ether');

        let percentage = await hol.percentageForOwner();
        percentage = percentage.toNumber();

        assert.equal(Math.round(ownerDif * 10) / 10, 2 / 100 * percentage);
        assert.equal(Math.round(winnerDif * 10) / 10, 2 - 2 / 100 * percentage );
    });
});