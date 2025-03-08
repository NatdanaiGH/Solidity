# 1.อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract

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




# 2.อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit

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




# 3.อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที

ในบางกรณี เกมอาจติดอยู่ในสถานะที่ไม่มีผู้เล่นครบสองคน หรือมีคนเข้ามาแต่ไม่เล่นต่อ โค้ดได้จัดการปัญหานี้ด้วยเงื่อนไขต่อไปนี้:

-exitGame() 

function exitGame() public {
    require(activePlayers[msg.sender], "Not a participant");
    require(playerCount < 2, "Game has started");

    payable(msg.sender).transfer(1 ether);
    activePlayers[msg.sender] = false;
    hasNotPlayed[msg.sender] = false;
    playerCount--;
}

-refundSinglePlayer() – ถ้าเกมค้างนานเกิน 1 ชั่วโมง และมีแค่ผู้เล่นคนเดียว

function refundSinglePlayer() public {
    require(playerCount == 1, "Invalid game state");
    require(timeTracker.elapsedSeconds() > 3600, "Time limit not met");

    payable(participantList[0]).transfer(prizePool);
    restartGame();
}

-enforceGameEnd() – ถ้าเกมเริ่มแล้ว แต่ไม่มีใครเปิดเผยตัวเลือกภายใน 2 ชั่วโมง

function enforceGameEnd() public {
    require(playerCount == 2, "Game hasn't started");
    require(timeTracker.elapsedSeconds() > 7200, "Time limit not met");

    payable(msg.sender).transfer(prizePool);
    restartGame();
}



# 4.อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ

-การเปิดเผยตัวเลือก (Reveal Choice)
ผู้เล่นต้องเปิดเผย choice และ salt เพื่อให้ระบบตรวจสอบความถูกต้อง

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

-การตัดสินผู้ชนะ
เมื่อผู้เล่นทั้งสองเปิดเผยตัวเลือกแล้ว ฟังก์ชัน determineWinner() จะใช้กฎของ Rock, Paper, Scissors, Lizard, Spock เพื่อตัดสินว่าใครชนะ

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
ใช้ (choiceA + 1) % 5 == choiceB และ (choiceA + 3) % 5 == choiceB เพื่อตรวจสอบว่าใครชนะ
หากผลเสมอ (else case) จะแบ่งเงินรางวัลให้ผู้เล่นทั้งสอง
