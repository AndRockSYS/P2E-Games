//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

contract TicTacToe {

    using Address for address payable;

    address owner;
    uint256 percentageForOwner;
    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;

    uint256 timeToClose = 5 minutes;

    uint256 public totalGames;

    struct Game {
        address winner;

        address noughts;
        address crosses;

        uint256 totalPool;
        uint256 createdAt;
    }

    mapping(uint256 => Game) public games;

    event CreateGame(address indexed player, uint256 bet, uint256 gameId);
    event CloseGame(uint256 gameId);
    event EnterTheGame(address indexed player, uint256 bet, uint256 gameId);
    event Winner(address indexed winner, uint256 _winAmount, uint256 gameId);

    constructor(uint256 _percentageForOwner) {
        percentageForOwner = _percentageForOwner;
        owner = msg.sender;
    }

    function createGame(uint8 _sideToPlayFor) payable external checkSender {
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");
        require(_sideToPlayFor == 1 || _sideToPlayFor == 2, "The side was chosen incorect");

        games[totalGames].totalPool += msg.value;
        games[totalGames].createdAt += block.timestamp;

        _sideToPlayFor == 1 ? games[totalGames].noughts = msg.sender : games[totalGames].crosses = msg.sender;

        emit CreateGame(msg.sender, msg.value, totalGames);

        unchecked {
            totalGames++;
        }
    }

    function closeGame(uint256 _gameId) external checkSender {
        require(msg.sender == games[_gameId].noughts || msg.sender == games[_gameId].crosses, "You did not create that game");
        require(games[_gameId].createdAt + timeToClose < block.timestamp, "You can not close it now");

        uint256 payBack = games[_gameId].totalPool;
        games[_gameId].totalPool = 0;

        payable(msg.sender).sendValue(payBack);

        emit CloseGame(_gameId);
    }

    function enterGame(uint256 _gameId) payable external checkSender {
        require(games[_gameId].noughts == address(0) || games[_gameId].crosses == address(0), "This game is full");
        require(games[_gameId].noughts != address(0) || games[_gameId].crosses != address(0), "This game was not created");
        require(msg.value == games[_gameId].totalPool, "Your bet is not correct");

        games[_gameId].noughts == address(0) ? games[_gameId].noughts = msg.sender : games[_gameId].crosses = msg.sender;

        games[_gameId].totalPool += msg.value;

        emit EnterTheGame(msg.sender, msg.value, _gameId);
    }

    function winner(uint256 _gameId) external checkSender {
        require(games[_gameId].winner == address(0), "This game already has a winner");
        require(games[_gameId].noughts != address(0) && games[_gameId].crosses != address(0), "This lobby is not ready");
        require(msg.sender == games[_gameId].noughts || msg.sender == games[_gameId].crosses, "This is not your game");

        games[_gameId].winner = msg.sender;

        uint256 comission = games[_gameId].totalPool / 100 * percentageForOwner;

        payable(msg.sender).sendValue(games[_gameId].totalPool);
        payable(owner).sendValue(comission);

        emit Winner(msg.sender, games[_gameId].totalPool - comission, _gameId);
    }

    function technicalIssues(address _to, uint256 _amount) external checkSender{
        require(msg.sender == owner, "You are not the owner");
        require(_to != address(0), "The receiver isn't exist");
        require(_amount <= address(this).balance, "Amount to transfer is too big");

        payable(_to).sendValue(_amount);
    }

    modifier checkSender {
        require(msg.sender != address(0), "This account does not exist");
        _;
    }

}