# Детальне пояснення тестування GrandmaGifts (Lesson 6)

## Мета завдання

Покрити тестами контракт GrandmaGifts з Lesson 4, використовуючи Hardhat. Тести перевіряють коректність логіки депозиту, розподілу та зняття коштів онуками.

---

## Структура проекту

```
HomeWorkCrypta/Lesson 6/
├── contracts/
│   └── GrandmaGifts.sol    # Контракт (копія з Lesson 4)
├── test/
│   └── GrandmaGifts.test.js
├── hardhat.config.js
└── Пояснення-Lesson6.md
```

---

## Hardhat — що це?

**Hardhat** — середовище для розробки смарт-контрактів Ethereum. Надає:

- Компіляцію Solidity
- Локальну мережу для тестів
- Маніпуляцію часом (`evm_increaseTime`, `evm_setNextBlockTimestamp`)
- Інтеграцію з ethers.js для виклику контрактів

---

## Ключові концепції тестування

### 1. ethers.getSigners()

Повертає масив "гаманців" — тестових адрес з балансом. За замовчуванням 20 адрес.

```javascript
[grandma, grandchild1, grandchild2, stranger] = await ethers.getSigners();
```

### 2. Деплой контракту

```javascript
const GrandmaGifts = await ethers.getContractFactory("GrandmaGifts");
grandmaGifts = await GrandmaGifts.deploy(
  [grandchild1.address, grandchild2.address],  // онуки
  [100, 200]  // дні народження (1–365)
);
```

### 3. Виклик з різних адрес

```javascript
grandmaGifts.connect(grandma).deposit({ value: amount });   // від бабусі
grandmaGifts.connect(grandchild1).withdraw();               // від онука
grandmaGifts.connect(stranger).withdraw();                  // від стороннього
```

### 4. Перевірка revert

```javascript
await expect(grandmaGifts.connect(stranger).withdraw()).to.be.reverted;
```

### 5. Перевірка подій

```javascript
await expect(grandmaGifts.connect(grandchild1).withdraw())
  .to.emit(grandmaGifts, "Withdrawn")
  .withArgs(grandchild1.address, share);
```

---

## Маніпуляція часом

Контракт перевіряє день народження через `block.timestamp`:

```solidity
uint256 dayOfYear = ((block.timestamp / 1 days) % 365) + 1;
require(dayOfYear >= bd, "Birthday not yet this year");
```

У тестах ми не можемо "відмотати" час назад. Тому використовуємо **evm_increaseTime** — додаємо секунди до поточного часу.

### Формула для setBlockTimestamp

Потрібно знайти `daysToAdd` так, щоб після додавання:

```
((currentDays + daysToAdd) % 365) + 1 == dayOfYear
```

Тобто `(currentDays + daysToAdd) % 365 == dayOfYear - 1`.

```javascript
const targetRemainder = (dayOfYear - 1 + 365) % 365;
let daysToAdd = (targetRemainder - (currentDays % 365) + 365) % 365;
if (daysToAdd === 0) daysToAdd = 365;  // повний рік
await ethers.provider.send("evm_increaseTime", [daysToAdd * ONE_DAY]);
await ethers.provider.send("evm_mine", []);
```

---

## Опис тестових кейсів

| № | Тест | Що перевіряє |
|---|------|--------------|
| 1 | Деплой з онуками | grandma, grandchildren, birthDayOfYear |
| 2 | Внесення коштів | deposit(), totalDeposited |
| 3 | Закриття депозиту | closeDeposit() |
| 4 | Розподіл | getShare() == totalDeposited / 2 |
| 5 | Зняття у ДН | withdraw() у день 100, баланс збільшився |
| 6 | Зняття після ДН | withdraw() у день 150 |
| 7 | Revert до ДН | withdraw() у день 99 → відхилено |
| 8 | Revert до ДН (день 50) | додаткова перевірка |
| 9 | Повторне зняття | другий withdraw() → відхилено |
| 10 | Сторонній | stranger.withdraw() → відхилено |
| 11 | Подія Withdrawn | emit з правильними args |

---

## Запуск тестів

```bash
cd "HomeWorkCrypta/Lesson 6"
npx hardhat test --config ./hardhat.config.js
```

Або з кореня проекту:

```bash
npx hardhat test --config "HomeWorkCrypta/Lesson 6/hardhat.config.js"
```

---

## Поради

1. **beforeEach** — кожен тест виконується з чистого стану (новий деплой).
2. **evm_mine** — після `evm_increaseTime` потрібен новий блок, щоб час застосувався.
3. **parseEther** — `ethers.parseEther("1.5")` для роботи з 18 десятковими знаками.
4. **gasUsed** — при перевірці балансу враховуй витрати на gas.
