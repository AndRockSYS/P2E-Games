# DuelsForTwoPeople
Identifing version, imported packages and VRF generator
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./chain.link/VRFv2.sol";
import "@openzeppelin/contracts/utils/Address.sol";
```
Vars, events that will be used for the contract
```solidity
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

  struct Lobby { //lobby, that will store the info about specific round
    address player1;
    address player2;
    uint256 pool; //sum of two bets in lobby

    uint256 createdAt; //block.timestamp, when the lobby was created

    address winner;
  }

  mapping(uint256 => Lobby) public lobbies; //storing all lobbies with their rounds
```
Constructor which takes percentage that will be executed from each game and sent to owner. Also it takes subscriprion id to connect to chainlink manager
```solidity
  constructor(uint16 _percentage, uint64 _subscriptionId){
    VRF_V2 = new VRFv2(_subscriptionId);

    owner = msg.sender;
    percentageForOwner = _percentage;
  }
```
# Creating new lobby by someone
```solidity
  //create new, empty lobby
  function createLobby(bool _chosenColor) payable external checkSender {
    require(msg.value >= minBet && msg.value <= maxBet, "Bet is too high or too low"); //check if bet is correct

    lobbies[lobbyNumber].createdAt = block.timestamp; //set time when that lobby was created
    lobbies[lobbyNumber].pool = msg.value; //adding bet to pool of that lobby

    _chosenColor ? lobbies[lobbyNumber].player1 = msg.sender : lobbies[lobbyNumber].player2 = msg.sender; //chose positions in lobby depends on _chosenColor

    emit CreateLobby(lobbyNumber, msg.sender, msg.value);

    unchecked {
      lobbyNumber++; //updating lobbyNumber for future lobbies
    }
  }
```
# Every player that created a lobby can close it after 5 minutes and receive bet back if he wants
```solidity
  function closeLobby(uint256 _lobby) external checkSender {
    require(lobbies[_lobby].player2 == address(0) || lobbies[_lobby].player1 == address(0), "This lobby is full"); //checks if msg.sender can join
    require(block.timestamp >= (lobbies[_lobby].createdAt + timeForLobby), "You can not close it now"); //checks if the time has gone
    require(msg.sender == lobbies[_lobby].player1 || msg.sender == lobbies[_lobby].player2, "You are not the creator of the lobby"); //checks for creator

    uint256 pool = lobbies[_lobby].pool;
    lobbies[_lobby].pool = 0; //set values to default
    lobbies[_lobby].createdAt = 0;

    payable(msg.sender).sendValue(pool); //send money back

    emit CloseLobby(_lobby); //emitting an event
  }
```
# Everyone can enter an exisitng lobby with the same bet as the creator of this lobby placed in it
```solidity
  function enterLobby(uint256 _lobby) payable external checkSender {
    require(lobbies[_lobby].pool > 0, "This lobby does not exist"); //check if lobby exists
    require(lobbies[_lobby].player2 == address(0) || lobbies[_lobby].player1 == address(0), "This lobby is full");
    require(msg.value == lobbies[_lobby].pool, "Your bet is not correct"); //checks for the same bet

    lobbies[_lobby].player1 == address(0) ? lobbies[_lobby].player1 = msg.sender : lobbies[_lobby].player2 = msg.sender; //set player to availible position in lobby
    lobbies[_lobby].pool += msg.value;

    emit EnterLobby(_lobby, msg.sender); //emitting entering in lobby
```
```diff
- Send request to start generate random number at the end of `enterLoby` function to save time and gas
```
```solidity
    VRF_V2.requestRandomWords(_lobby);
  }
```
```solidity
//PART OF CODE FROM VRFv2.sol
  //function in VRFv2.sol that sends the request to chainlink to generate number
  function requestRandomWords(uint256 duelId) external returns (uint256) {
    uint256 requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );

    s_requestIdToDuelId[requestId] = duelId; //setting request id to link it with duel id

    return requestId; //return the requestId to the requester.
  }
```
**When this contract (VRFv2.sol) receives random number for that round, this number will be set and event will be emited, only then** `startTheGame` **function can be ran**
```diff
- Some time need to pass to receive random number
```
```solidity
//PART OF CODE FROM VRFv2.sol
  function fulfillRandomWords(
      uint256 requestId,
      uint256[] memory randomWords
    ) internal override {
    require(!s_duelIdToNumber[s_requestIdToDuelId[requestId]].hasSet, "The number was set already"); //check to not reset the number

    s_duelIdToNumber[s_requestIdToDuelId[requestId]].number = randomWords[0]; //setting random number
    s_duelIdToNumber[s_requestIdToDuelId[requestId]].hasSet = true; //setting that the number was received

    emit RandomNumberIsReadyForDuel(s_requestIdToDuelId[requestId], randomWords[0]); //emitting event that the number is ready to be used
  }
```
# Start the game function that should start only if event in VRFv2.sol was emited for this round
```solidity
  function startTheGame(uint256 _lobby) external checkSender {
    require(lobbies[_lobby].winner == address(0), "This round has been ended"); //check if that lobby ended or not
    (uint256 winNumber, bool hasSet) = VRF_V2.getRandomNumberByDuelID(_lobby); //receiving data about number from VRFv2.sol
```
```solidity
//PART OF CODE FROM VRFv2.sol
  //return number for specific dueld if
  function getRandomNumberByDuelID(uint256 duelId) external view returns (uint256, bool) {
    return (s_duelIdToNumber[duelId].number, s_duelIdToNumber[duelId].hasSet);
  }
```
```solidity
    require(hasSet, "The number was not set yet"); //check if random number was set

    uint256 comission = lobbies[_lobby].pool * percentageForOwner/100; //computate comissiong for owner
    uint256 pool = lobbies[_lobby].pool;

    if(winNumber % 2 == 0) { //get random number and divide it and select winner
      lobbies[_lobby].winner = lobbies[_lobby].player1;
    } else {
      lobbies[_lobby].winner = lobbies[_lobby].player2;
    }
    payable(lobbies[_lobby].winner).sendValue(pool-comission); //send winAmount-commision to the winner
    payable(owner).sendValue(comission); //send comission to owner

    lobbies[_lobby].player1 = address(0); //clear the lobby and return refunds
    lobbies[_lobby].player2 = address(0);
    lobbies[_lobby].pool = 0;

    emit Winner(_lobby, lobbies[_lobby].winner, pool-comission); //emitting event to receive a winner
  }
```
# Helping functions and modifiers
```solidity
  //set new percentage of comission for the owner
  function setPercentage(uint256 _newPercentage) external {
    require(msg.sender == owner, "You do not have permsission"); //check for owner
    
    percentageForOwner = _newPercentage;
  }

  modifier checkSender {
    require(msg.sender != address(0), "Account does not exist");
    _;
  }
}
```
