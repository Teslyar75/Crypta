const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * Тести для контракту GrandmaGifts (Lesson 6)
 *
 * Покриття:
 * 1. Деплой, внесення коштів, задання онуків
 * 2. Правильний розподіл суми
 * 3. Зняття у день народження
 * 4. Зняття після дня народження
 * 5. Revert до дня народження
 * 6. Revert при повторному знятті
 * 7. Revert для стороннього
 * 8. Подія Withdrawn
 *
 * dayOfYear = ((block.timestamp / 86400) % 365) + 1
 */
describe("GrandmaGifts", function () {
  let grandmaGifts;
  let grandma, grandchild1, grandchild2, stranger;

  const ONE_DAY = 86400;
  const DEPOSIT_AMOUNT = ethers.parseEther("3"); // 3 ETH

  /**
   * Додає секунди, щоб досягти потрібного дня року.
   * dayOfYear = ((block.timestamp / 86400) % 365) + 1
   */
  async function setBlockTimestamp(dayOfYear) {
    const block = await ethers.provider.getBlock("latest");
    const currentDays = Math.floor(Number(block.timestamp) / ONE_DAY);
    const targetRemainder = (dayOfYear - 1 + 365) % 365;

    let daysToAdd = (targetRemainder - (currentDays % 365) + 365) % 365;
    if (daysToAdd === 0) daysToAdd = 365;

    await ethers.provider.send("evm_increaseTime", [daysToAdd * ONE_DAY]);
    await ethers.provider.send("evm_mine", []);
  }

  beforeEach(async function () {
    [grandma, grandchild1, grandchild2, stranger] = await ethers.getSigners();

    const GrandmaGifts = await ethers.getContractFactory("GrandmaGifts");
    grandmaGifts = await GrandmaGifts.deploy(
      [grandchild1.address, grandchild2.address],
      [100, 200] // ДН онука1 = день 100, онука2 = день 200
    );
  });

  describe("1. Деплой, внесення коштів, задання онуків", function () {
    it("Бабуся може задеплоїти контракт з онуками та датами народження", async function () {
      expect(await grandmaGifts.grandma()).to.equal(grandma.address);
      expect(await grandmaGifts.grandchildren(0)).to.equal(grandchild1.address);
      expect(await grandmaGifts.grandchildren(1)).to.equal(grandchild2.address);
      expect(await grandmaGifts.birthDayOfYear(grandchild1.address)).to.equal(100);
      expect(await grandmaGifts.birthDayOfYear(grandchild2.address)).to.equal(200);
    });

    it("Бабуся може внести кошти", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      expect(await grandmaGifts.totalDeposited()).to.equal(DEPOSIT_AMOUNT);
    });

    it("Бабуся може закрити депозит", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();
      expect(await grandmaGifts.depositClosed()).to.be.true;
    });
  });

  describe("2. Правильний розподіл суми між онуками", function () {
    it("Сума правильно ділиться на кількість онуків", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      const share = await grandmaGifts.getShare();
      expect(share).to.equal(ethers.parseEther("1.5")); // 3 ETH / 2 = 1.5 ETH
    });
  });

  describe("3. Успішне зняття у день народження", function () {
    it("Онук може зняти у день народження", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(100); // День 100 — ДН першого онука

      const balanceBefore = await ethers.provider.getBalance(grandchild1.address);
      const tx = await grandmaGifts.connect(grandchild1).withdraw();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const balanceAfter = await ethers.provider.getBalance(grandchild1.address);

      expect(balanceAfter).to.equal(balanceBefore + ethers.parseEther("1.5") - gasUsed);
      expect(await grandmaGifts.hasWithdrawn(grandchild1.address)).to.be.true;
    });
  });

  describe("4. Успішне зняття після дня народження", function () {
    it("Онук може зняти після дня народження", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(150); // День 150 — після ДН (100)

      const balanceBefore = await ethers.provider.getBalance(grandchild1.address);
      await grandmaGifts.connect(grandchild1).withdraw();
      const balanceAfter = await ethers.provider.getBalance(grandchild1.address);

      expect(balanceAfter).to.be.gt(balanceBefore);
      expect(await grandmaGifts.hasWithdrawn(grandchild1.address)).to.be.true;
    });
  });

  describe("5. Спроба зняти до дня народження", function () {
    it("Транзакцію відхилено при виклику до дня народження", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(99); // День 99 — ще не ДН (100)

      await expect(grandmaGifts.connect(grandchild1).withdraw()).to.be.reverted;
    });

    it("Revert при dayOfYear < birthDay", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(50); // Набагато раніше

      await expect(grandmaGifts.connect(grandchild1).withdraw()).to.be.reverted;
    });
  });

  describe("6. Повторне зняття", function () {
    it("Транзакцію відхилено при повторному знятті", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(100);
      await grandmaGifts.connect(grandchild1).withdraw();

      await expect(grandmaGifts.connect(grandchild1).withdraw()).to.be.reverted;
    });
  });

  describe("7. Спроба стороннього виклику", function () {
    it("Сторонній не може зняти (не онук)", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(365); // Будь-який день — stranger не онук

      await expect(grandmaGifts.connect(stranger).withdraw()).to.be.reverted;
    });
  });

  describe("8. Подія при знятті", function () {
    it("При знятті генерується подія Withdrawn з правильною адресою та сумою", async function () {
      await grandmaGifts.connect(grandma).deposit({ value: DEPOSIT_AMOUNT });
      await grandmaGifts.connect(grandma).closeDeposit();

      await setBlockTimestamp(100);

      const share = ethers.parseEther("1.5");
      await expect(grandmaGifts.connect(grandchild1).withdraw())
        .to.emit(grandmaGifts, "Withdrawn")
        .withArgs(grandchild1.address, share);
    });
  });
});
