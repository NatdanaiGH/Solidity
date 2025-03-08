// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    uint256 public playerCount = 0;
    uint256 public prizePool = 0;
    mapping(address => uint256) public playerSelections;
    mapping(address => bool) public hasNotPlayed;
    mapping(address => bool) public activePlayers;
    address[2] public participantList;
    uint256 public revealCount = 0;

    address[] private authorizedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    CommitReveal public commitReveal = new CommitReveal();
    TimeUnit public timeTracker = new TimeUnit();

    constructor() {
        commitReveal = new CommitReveal();
    }

    modifier onlyParticipants() {
        require(activePlayers[msg.sender], "Not an active participant");
        _;
    }

    function isAuthorized(address player) private view returns (bool) {
        for (uint256 i = 0; i < authorizedPlayers.length; i++) {
            if (player == authorizedPlayers[i]) {
                return true;
            }
        }
        return false;
    }

    function joinGame() public payable {
        require(isAuthorized(msg.sender), "Access denied");
        require(playerCount < 2, "Game is full");
        require(!activePlayers[msg.sender], "Already in game");
        require(msg.value == 1 ether, "Entry fee: 1 ETH required");
        
        prizePool += msg.value;
        hasNotPlayed[msg.sender] = true;
        activePlayers[msg.sender] = true;
        participantList[playerCount] = msg.sender;
        playerCount++;
    }

    function leaveGame() public {
        require(activePlayers[msg.sender], "Not a participant");
        require(playerCount < 2, "Game has started");
        
        payable(msg.sender).transfer(1 ether);
        activePlayers[msg.sender] = false;
        hasNotPlayed[msg.sender] = false;
        playerCount--;
    }

    function submitCommitment(bytes32 _commitment) external onlyParticipants {
        commitReveal.commitMove(msg.sender, _commitment, 0, "");
    }

    function discloseChoice(uint256 choice, string memory salt) external onlyParticipants {
        require(hasNotPlayed[msg.sender], "Already disclosed");
        require(choice < 5, "Invalid choice");
        require(commitReveal.reveal(msg.sender, choice, salt), "Invalid reveal");
        
        playerSelections[msg.sender] = choice;
        hasNotPlayed[msg.sender] = false;
        revealCount++;

        if (revealCount == 2) {
            determineWinner();
        }
    }

    function determineWinner() private {
        uint256 choiceA = playerSelections[participantList[0]];
        uint256 choiceB = playerSelections[participantList[1]];
        address payable playerA = payable(participantList[0]);
        address payable playerB = payable(participantList[1]);

        if ((choiceA + 1) % 5 == choiceB || (choiceA + 3) % 5 == choiceB) {
            playerB.transfer(prizePool);
        } else if ((choiceB + 1) % 5 == choiceA || (choiceB + 3) % 5 == choiceA) {
            playerA.transfer(prizePool);
        } else {
            playerA.transfer(prizePool / 2);
            playerB.transfer(prizePool / 2);
        }
        restartGame();
    }

    function restartGame() internal {
        commitReveal.resetCommit(participantList[0], participantList[1]);
        delete playerSelections[participantList[0]];
        delete playerSelections[participantList[1]];
        activePlayers[participantList[0]] = false;
        activePlayers[participantList[1]] = false;
        playerCount = 0;
        prizePool = 0;
        revealCount = 0;
    }

    function enforceGameEnd() public {
        require(playerCount == 2, "Game hasn't started");
        require(timeTracker.elapsedSeconds() > 7200, "Time limit not met");

        payable(msg.sender).transfer(prizePool);
        restartGame();
    }

    function refundSinglePlayer() public {
        require(playerCount == 1, "Invalid game state");
        require(timeTracker.elapsedSeconds() > 3600, "Time limit not met");

        payable(participantList[0]).transfer(prizePool);
        restartGame();
    }
}
