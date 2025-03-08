1.อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract

-exitGame() หากผู้เล่นลงทะเบียนเข้าเกมแล้วเปลี่ยนใจ สามารถใช้ฟังก์ชันนี้เพื่อถอนเงินคืน (1 ETH) ได้ ตราบใดที่เกมยังไม่เริ่ม
ป้องกันปัญหาผู้เล่นเข้าร่วมแต่ไม่สามารถถอนเงินคืน


function exitGame() public {
    require(activePlayers[msg.sender], "Not a participant");
    require(playerCount < 2, "Game has started");
    
    payable(msg.sender).transfer(1 ether);
    activePlayers[msg.sender] = false;
    hasNotPlayed[msg.sender] = false;
    playerCount--;
}


-enforceGameEnd() หากเกมเริ่มแล้ว แต่ผู้เล่นไม่เปิดเผยตัวเลือกของตนภายใน 2 ชั่วโมง (7200 วินาที) ผู้เรียกฟังก์ชันสามารถรับเงินทั้งหมดใน prizePool ไปได้
ป้องกันกรณีที่ผู้เล่นไม่เปิดเผยตัวเลือก ทำให้เงินค้างอยู่ในสัญญา

function enforceGameEnd() public {
    require(playerCount == 2, "Game hasn't started");
    require(timeTracker.elapsedSeconds() > 7200, "Time limit not met");
   
    payable(msg.sender).transfer(prizePool);
    restartGame();
}


-refundSinglePlayer()หากมีผู้เล่นเพียงคนเดียวอยู่ในเกมนานเกิน 1 ชั่วโมง (3600 วินาที) สามารถขอเงินคืนได้
ป้องกันปัญหาผู้เล่นเข้าร่วมแล้วไม่มีคู่แข่ง ทำให้เงินติดอยู่ในเกม

function refundSinglePlayer() public {
    require(playerCount == 1, "Invalid game state");
    require(timeTracker.elapsedSeconds() > 3600, "Time limit not met");
   
    payable(participantList[0]).transfer(prizePool);
    restartGame();
}


2.อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit

การซ่อนตัวเลือกของผู้เล่น (Rock, Paper, Scissors, Lizard, Spock) ทำโดยใช้เทคนิค commit-reveal ซึ่งช่วยป้องกัน front-running (การดูข้อมูลของผู้เล่นก่อนแล้วโกง)

-การ Commit (ซ่อนข้อมูล)
ผู้เล่นส่งค่า commitment ที่เป็นค่าแฮชของ (choice, salt) ไปเก็บใน contract ผ่านฟังก์ชัน commitMove

function submitCommitment(bytes32 _commitment) external onlyParticipants {
    commitReveal.commitMove(msg.sender, _commitment, 0, "");
}
ภายใน CommitReveal.sol ฟังก์ชัน commitMove จะบันทึกค่าที่ถูกแฮชเอาไว้

function commitMove(address player, bytes32 commitment, uint256 choice, string memory salt) public {
    commitments[player] = commitment;
    choices[player] = choice;
    salts[player] = salt;
}
-การ Reveal (เปิดเผยข้อมูล)
ผู้เล่นต้องส่งค่าที่แท้จริงของ choice และ salt มาเพื่อตรวจสอบว่าตรงกับค่าที่ commit ไว้หรือไม่

function reveal(address player, uint256 choice, string memory salt) public view returns (bool) {
    bytes32 expectedCommitment = getHash(choice, salt);
    return commitments[player] == expectedCommitment;
}
ฟังก์ชัน getHash ใช้ keccak256 เพื่อสร้างค่าแฮชที่ใช้ตรวจสอบ

function getHash(uint256 choice, string memory salt) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(choice, salt));
}


