const RouletteTest = artifacts.require("RouletteTest");
const truffle = require("truffle-assertions");

contract("RouletteTest", (accounts) => {
    let roulette = null;
    beforeEach(async() => {
        roulette = await RouletteTest.new(10);
    });

    it("Should create roulette only by the owner", async() => {
        await truffle.reverts(roulette.createRound({from: accounts[1]}), "You are not the owner");

        await roulette.createRound();
        let round = await roulette.rounds(0);

        assert.equal(round.winColor, 0);
    });

    it("Should check bet", async() => {
        await roulette.createRound();

        await truffle.reverts(roulette.enterRound(0, {value: web3.utils.toWei('0.0049', 'ether')}), "Your bet is not correct");
        await truffle.reverts(roulette.enterRound(0, {value: web3.utils.toWei('1001', 'ether')}), "Your bet is not correct");
    });

    it("Should enter round and increase pool", async() => {
        await roulette.createRound();

        let balanceBefore = await web3.eth.getBalance(accounts[1]);
        
        await roulette.enterRound(0, {from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        let round = await roulette.rounds(0);
        let pool = await web3.utils.fromWei(round.pool.toString(), 'ether');

        let balanceAfter = await web3.eth.getBalance(accounts[1]);
        let diff = balanceBefore - balanceAfter;

        assert.equal(pool, 1);
        assert.equal(Math.round(await web3.utils.fromWei(diff.toString(), 'ether')), 1);
    });

    it("Should start the game by the owner and pay owner and winners", async() => {
        await roulette.createRound();

        await roulette.enterRound(0, {from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        await roulette.enterRound(1, {from: accounts[2], value: web3.utils.toWei('1', 'ether')});
        await roulette.enterRound(2, {from: accounts[3], value: web3.utils.toWei('1', 'ether')});

        let ownerBefore = await web3.eth.getBalance(accounts[0]);
        let winnerBefore = await web3.eth.getBalance(accounts[2]);

        await truffle.reverts(roulette.closeRound({from: accounts[4]}), "You are not the owner");
        await roulette.closeRound();

        let percentage = await roulette.percentageForOwner();
        percentage = percentage.toNumber();

        let round = await roulette.rounds(0);
        let pool = await web3.utils.fromWei(round.pool.toString(), 'ether');

        let ownerAfter = await web3.eth.getBalance(accounts[0]);
        let winnerAfter = await web3.eth.getBalance(accounts[2]);

        let owner = await web3.utils.fromWei((ownerAfter - ownerBefore).toString(), 'ether');
        let winner = await web3.utils.fromWei((winnerAfter - winnerBefore).toString(), 'ether');

        assert.equal(Math.round(owner * 10) / 10, pool / 100 * percentage);
        assert.equal(Math.round(winner * 10) / 10, pool - pool / 100 * percentage);
    });
});