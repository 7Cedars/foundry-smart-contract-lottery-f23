
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Seven Cedars / Patrick Collins
 * @notice This contract was written during PC course on foundry and solidityu. 
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
  error Raffle__NotEnoughEthSent(); 
  error Raffle__TransferFailed(); 
  error Raffle__RaffleNotOpen(); 
  error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers, 
    uint256 raffleState
  ); 

  /** Type declarations */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /** state variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3; 
  uint32 private constant NUM_WORDS = 1; 
  
  uint256 private immutable i_entranceFee; 
  uint256 private immutable i_interval;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator; 
  bytes32 private immutable i_gasLane; 
  uint64  private immutable i_subscriptionId; 
  uint32  private immutable i_callbackGasLimit; 

  address payable[] private s_players; 
  address payable private s_recentWinner; 
  uint256 private s_lastTimeStamp;
  RaffleState private s_raffleState; 
  
  /** Events */
  event EnteredRaffle(address indexed player);  
  event PickedWinner(address winner);  
  

  constructor(
    uint256 entranceFee, 
    uint256 interval, 
    address vrfCoordinator, 
    bytes32 gasLane, 
    uint64 subscriptionId, 
    uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
      i_entranceFee = entranceFee; 
      i_interval = interval; 
      i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator); 
      i_gasLane = gasLane; 
      i_subscriptionId = subscriptionId; 
      i_callbackGasLimit = callbackGasLimit; 

      s_raffleState = RaffleState.OPEN; 
      s_lastTimeStamp = block.timestamp; 
      
  }

  function enterRaffle() external payable { 
    if(msg.value < i_entranceFee) {
      revert Raffle__NotEnoughEthSent(); 
    }
    if(s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffleNotOpen(); 
    }
    s_players.push(payable(msg.sender));

    emit EnteredRaffle(msg.sender); 
  } 

  /** 
   * @dev Description here of function. 
   * 
   * 
   * 
   * */ 
  function checkUpkeep(
      bytes memory /* checkData */ 
    ) public view returns ( bool upkeepNeeded, bytes memory /* performData */ ) {
      bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; 
      bool isOpen = RaffleState.OPEN == s_raffleState; 
      bool hasBalance = address(this).balance > 0; 
      bool hasPlayers = s_players.length > 0; 
      upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers); 
      return (upkeepNeeded, "0x0");  // this last bit is a blank bytes object. 
    }

  function performUpkeep(bytes calldata /* performData */) external {
    (bool upkeepNeeded, ) = checkUpkeep(""); 
    if (!upkeepNeeded) {
      revert Raffle__UpkeepNotNeeded(
        address(this).balance,
        s_players.length, 
        uint256(s_raffleState) 
        ); 
    }

    s_raffleState = RaffleState.CALCULATING; 
    i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, 
            i_callbackGasLimit,
            NUM_WORDS
    );
  }

  // NB: note on CEI: Checks, Effects, Interactions.. (Patrick Collins.)
  function fulfillRandomWords(
    uint256 requestId, 
    uint256[] memory randomWords
  ) internal override {
    // step 1: Checks (require, if -> errors.. etc) -- most gas efficient. 

    // step 2: effects: you effect your contract
    uint256 indexOfWinner = randomWords[0] % s_players.length; 
    address payable winner = s_players[indexOfWinner]; 
    s_recentWinner = winner; 
    s_raffleState = RaffleState.OPEN; 
    s_players = new address payable[](0); 
    s_lastTimeStamp = block.timestamp; 
    emit PickedWinner(winner); // so note: emit at end of effects! -- not at end of function! 

    // interactions with other contracts. (due to reentrancy attacks - security.) 
    (bool success, ) = winner.call{value: address(this).balance}(""); 
    if (!success) {
          revert Raffle__TransferFailed(); 
    }
  }

  /** Getter Funcions */ 
  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee; 
  } 

  function getRaffleState() external view returns (RaffleState) {
    return s_raffleState; 
  } 

  function getPlayer(uint256 indexOfPlayer) external view returns (address) {
    return s_players[indexOfPlayer];
  } 
}