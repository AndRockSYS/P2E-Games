const Duels = artifacts.require("Duels");
const truffleAssert = require('truffle-assertions');

contract("Duels", (accounts) => {
    let duels = null;
    beforeEach(async() => {
        duels = await Duels.new(10);
    });

    it("Should create lobby", async() => {
        let balanceBefore = await web3.eth.getBalance(accounts[0]);
        await duels.createLobby({from: accounts[0], value: web3.utils.toWei('1','ether')});
        let balanceAfter = await web3.eth.getBalance(accounts[0]);

        const lobby = await duels.lobbies(0);
        assert.equal(lobby[0], accounts[0]);
        assert.equal(lobby[1], 0x0000000000000000000000000000000000000000);
        assert.equal(lobby[2], web3.utils.toWei('1','ether'));

        assert.equal(Math.round(await web3.utils.fromWei((balanceBefore - balanceAfter).toString(), 'ether')),1);
        assert.equal(await web3.eth.getBalance(duels.address), web3.utils.toWei('1','ether'));
    });

    it("Should not create lobby if the bet is not correct", async() => {
        await truffleAssert.reverts(duels.createLobby({from: accounts[0], value: web3.utils.toWei('0.0049','ether')}), "Bet is too high or too low");
        await truffleAssert.reverts(duels.createLobby({from: accounts[0], value: web3.utils.toWei('1001','ether')}), "Bet is too high or too low");
    });

    it("Should close the lobby after specific period", async() => {
        let beforeCreating = await web3.eth.getBalance(accounts[1]);
        await duels.createLobby({from: accounts[1], value: web3.utils.toWei('1','ether')});

        await truffleAssert.reverts(duels.closeLobby(0, Math.floor(Date.now()/1000), {from: accounts[1]}), "You can not close it now");

        await truffleAssert.reverts(duels.closeLobby(0, Math.floor(Date.now()/1000), {from: accounts[2]}), "You are not the creator of the lobby");
        
        await new Promise(resolve => setTimeout(resolve, 4000));
        await duels.closeLobby(0, Math.floor(Date.now()/1000), {from: accounts[1]});
        let afterClosing = await web3.eth.getBalance(accounts[1]);

        await assert.equal(Math.round(await web3.utils.fromWei(beforeCreating.toString(), 'ether')), 
        Math.round(await web3.utils.fromWei(afterClosing.toString(), 'ether')));

        const lobby = await duels.lobbies(0);
        await assert.equal(lobby[0], 0x0000000000000000000000000000000000000000);
        await assert.equal(lobby[2], 0);
    });

    it("Should enter the lobby and do not allow others to join when this lobby is full", async() => {
        await duels.createLobby({from: accounts[0], value: web3.utils.toWei('1','ether')});
        await truffleAssert.reverts(duels.enterLobby(0, {from: accounts[1], value: web3.utils.toWei('2','ether')}), "Your bet is not correct");

        let balanceBefore = await web3.eth.getBalance(accounts[1]);

        await duels.enterLobby(0, {from: accounts[1], value: web3.utils.toWei('1','ether')})

        await truffleAssert.reverts(duels.enterLobby(0, {from: accounts[2], value: web3.utils.toWei('1','ether')}), "This lobby is full");

        let balanceAfter = await web3.eth.getBalance(accounts[1]);

        let duel = await duels.lobbies(0);
        assert.equal(duel[1], accounts[1]);
        assert.equal(duel[2], web3.utils.toWei('2','ether'));

        assert.equal(Math.round(await web3.utils.fromWei((balanceBefore - balanceAfter).toString(), 'ether')),1);
        assert.equal(await web3.eth.getBalance(duels.address), web3.utils.toWei('2','ether'));
    });

    it("Should revert if lobby is not full or start the game and pay the winner and the owner", async() => {
        await duels.createLobby({from: accounts[1], value: web3.utils.toWei('1','ether')});
        let beforeWinning = await web3.eth.getBalance(accounts[1]);

        await truffleAssert.reverts(duels.startTheGame(1), "The game can not start");

        await duels.enterLobby(0, {from: accounts[2], value: web3.utils.toWei('1','ether')})
        
        let ownerBefore = await web3.eth.getBalance(accounts[0]);
        await duels.startTheGame(0);

        let afterWinning = await web3.eth.getBalance(accounts[1]);
        let ownerAfter = await web3.eth.getBalance(accounts[0]);

        let percentage = await duels.percentageForOwner.call();
        let duel = await duels.lobbies(0);
        assert.equal(duel.winner, accounts[1]);
        assert.equal(await web3.utils.fromWei((afterWinning - beforeWinning).toString(), 'ether'), 2/100*(100-percentage));
        assert.equal(Math.round(await web3.utils.fromWei((ownerAfter - ownerBefore).toString(), 'ether')*10)/10, 2/100*percentage);
    });
});