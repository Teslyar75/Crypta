# Gas оптимизация

## ⛽ Что такое Gas?

**Gas** - плата за выполнение операций в Ethereum. Чем меньше газа, тем дешевле транзакция.

## 💰 Стоимость операций

```solidity
// Дорого (запись в storage)
uint public data = 100;  // ~20,000 gas

// Дешево (чтение)
function getData() public view returns (uint) {
    return data;  // ~2,300 gas
}

// Бесплатно (pure функции)
function add(uint a, uint b) public pure returns (uint) {
    return a + b;  // 0 gas (если вызвана локально)
}
```

## 🚀 Техники оптимизации

### 1. Используй memory вместо storage

```solidity
// ❌ Дорого
function sumArray(uint[] storage arr) internal returns (uint) {
    uint sum = 0;
    for (uint i = 0; i < arr.length; i++) {
        sum += arr[i];  // Каждое чтение из storage дорого
    }
    return sum;
}

// ✅ Дешево
function sumArray(uint[] memory arr) public pure returns (uint) {
    uint sum = 0;
    for (uint i = 0; i < arr.length; i++) {
        sum += arr[i];  // Чтение из memory дешево
    }
    return sum;
}
```

### 2. Кэшируй переменные storage

```solidity
// ❌ Дорого
function processData() public {
    for (uint i = 0; i < items.length; i++) {
        // items.length читается каждый раз!
    }
}

// ✅ Дешево
function processData() public {
    uint len = items.length;  // Кэш
    for (uint i = 0; i < len; i++) {
        // Используем кэшированное значение
    }
}
```

### 3. Используй uint256 вместо меньших типов

```solidity
// ❌ Может быть дороже
uint8 a;
uint16 b;

// ✅ Оптимально
uint256 a;
uint256 b;
```

**Исключение**: Упаковка в struct

```solidity
// ✅ Эффективная упаковка (один слот storage)
struct Data {
    uint128 a;
    uint128 b;
}
```

### 4. Используй calldata для внешних функций

```solidity
// ❌ Дороже
function process(uint[] memory data) external {
    // ...
}

// ✅ Дешевле
function process(uint[] calldata data) external {
    // ...
}
```

### 5. Удаляй неиспользуемые данные

```solidity
// Возврат газа при удалении
function remove(uint index) public {
    delete items[index];  // Возвращает газ
}
```

### 6. Используй events вместо storage

```solidity
// ❌ Дорого
string[] public logs;

function addLog(string memory log) public {
    logs.push(log);  // Очень дорого!
}

// ✅ Дешево
event Log(string message);

function addLog(string memory log) public {
    emit Log(log);  // Намного дешевле
}
```

### 7. Оптимизируй циклы

```solidity
// ❌ Неэффективно
for (uint i = 0; i < array.length; i++) {
    // array.length вычисляется каждый раз
}

// ✅ Эффективно
uint len = array.length;
for (uint i = 0; i < len; ++i) {  // ++i дешевле i++
    // ...
}
```

### 8. Используй mapping вместо array

```solidity
// ❌ Дорого для поиска
address[] public users;

function isUser(address user) public view returns (bool) {
    for (uint i = 0; i < users.length; i++) {
        if (users[i] == user) return true;
    }
    return false;
}

// ✅ Дешево
mapping(address => bool) public isUser;

function checkUser(address user) public view returns (bool) {
    return isUser[user];  // O(1)
}
```

### 9. Упаковка переменных

```solidity
// ❌ 3 слота storage (дорого)
uint256 a;  // Слот 0
uint128 b;  // Слот 1
uint128 c;  // Слот 2

// ✅ 2 слота storage (дешевле)
uint256 a;  // Слот 0
uint128 b;  // Слот 1
uint128 c;  // Слот 1 (упаковано с b)
```

### 10. Используй immutable и constant

```solidity
// ❌ Дорого (storage)
uint public fee = 100;

// ✅ Дешево (не использует storage)
uint public constant FEE = 100;
uint public immutable deployTime;

constructor() {
    deployTime = block.timestamp;
}
```

## 📊 Измерение газа

### hardhat.config.js

```javascript
module.exports = {
  gasReporter: {
    enabled: true,
    currency: 'USD',
    coinmarketcap: 'YOUR_API_KEY'
  }
};
```

### Запуск

```bash
REPORT_GAS=true npx hardhat test
```

## 🎯 Практические советы

1. **Профилируй код** - используй gas reporter
2. **Оптимизируй критические функции** - часто вызываемые
3. **Баланс читаемости и оптимизации** - не жертвуй читаемостью
4. **Тестируй после оптимизации** - убедись, что код работает

## Следующий шаг

Изучи [Upgradeable контракты](./02-Upgradeable-контракты.md)
