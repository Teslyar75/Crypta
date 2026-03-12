# Детальне пояснення контрактів Lesson 4

## 1. Бібліотеки та using for

### Що таке library в Solidity?

Бібліотека — це контракт без стану (або з мінімальним станом), що містить перевикористовувані функції. Вона не має змінних стану (або має лише для внутрішнього використання).

```solidity
library ArrayLibrary {
    function indexOf(uint256[] storage arr, uint256 value) internal view returns (uint256) {
        // ...
    }
}
```

### internal

Функції бібліотеки зазвичай `internal` — їх можна викликати лише з контракту, що її підключає.

### storage vs memory

- `uint256[] storage arr` — функція працює з масивом, що зберігається в блокчейні (модифікує його)
- `uint256[] memory arr` — тимчасовий масив, зміни не зберігаються

### using for

```solidity
using ArrayLibrary for uint256[];
uint256[] private data;
// Тепер можна викликати: data.remove(0), data.sort(), data.indexOf(5)
```

`using ArrayLibrary for uint256[]` означає: для типу `uint256[]` додати методи з `ArrayLibrary`. Перший параметр функції бібліотеки стає об'єктом виклику.

### type(uint256).max

Повертає максимальне значення `uint256`. Використовується як "не знайдено" замість -1 (бо uint не може бути від'ємним).

---

## 2. Бабуся та онуки

### Логіка завдання

- Бабуся вносить ETH на депозит
- Сума ділиться на кількість онуків
- Кожен онук забирає свою частку у день народження або після

### День народження

Зберігаємо як **день року (1–365)**:
- 1 = 1 січня
- 365 = 31 грудня

### Перевірка "день народження вже минув"

```solidity
uint256 dayOfYear = (block.timestamp / 1 days) % 365;
require(dayOfYear >= bd, "Birthday not yet this year");
```

`block.timestamp / 1 days` — кількість днів з епохи Unix. `% 365` дає приблизний день року (без урахування високосних років, але достатньо для навчального прикладу).

### closeDeposit

Бабуся закриває депозит, щоб фіксувати суму. Після цього подальші внески неможливі — онуки отримують рівні частки від зафіксованої суми.

### Розподіл

```solidity
uint256 share = totalDeposited / grandchildren.length;
```

Цілочисельне ділення — залишок залишається в контракті. Для точного розподілу потрібна більш складна логіка.

---

## 3. Фонд освітніх грантів

### Enum GrantStatus

```solidity
enum GrantStatus { Active, Frozen, Paid }
```

- **Active** — студент накопичує, мета не досягнута
- **Frozen** — заморожено через невиконання умов
- **Paid** — грант виплачено

### Роль owner

Тільки власник контракту може:
- реєструвати студентів
- підтверджувати досягнення мети (`confirmGoalReached`)
- заморожувати/розморожувати студентів

### Події (events)

```solidity
event GoalReached(address indexed student, uint256 amount);
emit GoalReached(_student, s.balance);
```

Події зберігаються в логах транзакцій. `indexed` дозволяє фільтрувати за цим полем. Фронтенд може слухати події через Web3.

### Модифікатори

```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "Only owner");
    _;  // тіло функції виконується тут
}
```

`_` — місце вставки коду функції. Модифікатор перевіряє умову перед виконанням.

### Логіка роботи

1. **registerStudent** — owner додає студента з цільовою сумою
2. **deposit** — студент або родичі вносять кошти
3. **confirmGoalReached** — owner підтверджує досягнення (наприклад, вступ до університету)
4. **withdrawGrant** — студент забирає кошти
5. **freezeStudent** — owner заморожує при порушенні умов
6. **unfreezeStudent** — owner розморожує після виправлення

---

## 4. Фонд екстреної допомоги

### Багатостороннє підтвердження

Щоб уникнути зловживань, виплата потребує підтвердження від кількох учасників:

```solidity
uint256 public requiredConfirmations;
mapping(bytes32 => uint256) public requestConfirmations;
```

Кожен учасник викликає `confirmWithdrawal(requestId)`. Коли `requestConfirmations[requestId] >= requiredConfirmations`, можна виконати виплату.

### bytes32 requestId

Унікальний ідентифікатор заявки:

```solidity
bytes32 requestId = keccak256(abi.encodePacked(block.timestamp, msg.sender, _beneficiary, _amount, _reason));
```

`keccak256` — хеш-функція. `abi.encodePacked` — упаковка аргументів у байти. Результат — унікальний ID заявки.

### Зберігання заявки

```solidity
struct WithdrawalRequest {
    address beneficiary;
    uint256 amount;
    string reason;
    bool exists;
}
mapping(bytes32 => WithdrawalRequest) public requests;
```

При створенні заявки зберігаємо beneficiary, amount, reason. При виконанні беремо їх із mapping — не потрібно передавати повторно.

### Роль medicalAuthority

Окрема адреса (наприклад, медична організація) може виконувати виплату разом з owner. Це додатковий захист і довіра.

### Логіка роботи

1. **contribute** — учасники щомісяця вносять кошти
2. **requestWithdrawal** — учасник створює заявку на виплату (beneficiary, amount, reason)
3. **confirmWithdrawal** — інші учасники підтверджують заявку
4. **executeWithdrawal** — owner або medicalAuthority виконує виплату після достатньої кількості підтверджень

---

## Деплой контрактів

### ArrayUtils
Без параметрів.

### GrandmaGiftsSimple
```solidity
// Адреси онуків та дні народження (1-365)
["0x123...", "0x456..."], [15, 200]  // 15 січня, 200-й день року
```

### EducationGrantFund
Без параметрів. Потім викликати `registerStudent` для кожного студента.

### EmergencyFund
```solidity
// Учасники, кількість підтверджень, адреса медичної організації
["0x...", "0x..."], 2, "0xMedicalAuthority..."
```

---

## Поради з безпеки

1. **Reentrancy** — для контрактів з переказами використовуй патерн Checks-Effects-Interactions
2. **Integer overflow** — Solidity 0.8+ перевіряє автоматично
3. **Access control** — обмежуй критичні функції модифікаторами
4. **Storage** — зберігання даних коштує gas, уникай зайвих записів
