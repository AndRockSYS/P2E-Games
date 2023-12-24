// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";

contract WheelTest {
    using Address for address payable;

    uint64 public percentageForOwner;
    address owner;

    uint256 minBet = 0.005 ether;
    uint256 maxBet = 1000 ether;
    uint256 timeToStart = 1 minutes;

    uint256 public currentRound;

    struct Spin {
        address winner;
        uint256 totalPool;

        uint256 createdAt;
        bool hasNumber; 
        bool hasEnded;
        Player[] players;
    }

    struct Player {
        address player;
        uint256 bet;
    }

    Spin clearSpin;

    mapping(uint256 => Spin) public spins;

    event CreateWheel(uint256 _wheelRound);
    event EnterWheel(address indexed _account, uint256 _bet);
    event PendingRandomNumber();
    event Winner(address indexed _winner, uint256 _winningAmount);

    constructor(uint64 _percentageForOwner) {
      owner = msg.sender;
      percentageForOwner = _percentageForOwner;
    }

    function createWheel() external onlyOwner {
        spins[currentRound] = clearSpin;
        spins[currentRound].createdAt = block.timestamp;

        emit CreateWheel(currentRound);
    }

    function enterWheel() external payable checkSender {
        require(msg.value >= minBet && msg.value <= maxBet, "Your bet is too low or too high");

        spins[currentRound].totalPool += msg.value;
        spins[currentRound].players.push(Player(msg.sender, msg.value));

        emit EnterWheel(msg.sender, msg.value);
    }

    function generateNumber() external onlyOwner {
        require(block.timestamp > spins[currentRound].createdAt + timeToStart, "You can not start the game now");
        require(!spins[currentRound].hasNumber, "The number was already generated");

        //VRF_V2.requestRandomWords(currentRound); //generate random number
        spins[currentRound].hasNumber = true;
        emit PendingRandomNumber();
    }

    function closeWheel() external onlyOwner {
        require(!spins[currentRound].hasEnded , "The wheel can not start");
        //require(VRF_V2.getRandomNumberByDuelID(currentRound) != 0, "The number was not generated yet");
        uint256 comission = spins[currentRound].totalPool * percentageForOwner/100;
        //compute winner
        //uint256 winNumber;
        //unchecked {
            //uint16 randomNumber = uint16(VRF_V2.getRandomNumberByDuelID(currentRound));
            //winNumber = uint256(randomNumber) * 10000 / 65536;
        //}
        //uint256 previous = 0;
        // Player[] memory actualPlayers = spins[currentRound].players;
        // for(uint i = 0; i < actualPlayers.length; i++) {
        //     previous += actualPlayers[i].bet * 10000 / spins[currentRound].totalPool;
        //     if(previous >= winNumber) {
        //         spins[currentRound].winner = actualPlayers[i].player;
        //         break;
        //     }
        // }
        spins[currentRound].winner = spins[currentRound].players[0].player;
        emit Winner(spins[currentRound].winner, spins[currentRound].totalPool - comission);
        payable(spins[currentRound].winner).sendValue(spins[currentRound].totalPool - comission);
        payable(owner).sendValue(comission);
        spins[currentRound].hasEnded = true;
        //unchecked {
            currentRound++;
        //}
    }

    function setNewPercentage(uint64 _newPercentage) external onlyOwner {
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