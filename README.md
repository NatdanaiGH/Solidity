# 1. อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โค้ดป้องกันการล็อกเงินไว้ในสัญญาโดยใช้กลไกต่อไปนี้:

leaveGame()

ถ้าผู้เล่นเข้าร่วมเกมแล้วแต่ยังไม่มีคู่เล่น สามารถออกจากเกมและรับเงินคืนได้
require(playerCount < 2, "Game has started"); ป้องกันไม่ให้ถอนหลังจากเริ่มเกม
claimTimeout()

ถ้าผู้เล่นอีกฝ่ายไม่เปิดเผยผลการเล่น (reveal) ภายในเวลาที่กำหนด ผู้เล่นที่เปิดเผยแล้วสามารถรับเงินรางวัลทั้งหมดได้
ใช้ timeTracker.elapsedSeconds() ตรวจสอบเวลาที่ผ่านไป
refundSinglePlayer()

ถ้ามีผู้เล่นเพียงคนเดียวลงทะเบียนแต่ไม่มีคนที่สองเข้ามาภายในเวลาที่กำหนด ระบบจะคืนเงินให้
# 2. อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
ใช้เทคนิค commit-reveal เพื่อป้องกัน front-running
ผู้เล่นจะส่งค่าที่เป็น commitment ซึ่งเป็น hash ของ (choice + salt) ไปยัง commitReveal.commitMove()
การสร้าง commitment:

bytes32 commitment = keccak256(abi.encodePacked(choice, salt));
เมื่อส่ง commitment ไปแล้ว ผู้เล่นไม่สามารถเปลี่ยนใจได้ ทำให้เกมยุติธรรมขึ้น
# 3. อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
ใช้ timeTracker.elapsedSeconds() เพื่อตรวจสอบว่าเวลาผ่านไปนานพอที่จะบังคับจบเกมหรือยัง
ถ้าเกมเริ่มแล้วแต่มีผู้เล่นคนเดียวเปิดเผยผล อีกคนไม่เปิดเผย:
ใช้ claimTimeout() ให้ผู้เล่นที่เปิดเผยแล้วสามารถรับรางวัลทั้งหมด
ถ้ามีผู้เล่นแค่คนเดียวและไม่มีคู่แข่งเข้ามา:
ใช้ refundSinglePlayer() คืนเงินให้
# 4. อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ
เมื่อผู้เล่นทั้งสองเปิดเผยผล (discloseChoice()) ระบบจะตรวจสอบว่า hash ตรงกับที่ commit หรือไม่
นำค่าที่เปิดเผยมาเปรียบเทียบกันเพื่อหาผู้ชนะตามกติกา Rock, Paper, Scissors, Lizard, Spock
ใช้เงื่อนไขเพื่อตัดสินว่าใครชนะ

if ((choiceA + 1) % 5 == choiceB || (choiceA + 3) % 5 == choiceB) {
    playerB.transfer(prizePool);
} else if ((choiceB + 1) % 5 == choiceA || (choiceB + 3) % 5 == choiceA) {
    playerA.transfer(prizePool);
} else {
    playerA.transfer(prizePool / 2);
    playerB.transfer(prizePool / 2);
}
