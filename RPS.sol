// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    struct Player {
        address payable addr;
        bytes32 commitment;
        uint256 choice;
        bool hasRevealed;
    }

    mapping(address => bool) public authorizedPlayers;
    Player[2] public players;
    uint256 public prizePool;
    uint256 public revealDeadline;
    uint8 public playerCount;
    uint8 public revealCount;
    bool public gameActive;

    CommitReveal public commitReveal;
    TimeUnit public timeTracker;

    event GameStarted(address indexed player1, address indexed player2);
    event PlayerCommitted(address indexed player);
    event PlayerRevealed(address indexed player, uint256 choice);
    event GameResult(address winner, uint256 prizeAmount);
    event GameReset();

    constructor() {
        commitReveal = new CommitReveal();
        timeTracker = new TimeUnit();
        authorizedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        authorizedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        authorizedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        authorizedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    modifier onlyAuthorized() {
        require(authorizedPlayers[msg.sender], "Not an authorized player");
        _;
    }

    modifier onlyDuringGame() {
        require(gameActive, "No active game");
        _;
    }

    function joinGame() external payable onlyAuthorized {
        require(playerCount < 2, "Game is full");
        require(msg.value == 1 ether, "Entry fee: 1 ETH required");
        
        players[playerCount] = Player(payable(msg.sender), bytes32(0), 0, false);
        prizePool += msg.value;
        playerCount++;
        
        if (playerCount == 2) {
            gameActive = true;
            revealDeadline = block.timestamp + 2 hours;
            emit GameStarted(players[0].addr, players[1].addr);
        }
    }

    function commitChoice(bytes32 _commitment) external onlyDuringGame {
        require(msg.sender == players[0].addr || msg.sender == players[1].addr, "Not a participant");
        uint8 index = (msg.sender == players[0].addr) ? 0 : 1;
        require(players[index].commitment == bytes32(0), "Already committed");
        
        players[index].commitment = _commitment;
        emit PlayerCommitted(msg.sender);
    }

    function revealChoice(uint256 _choice, string memory _salt) external onlyDuringGame {
        require(_choice < 5, "Invalid choice");
        uint8 index = (msg.sender == players[0].addr) ? 0 : 1;
        require(!players[index].hasRevealed, "Already revealed");
        require(commitReveal.reveal(msg.sender, _choice, _salt), "Invalid reveal");
        
        players[index].choice = _choice;
        players[index].hasRevealed = true;
        revealCount++;
        
        emit PlayerRevealed(msg.sender, _choice);
        
        if (revealCount == 2) {
            determineWinner();
        }
    }

    function determineWinner() private {
        uint256 choiceA = players[0].choice;
        uint256 choiceB = players[1].choice;
        address payable winner;
        uint256 winnerPrize = prizePool;

        if ((choiceA + 1) % 5 == choiceB || (choiceA + 3) % 5 == choiceB) {
            winner = players[1].addr;
        } else if ((choiceB + 1) % 5 == choiceA || (choiceB + 3) % 5 == choiceA) {
            winner = players[0].addr;
        } else {
            players[0].addr.transfer(prizePool / 2);
            players[1].addr.transfer(prizePool / 2);
            resetGame();
            return;
        }

        winner.transfer(winnerPrize);
        emit GameResult(winner, winnerPrize);
        resetGame();
    }

    function claimTimeout() external onlyDuringGame {
        require(block.timestamp > revealDeadline, "Reveal period not over");
        
        if (revealCount == 1) {
            uint8 index = players[0].hasRevealed ? 0 : 1;
            players[index].addr.transfer(prizePool);
            resetGame();
        }
    }

    function resetGame() private {
        delete players;
        prizePool = 0;
        playerCount = 0;
        revealCount = 0;
        gameActive = false;
        emit GameReset();
    }
}

