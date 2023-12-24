// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import "../chain.link/VRFv2.sol";

contract Duels {

  //VRFv2 public VRF_V2;

  address public owner;
  uint256 public percentageForOwner;
  uint256 maxBet = 1000 ether;
  uint256 minBet = 0.005 ether;
  uint256 public lobbyNumber;
  uint256 timeForLobby = 3 seconds;

  event CreateLobby(uint256 lobby, address indexed creator, uint256 bet);
  event EnterLobby(uint256 lobby, address indexed enteredPlayer);
  event CloseLobby(uint256 lobby);
  event Winner(uint256 lobby, address indexed winner, uint256 amount);

  struct Lobby {
    address player1;
    address player2;
    uint256 pool;

    uint256 createdAt;
    address winner;
  }

  mapping(uint256 => Lobby) public lobbies;

  constructor(uint16 _percentage){//, uint64 _subscriptionId){
    percentageForOwner = _percentage;
    //VRF_V2 = new VRFv2(_subscriptionId);
    owner = msg.sender;
  }

  function createLobby() payable external checkSender {
    require(msg.value >= minBet && msg.value <= maxBet, "Bet is too high or too low");
    lobbies[lobbyNumber] = Lobby(msg.sender, address(0), msg.value, block.timestamp, address(0));
    emit CreateLobby(lobbyNumber, msg.sender, msg.value);
    unchecked {
      lobbyNumber++;
    }
  }

  function closeLobby(uint256 _lobby, uint256 time) external {
    require(msg.sender == lobbies[_lobby].player1, "You are not the creator of the lobby");
    require(time >= (lobbies[_lobby].createdAt + timeForLobby), "You can not close it now");
    require(lobbies[_lobby].player2 == address(0), "This lobby is full");
    lobbies[_lobby].player1 = address(0);
    uint256 pool = lobbies[_lobby].pool;
    lobbies[_lobby].pool = 0;
    lobbies[_lobby].createdAt = 0;
    payable(msg.sender).transfer(pool);
    emit CloseLobby(_lobby);
  }

  function enterLobby(uint256 _lobby) payable external checkSender {
    require(lobbies[_lobby].player2 == address(0), "This lobby is full");
    require(msg.value == lobbies[_lobby].pool, "Your bet is not correct");
    lobbies[_lobby].player2 = msg.sender;
    lobbies[_lobby].pool += msg.value;
    emit EnterLobby(_lobby, msg.sender);
  }

  function startTheGame(uint256 _lobby) external {
    require(lobbies[_lobby].player1 != address(0) && lobbies[_lobby].player2 != address(0) && lobbies[_lobby].pool > 0, "The game can not start");
    //VRF_V2.requestRandomWords(_lobby);
    uint256 comission = lobbies[_lobby].pool * percentageForOwner/100;
    uint256 pool = lobbies[_lobby].pool;
    lobbies[_lobby].pool = 0;
   //if((VRF_V2.getRandomNumberByDuelID(_lobby) % 2) == 0) {
      payable(lobbies[_lobby].player1).transfer(pool-comission);
      emit Winner(_lobby, lobbies[_lobby].player1, pool-comission);
      lobbies[_lobby].winner = lobbies[_lobby].player1;
    //} else {
    //   payable(lobbies[_lobby].player2).transfer(pool-comission);
    //   emit Winner(_lobby, lobbies[_lobby].player2, pool-comission);
    //}
    payable(owner).transfer(comission);
    lobbies[_lobby].player1 = address(0);
    lobbies[_lobby].player2 = address(0);
    lobbies[_lobby].createdAt = 0;
  }

  function setPercentage(uint256 _newPercentage) external {
    require(msg.sender == owner, "You do not have permsission");
    percentageForOwner = _newPercentage;
  }

  modifier checkSender {
    require(msg.sender != address(0), "Account does not exist");
    _;
  }
}