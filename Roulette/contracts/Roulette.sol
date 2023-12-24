//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "./chain.link/VRFv2.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Roulette {

    using Address for address payable;

    VRFv2 public VRF_V2;

    uint256 percentageForOwner;

    address owner;
    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;

    uint256 timeToStart = 1 minutes; //time after which the round can start

    uint256 public currentRound;
    uint256 treasury; //casino's treasury

    constructor(uint64 _subscriptionId, uint256 _percentageForOwner) {
        owner = msg.sender;
        percentageForOwner = _percentageForOwner;

        VRF_V2 = new VRFv2(_subscriptionId); //random number generator
    }

    struct Round {
        Color winColor;
        uint256 pool;

        uint256 createdAt;

        bool hasNumber;

        address[] green;
        address[] black;
        address[] red;
    }

    enum Color { GREEN, RED, BLACK } //colors which can be in roulette

    uint8[] red = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36]; //all red number

    mapping(uint256 => Round) public rounds;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(uint256 round, uint256 pool, Color winColor);

    function createRound() external onlyOwner {
        require(rounds[currentRound].createdAt == 0, "This round has not been ended"); //that round should be empty
        rounds[currentRound].createdAt = block.timestamp;

        emit CreateRoulette(currentRound);
    }

    function enterRound(Color _color) external payable checkSender {
        require(rounds[currentRound].createdAt + timeToStart > block.timestamp, "Bets are closed");
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");

        if(_color == Color(0)) rounds[currentRound].green.push(msg.sender); //push player to array depends on which color he chose
        if(_color == Color(1)) rounds[currentRound].red.push(msg.sender);
        if(_color == Color(2)) rounds[currentRound].black.push(msg.sender);

        rounds[currentRound].pool += msg.value; //adding his bet to pool of this round

        emit EnterRoulette(msg.sender, msg.value, _color);
    }

    function generateNumebr() external onlyOwner {
        require(rounds[currentRound].createdAt + timeToStart < block.timestamp, "You can not generate it now");

        VRF_V2.requestRandomWords(currentRound);
    }
    //to start this function event in VRFv2.sol file must be emited
    function closeRound() external onlyOwner {
        require(rounds[currentRound+1].createdAt == 0, "This round has ended");
        require(block.timestamp > timeToStart + rounds[currentRound].createdAt, "The rouletter can not start yet");
        (uint256 oldRange, bool hasSet) = VRF_V2.getRandomNumberByRouletteRound(currentRound);
        require(hasSet, "The number was not set yet");

        uint8 win;

        unchecked {
            uint8 newRange = uint8(oldRange); //computate winning number in range from 0 to 36
            uint16 winNumber = uint16(newRange) * 37 / 256;
            win = selectColor(winNumber);
        }

        uint256 comission = rounds[currentRound].pool / 100 * percentageForOwner;

        rounds[currentRound].winColor = Color(win);
        address[] memory winners;
        if(win == 0) winners = rounds[currentRound].green; //set winners depends on winning number
        if(win == 1) winners = rounds[currentRound].red;
        if(win == 2) winners = rounds[currentRound].black;

        if(winners.length != 0) {
            for(uint256 i = 0; i < winners.length; i++) {
                payable(winners[i]).sendValue((rounds[currentRound].pool - comission) / winners.length);
            }
        } else treasury += rounds[currentRound].pool - comission; //adding pool to treasury if there are no winners
        payable(owner).sendValue(comission);

        emit CloseRoulette(currentRound, rounds[currentRound].pool, Color(win));

        unchecked {
            currentRound++;
        }
    }
    //select winning color depends on winning number
    function selectColor(uint16 _winNumber) internal view returns(uint8){
        if(_winNumber == 0) return 0;
        for(uint8 i = 0; i < red.length; i++) {
            if(red[i] == _winNumber) return 1;
        }
        return 2;
    }

    function setPercenage(uint256 _newPercentage) external onlyOwner {
        percentageForOwner = _newPercentage;
    }
    //receive money from treasury
    function getFromTreasury(uint256 _amount) external onlyOwner {
        require(_amount <= treasury, "Your number is bigger than allowed");
        treasury -= _amount;
        payable(msg.sender).sendValue(_amount);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier checkSender {
        require(msg.sender != address(0), "This account does not exist");
        _;
    }

}