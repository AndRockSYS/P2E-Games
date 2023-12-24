//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

contract RouletteTest {

    using Address for address payable;

    uint256 public percentageForOwner;

    address owner;
    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;

    uint256 timeToStart = 10 seconds;

    uint256 public currentRound;

    constructor(uint256 _percentageForOwner) {
        owner = msg.sender;
        percentageForOwner = _percentageForOwner;
    }

    struct Round {
        Color winColor;
        uint256 pool;

        uint256 createdAt;

        bool hasNumber;
        bool hasEnded;

        address[] green;
        address[] black;
        address[] red;
    }

    enum Color { GREEN, RED, BLACK }

    uint8[] red = [1,3,5,7,9,12,14,16,18,21,23,25,27,28,30,32,34,36];

    Round clearRound;

    mapping(uint256 => Round) public rounds;

    event CreateRoulette(uint256 round);
    event EnterRoulette(address indexed player, uint256 bet, Color color);
    event CloseRoulette(Color winColor);

    function createRound() external onlyOwner {
        rounds[currentRound] = clearRound;
        rounds[currentRound].createdAt = block.timestamp;

        emit CreateRoulette(currentRound);
    }

    function enterRound(Color _color) external payable checkSender {
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is not correct");
        require(!rounds[currentRound].hasNumber, "Bets are closed");

        if(_color == Color(0)) rounds[currentRound].green.push(msg.sender);
        if(_color == Color(1)) rounds[currentRound].red.push(msg.sender);
        if(_color == Color(2)) rounds[currentRound].black.push(msg.sender);

        rounds[currentRound].pool += msg.value;

        emit EnterRoulette(msg.sender, msg.value, _color);
    }

    // function generateNumebr() external onlyOwner {
    //     require(!rounds[currentRound].hasNumber, "The number was generated");

    //     VRF_V2.requestRandomWords(currentRound);
    //     rounds[currentRound].hasNumber = true;
    // }

    function closeRound() external onlyOwner {
        require(!rounds[currentRound].hasEnded, "This round has ended");
        // require(block.timestamp > block.timestamp + rounds[currentRound].createdAt, "The rouletter can not start yet");
        // require(VRF_V2.getRandomNumberByDuelID(currentRound) != 0, "The number was not generated yet");

        // uint8 newRange = uint8(VRF_V2.getRandomNumberByDuelID(currentRound));
        // uint16 winNumber = uint16(newRange) * 37 / 256;
        // uint8 win = selectColor(winNumber);

        uint256 comission = rounds[currentRound].pool / 100 * percentageForOwner;
        uint8 win = 1;

        rounds[currentRound].winColor = Color(win);
        address[] memory winners;
        if(win == 0) winners = rounds[currentRound].green;
        if(win == 1) winners = rounds[currentRound].red;
        if(win == 2) winners = rounds[currentRound].black;

        if(winners.length != 0)
            for(uint256 i = 0; i < winners.length; i++) {
                payable(winners[i]).sendValue((rounds[currentRound].pool - comission) / winners.length);
            }
        payable(owner).sendValue(comission);

        rounds[currentRound].hasEnded = true;
        emit CloseRoulette(Color(0));
        unchecked {
            currentRound++;
        }
    }

    function selectColor(uint16 _winNumber) internal view returns(uint8){
        if(_winNumber == 0) return 0;
        for(uint8 i = 0; i < red.length; i++) {
            if(red[i] == _winNumber) {
                return 1;
            }
        }
        return 2;
    }

    function setPercenage(uint256 _newPercentage) external onlyOwner {
        percentageForOwner = _newPercentage;
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