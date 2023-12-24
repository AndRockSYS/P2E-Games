// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./chain.link/VRFv2.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract DuelsForTwoPeople {

  using Address for address payable;

  VRFv2 public VRF_V2; //generate random number variable

  address owner;
  uint256 percentageForOwner; //percentage from lobby pool which will be transfered to the deployer

  uint256 maxBet = 1000 ether;
  uint256 minBet = 0.005 ether;

  uint256 lobbyNumber; //number of all lobbies
  uint256 timeForLobby = 5 minutes; //after that time, player can close the lobby

  event CreateLobby(uint256 lobby, address indexed creator, uint256 bet);
  event EnterLobby(uint256 lobby, address indexed enteredPlayer);
  event CloseLobby(uint256 lobby);
  event Winner(uint256 lobby, address indexed winner, uint256 amount);

  struct Lobby {
    address player1;
    address player2;
    uint256 pool; //sum of two bets in lobby

    uint256 createdAt; //block.timestamp, when the lobby was created

    address winner;
  }

  mapping(uint256 => Lobby) public lobbies;

  constructor(uint16 _percentage, uint64 _subscriptionId){
    VRF_V2 = new VRFv2(_subscriptionId);

    owner = msg.sender;
    percentageForOwner = _percentage;
  }
  //create new, empty lobby
  function createLobby(bool _chosenColor) payable external checkSender {
    require(msg.value >= minBet && msg.value <= maxBet, "Bet is too high or too low");

    lobbies[lobbyNumber].createdAt = block.timestamp;
    lobbies[lobbyNumber].pool = msg.value;

    _chosenColor ? lobbies[lobbyNumber].player1 = msg.sender : lobbies[lobbyNumber].player2 = msg.sender;

    emit CreateLobby(lobbyNumber, msg.sender, msg.value);

    unchecked {
      lobbyNumber++;
    }
  }
  //close the lobby after specific amount of time if the player2 wan not found
  function closeLobby(uint256 _lobby) external checkSender {
    require(lobbies[_lobby].player2 == address(0) || lobbies[_lobby].player1 == address(0), "This lobby is full");
    require(block.timestamp >= (lobbies[_lobby].createdAt + timeForLobby), "You can not close it now");
    require(msg.sender == lobbies[_lobby].player1 || msg.sender == lobbies[_lobby].player2, "You are not the creator of the lobby");

    uint256 pool = lobbies[_lobby].pool;
    lobbies[_lobby].pool = 0;
    lobbies[_lobby].createdAt = 0;

    payable(msg.sender).sendValue(pool);

    emit CloseLobby(_lobby);
  }
  //enter an existing lobby with the same bet as the first player
  function enterLobby(uint256 _lobby) payable external checkSender {
    require(lobbies[_lobby].pool > 0, "This lobby does not exist");
    require(lobbies[_lobby].player2 == address(0) || lobbies[_lobby].player1 == address(0), "This lobby is full");
    require(msg.value == lobbies[_lobby].pool, "Your bet is not correct");

    lobbies[_lobby].player1 == address(0) ? lobbies[_lobby].player1 = msg.sender : lobbies[_lobby].player2 = msg.sender;
    lobbies[_lobby].pool += msg.value;

    emit EnterLobby(_lobby, msg.sender);

    VRF_V2.requestRandomWords(_lobby);
  }
  //start the game only if event in VRFv2.sol was emited for this round
  function startTheGame(uint256 _lobby) external checkSender {
    require(lobbies[_lobby].winner == address(0), "This round has been ended");
    (uint256 winNumber, bool hasSet) = VRF_V2.getRandomNumberByDuelID(_lobby);
    require(hasSet, "The number was not set yet");

    uint256 comission = lobbies[_lobby].pool * percentageForOwner/100;
    uint256 pool = lobbies[_lobby].pool;

    if(winNumber % 2 == 0) { //get random number and divide it
      lobbies[_lobby].winner = lobbies[_lobby].player1;
    } else {
      lobbies[_lobby].winner = lobbies[_lobby].player2;
    }
    payable(lobbies[_lobby].winner).sendValue(pool-comission); //send winAmount-commision to the winner
    payable(owner).sendValue(comission); //send comission to owner

    lobbies[_lobby].player1 = address(0); //clear the lobby and return refunds
    lobbies[_lobby].player2 = address(0);
    lobbies[_lobby].pool = 0;

    emit Winner(_lobby, lobbies[_lobby].winner, pool-comission);
  }
  //set new percentage of comission for the owner
  function setPercentage(uint256 _newPercentage) external {
    require(msg.sender == owner, "You do not have permsission");
    
    percentageForOwner = _newPercentage;
  }

  modifier checkSender {
    require(msg.sender != address(0), "Account does not exist");
    _;
  }
}