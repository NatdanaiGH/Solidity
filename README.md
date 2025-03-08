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
