# Тестирование с Hardhat

## 🧪 Настройка тестирования

### Установка зависимостей

```bash
npm install --save-dev @nomiclabs/hardhat-waffle ethereum-waffle chai
npm install --save-dev @nomiclabs/hardhat-ethers ethers
```

### Структура тестов

```
test/
├── MyContract.test.js
├── Token.test.js
└── helpers.js
```

## ✍️ Написание тестов

### Базовый тест

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyContract", function () {
  let contract;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    // Получение аккаунтов
    [owner, addr1, addr2] = await ethers.getSigners();
    
    // Деплой контракта
    const Contract = await ethers.getContractFactory("MyContract");
    contract = await Contract.deploy();
    await contract.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await contract.owner()).to.equal(owner.address);
    });

    it("Should have zero balance initially", async function () {
      expect(await contract.getBalance()).to.equal(0);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens", async function () {
      await contract.transfer(addr1.address, 50);
      expect(await contract.balanceOf(addr1.address)).to.equal(50);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      await expect(
        contract.connect(addr1).transfer(owner.address, 1)
      ).to.be.revertedWith("Insufficient balance");
    });

    it("Should emit Transfer event", async function () {
      await expect(contract.transfer(addr1.address, 50))
        .to.emit(contract, "Transfer")
        .withArgs(owner.address, addr1.address, 50);
    });
  });
});
```

## 🔍 Продвинутое тестирование

### Тестирование времени

```javascript
const { time } = require("@nomicfoundation/hardhat-network-helpers");

it("Should unlock after time", async function () {
  const unlockTime = (await time.latest()) + 3600; // +1 час
  
  await time.increaseTo(unlockTime);
  
  await expect(contract.withdraw()).not.to.be.reverted;
});
```

### Тестирование событий

```javascript
it("Should emit event with correct parameters", async function () {
  await expect(contract.deposit({ value: 100 }))
    .to.emit(contract, "Deposit")
    .withArgs(owner.address, 100);
});
```

### Тестирование revert

```javascript
it("Should revert with custom error", async function () {
  await expect(contract.withdraw())
    .to.be.revertedWith("Too early");
    
  // Для custom errors (0.8.4+)
  await expect(contract.withdraw())
    .to.be.revertedWithCustomError(contract, "TooEarly");
});
```

### Тестирование изменения баланса

```javascript
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

it("Should change balances", async function () {
  await expect(() => 
    contract.transfer(addr1.address, 50)
  ).to.changeTokenBalances(
    contract,
    [owner, addr1],
    [-50, 50]
  );
});
```

## 🚀 Запуск тестов

```bash
# Все тесты
npx hardhat test

# Конкретный файл
npx hardhat test test/MyContract.test.js

# С покрытием кода
npx hardhat coverage

# С отчетом о газе
REPORT_GAS=true npx hardhat test
```

## 📊 Покрытие кода

### Установка

```bash
npm install --save-dev solidity-coverage
```

### hardhat.config.js

```javascript
require("solidity-coverage");

module.exports = {
  solidity: "0.8.19",
};
```

### Запуск

```bash
npx hardhat coverage
```

## 💡 Best Practices

1. **Тестируй все сценарии** - успешные и неуспешные
2. **Используй fixtures** - для переиспользования setup
3. **Проверяй события** - важная часть контракта
4. **Тестируй граничные случаи** - 0, максимальные значения
5. **Покрытие > 90%** - стремись к высокому покрытию

## Следующий шаг

Изучи [Деплой контрактов](./02-Деплой.md)
