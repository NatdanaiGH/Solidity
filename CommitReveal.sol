// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract CommitReveal {
    mapping(address => bytes32) public commitRecords;
    mapping(address => uint256) public playerChoices;
    mapping(address => string) public secretSalts;

    event CommitmentStored(address indexed player, bytes32 commitment);
    event CommitmentsCleared(address player1, address player2);

    function storeCommitment(address player, bytes32 commitment, uint256 choice, string memory salt) public {
        playerChoices[player] = choice;
        secretSalts[player] = salt;
        commitRecords[player] = commitment;

        emit CommitmentStored(player, commitment);
    }

    function reveal(address player, uint256 choice, string memory salt) public view returns (bool) {
        bytes32 expectedCommitment = getHash(choice, salt);
        return commitRecords[player] == expectedCommitment;
    }

    function getHash(uint256 choice, string memory salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, salt));
    }

    function clearCommitments(address player1, address player2) public {
        delete playerChoices[player1];
        delete playerChoices[player2];
        delete secretSalts[player1];
        delete secretSalts[player2];
        delete commitRecords[player1];
        delete commitRecords[player2];

        emit CommitmentsCleared(player1, player2);
    }
}
