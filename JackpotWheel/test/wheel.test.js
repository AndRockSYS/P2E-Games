const WheelTest = artifacts.require("WheelTest");
const truffle = require("truffle-assertions");

contract("WheelTest", (accounts) => {
    let wheel = null;
    beforeEach(async() => {
        wheel = await WheelTest.new(10);
    });

    it("Should create new wheel by the owner only", async() => {
        await truffle.reverts(wheel.createWheel({from: accounts[1]}), "You are not the owner");
        await wheel.createWheel({from: accounts[0]});

        let round = await wheel.currentRound();
        let spin = await wheel.spins(round.toNumber());

        assert.equal(spin.hasEnded, false);
        assert.equal(spin.winner, 0x0000000000000000000000000000000000000000);
    });

    it("Should enter the wheel while only bet is correct", async() => {
        await truffle.reverts(wheel.enterWheel({value: web3.utils.toWei('0.0049','ether')}), "Your bet is too low or too high");
        await truffle.reverts(wheel.enterWheel({value: web3.utils.toWei('1001','ether')}), "Your bet is too low or too high");
    });

    it("Should enter the wheel and increase total pool", async() => {
        await wheel.createWheel({from: accounts[0]});

        let balanceBefore = await web3.eth.getBalance(accounts[1]);

        await wheel.enterWheel({from: accounts[1], value: web3.utils.toWei('1','ether')});

        let round = await wheel.currentRound();
        let spin = await wheel.spins(round.toNumber());

        let balanceAfter = await web3.eth.getBalance(accounts[1]);
        let dif = balanceBefore - balanceAfter;

        assert.equal(spin.totalPool, web3.utils.toWei('1','ether'));
        assert.equal(Math.round(await web3.utils.fromWei(dif.toString(), 'ether')), 1);
    });

    it("Should close the wheel by the owner and increase owner and winner balances", async() => {
        await wheel.createWheel({from: accounts[0]});

        await wheel.enterWheel({from: accounts[1], value: web3.utils.toWei('1','ether')});
        await wheel.enterWheel({from: accounts[2], value: web3.utils.toWei('1','ether')});
        await wheel.enterWheel({from: accounts[3], value: web3.utils.toWei('1','ether')});

        let balanceBefore = await web3.eth.getBalance(accounts[1]);
        let ownerBefore = await web3.eth.getBalance(accounts[0]);

        let round = await wheel.currentRound();

        await truffle.reverts(wheel.closeWheel({from: accounts[1]}), "You are not the owner");
        await wheel.closeWheel({from: accounts[0]});

        let balanceAfter = await web3.eth.getBalance(accounts[1]);
        let ownerAfter = await web3.eth.getBalance(accounts[0]);

        let playerDif = await web3.utils.fromWei((balanceAfter-balanceBefore).toString(), 'ether');
        let ownerDif = await web3.utils.fromWei((ownerAfter-ownerBefore).toString(), 'ether');

        let spin = await wheel.spins(round.toNumber());

        assert.equal(spin.hasEnded, true);
        assert.equal(spin.winner, accounts[1]);

        let percentage = await wheel.percentageForOwner();
        percentage = percentage.toNumber();
        let amountForOwner = 3/100*percentage;
        assert.equal(Math.round(ownerDif*10)/10, amountForOwner);

        let winAmount = 3 - amountForOwner;
        assert.equal(Math.round(playerDif*10)/10, winAmount);

        let loser = await web3.eth.getBalance(accounts[2]);
        let loserBalance = await web3.utils.fromWei(loser.toString(), 'ether');
        assert.equal(Math.round(loserBalance), 99);

        let loser2 = await web3.eth.getBalance(accounts[3]);
        let loser2Balance = await web3.utils.fromWei(loser2.toString(), 'ether');
        assert.equal(Math.round(loserBalance), Math.round(loser2Balance))
    });
});