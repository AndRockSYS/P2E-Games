const Test = artifacts.require('Test');
const truffle = require('truffle-assertions');

contract('ColorWheel', (accounts) => {
    let wheel;

    beforeEach(async() => {
        wheel = await Test.new(10)
    });

    it('Should create round only by the owner', async() => {
        await truffle.reverts(wheel.createRound({from: accounts[1]}), 'You are not the owner');

        await wheel.createRound();

        let round = await wheel.rounds(0);
        let time = round.createdAt;
        time = time.toNumber();
        
        assert.notEqual(time, 0);
    });

    it('Should allow only correct bets and enter only at allowed time', async() => {
        await wheel.createRound();

        await truffle.reverts(wheel.enterRound(0, {value: web3.utils.toWei('0.0049', 'ether')}), 'Your bet is not correct');
        await truffle.reverts(wheel.enterRound(0, {value: web3.utils.toWei('1001', 'ether')}), 'Your bet is not correct');

        await new Promise(resolve => setTimeout(() => resolve(), 3500));
        await truffle.reverts(wheel.enterRound(0), 'Bets are closed');
    });

    it('Should close round only by the owner and after specific amount of time', async() => {
        await wheel.createRound();

        await truffle.reverts(wheel.closeRound(0), 'You can not close wheel now');
        await truffle.reverts(wheel.closeRound(0, {from: accounts[1]}), 'You are not the owner');

        await new Promise(resolve => setTimeout(() => resolve(), 3500));
        await wheel.closeRound(0);
    });

    it(`Should decrease plyer's balance after bet add pool to the treasury if no one is winner`, async() => {
        await wheel.createRound();

        await wheel.enterRound(0, {from: accounts[0], value: web3.utils.toWei('1', 'ether')});

        await new Promise(resolve => setTimeout(() => resolve(), 3500));

        let round = await wheel.rounds(0);
        let pool = round.totalPool;
        pool = web3.utils.fromWei(pool, 'ether');

        await wheel.closeRound(0);

        let treasury = await wheel.treasury();
        treasury = web3.utils.fromWei(treasury, 'ether');

        assert.equal(treasury, 1);
        assert.equal(pool, 1);
    });

    it('Should end the game and pay to the winner and owner', async() => {
        await wheel.createRound();

        await wheel.enterRound(0, {from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        await wheel.enterRound(1, {from: accounts[2], value: web3.utils.toWei('1', 'ether')});

        let ownerBefore = await web3.eth.getBalance(accounts[0]);
        let winnerBefore = await web3.eth.getBalance(accounts[1]);

        await new Promise(resolve => setTimeout(() => resolve(), 3500));
        await wheel.closeRound(158);

        let ownerAfter = await web3.eth.getBalance(accounts[0]);
        let winnerAfter = await web3.eth.getBalance(accounts[1]);

        let owner = web3.utils.fromWei((ownerAfter-ownerBefore).toString(), 'ether');
        let winner = web3.utils.fromWei((winnerAfter-winnerBefore).toString(), 'ether');

        assert.equal(Math.round(owner * 10) / 10, 0.2);
        assert.equal(Math.round(winner * 10) / 10, 1.8);
    });
});
