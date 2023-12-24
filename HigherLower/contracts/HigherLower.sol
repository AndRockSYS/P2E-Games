//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "./chain.link/PriceConsumerV3.sol";

contract HigherLower {

    using Address for address payable;

    PriceConsumerV3 public GET_PRICE;

    uint256 treasury;

    address owner;
    uint256 percentageForOwner;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;

    uint256 public currentRound;
    uint256 timeToWait = 60 seconds; //time of a round; update price timer; price heartbeat

    enum Price {HIGHER, LOWER, EQUAL} //all possible variants of changing price

    struct Round {
        uint256 totalPool;

        uint80 priceRound; //current round of price (check PricConsumerV3.sol)
        uint256 startPrice; //price of cryptocurrency at the beginning of the round
        uint256 endPrice; //price of cryptocurrency at the end of the round

        uint256 createdAt;

        Price result;

        address[] higher;
        address[] lower;
    }

    mapping(uint256 => Round) public rounds;

    event CreateRound(uint256 id, uint256 startPrice);
    event EnterRound(address indexed player, uint256 bet, Price result);
    event CloseRound(uint256 id, uint256 endPrice, Price result);

    constructor(uint256 _percentageForOwner) {
        percentageForOwner = _percentageForOwner;
        owner = msg.sender;

        GET_PRICE = new PriceConsumerV3(); //get price of currency
    }

    function createRound() external onlyOwner {
        require(rounds[currentRound].startPrice == 0, "Previous round has not been ended"); //check if this round does not exist
        (rounds[currentRound].priceRound, rounds[currentRound].startPrice) = GET_PRICE.getLatestPrice(); //get start price
        rounds[currentRound].createdAt = block.timestamp;

        emit CreateRound(currentRound, rounds[currentRound].startPrice);
    }

    function enterRound(Price _decision) external payable checkSender {
        require(rounds[currentRound].createdAt + timeToWait > block.timestamp, "Bets are closed");
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");

        rounds[currentRound].totalPool += msg.value;
        Price(0) == _decision ? rounds[currentRound].higher.push(msg.sender) : rounds[currentRound].lower.push(msg.sender); //adding player to an array depends on his decision

        emit EnterRound(msg.sender, msg.value, _decision);
    }
    //the number of round should update to run that function
    function closeRound() external onlyOwner {
        require(rounds[currentRound].createdAt + timeToWait < block.timestamp, "You can not start the round now");
        //checking if round was updated
        (uint80 currentPriceRound,) = GET_PRICE.getLatestPrice();
        require(currentPriceRound > rounds[currentRound].priceRound, "The price has not been updated yet");
        //if the round was updated - closing round
        (, rounds[currentRound].endPrice) = GET_PRICE.getLatestPrice(); //setting end price
 
        uint256 commision = rounds[currentRound].totalPool / 100 * percentageForOwner;
        uint256 moneyLeft = rounds[currentRound].totalPool - commision;

        address[] memory winners;

        payable(owner).sendValue(commision);

        if(rounds[currentRound].endPrice == rounds[currentRound].startPrice) { //compare startPrice to endPrice
            treasury += rounds[currentRound].totalPool;
            rounds[currentRound].result = Price(2);
        }
        if(rounds[currentRound].endPrice > rounds[currentRound].startPrice) {
            winners = rounds[currentRound].higher;
            rounds[currentRound].result = Price(0);
        } 
        if(rounds[currentRound].endPrice < rounds[currentRound].startPrice) {
            winners = rounds[currentRound].lower;
            rounds[currentRound].result = Price(1);
        }

        if(winners.length > 0)
        for(uint256 i = 0; i < winners.length; i++) { //paying to the winners if they exist
            payable(winners[i]).sendValue(moneyLeft / winners.length);
        }

        emit CloseRound(currentRound, rounds[currentRound].endPrice, rounds[currentRound].result);

        unchecked {
            currentRound++;
        }
    }
    //receive money from treasury
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