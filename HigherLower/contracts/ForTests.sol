//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

contract Test {

    using Address for address payable;

    uint256 treasury;

    address owner;
    uint256 public percentageForOwner;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;

    uint256 public currentRound;
    uint256 timeToWait = 90 seconds;

    enum Price {HIGHER, LOWER, EQUAL}

    struct Round {
        uint256 totalPool;

        uint256 startPrice;
        uint256 endPrice;

        uint256 createdAt;

        Price higherOrLower;

        address[] higher;
        address[] lower;
    }

    mapping(uint256 => Round) public rounds;

    event CreateRound(uint256 id, uint256 startPrice);
    event EnterRound(address indexed player, uint256 bet, Price higherOrLower);
    event CloseRound(uint256 id, uint256 endPrice, Price higherOrLower);

    constructor(uint256 _percentageForOwner) {
        percentageForOwner = _percentageForOwner;
        owner = msg.sender;
    }

    function createRound() external onlyOwner {
        require(rounds[currentRound].startPrice == 0, "Previous round has not been ended");
        rounds[currentRound].startPrice = 250;
        rounds[currentRound].createdAt = block.timestamp;

        emit CreateRound(currentRound, rounds[currentRound].startPrice);
    }

    function enterRound(Price _decision) external payable checkSender {
        //require(rounds[currentRound].createdAt + timeToWait > block.timestamp, "Bets are closed");
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");

        rounds[currentRound].totalPool += msg.value;
        if(Price(0) == _decision) rounds[currentRound].higher.push(msg.sender);
        if(Price(1) == _decision) rounds[currentRound].lower.push(msg.sender);

        emit EnterRound(msg.sender, msg.value, _decision);
    }

    function closeRound() external onlyOwner {
        //require(rounds[currentRound].createdAt + timeToWait < block.timestamp, "You can not start the round now");

        rounds[currentRound].endPrice = 300;

        uint256 commision = rounds[currentRound].totalPool / 100 * percentageForOwner;
        uint256 moneyLeft = rounds[currentRound].totalPool - commision;

        address[] memory winners;

        payable(owner).sendValue(commision);

        if(rounds[currentRound].endPrice > rounds[currentRound].startPrice) {
            winners = rounds[currentRound].higher;
            rounds[currentRound].higherOrLower = Price(0);
        } 
        if(rounds[currentRound].endPrice < rounds[currentRound].startPrice) {
            winners = rounds[currentRound].lower;
            rounds[currentRound].higherOrLower = Price(1);
        }
        if(rounds[currentRound].endPrice == rounds[currentRound].startPrice) {
            treasury += rounds[currentRound].totalPool;
        }

        for(uint256 i = 0; i < winners.length; i++) {
            payable(winners[i]).sendValue(moneyLeft / winners.length);
        }

        emit CloseRound(currentRound, rounds[currentRound].endPrice, rounds[currentRound].higherOrLower);

        unchecked {
            currentRound++;
        }
    }

    function getFromTreasury(uint256 _amount) external onlyOwner {
        require(_amount <= treasury, "The amount for getting is too high");
        treasury -= _amount;
        payable(owner).sendValue(_amount);
    }

    modifier checkSender {
        require(msg.sender != address(0), "This account does not exist");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

}