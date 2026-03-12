# Детальне пояснення контрактів Lesson 5

## 1. Інтерфейси (interface)

### Що таке інтерфейс?

Інтерфейс — це "контракт" між контрактом та зовнішнім світом. Він визначає **сигнатури** функцій (ім'я, параметри, тип повернення), але не їх реалізацію.

```solidity
interface IQuest {
    function startQuest(uint256 _questId) external returns (bool);
    function completeQuest(uint256 _questId) external returns (bool);
    function getReward(uint256 _questId) external returns (uint256);
}
```

### Навіщо потрібен?

1. **Абстракція** — можна працювати з різними реалізаціями через один інтерфейс
2. **Перевірка** — контракт, що `is IQuest`, зобов'язаний реалізувати всі методи
3. **Виклик зовнішніх контрактів** — знаючи адресу, можна викликати методи через інтерфейс

### external

У інтерфейсах функції завжди `external` — їх можна викликати лише ззовні (або через `this.func()`).

### override

Коли контракт реалізує інтерфейс, функції позначають `override`:

```solidity
function startQuest(uint256 _questId) external override returns (bool) {
    // ...
}
```

---

## 2. QuestManager — система квестів та рівнів

### Структура Quest

- **requiredLevel** — мінімальний рівень для старту
- **duration** — скільки секунд має пройти до завершення
- **rewardGold**, **rewardExp** — нагороди

### Система рівнів

```solidity
uint256 public constant EXP_PER_LEVEL = 100;
```

Для кожного рівня потрібно більше exp: рівень 1→2 = 100, 2→3 = 200, тощо.

```solidity
function _expForNextLevel(uint256 _level) internal pure returns (uint256) {
    return EXP_PER_LEVEL * (_level + 1);
}
```

### Логіка completeQuest

1. Перевірка: квест активний, минуло достатньо часу
2. Очищення activeQuestId
3. Додавання gold та exp
4. Виклик `_addExperience` — можливе підвищення рівня

### memory vs storage у функціях

```solidity
Quest memory q = quests[_questId];  // Копія, не змінює оригінал
PlayerProgress storage p = players[_player];  // Посилання, зміни зберігаються
```

---

## 3. Бібліотека ResourceUtils

### Чисті функції (pure)

Бібліотека містить лише `pure` функції — вони не читають і не змінюють стан. Тільки обчислення.

### maxActionsFromEnergy

Скільки дій можна виконати при обмеженій енергії:
```
дій = енергія / вартість_однієї_дії
```

### upgradeCost

Вартість апгрейду зростає з рівнем. Формула (спрощена):
```
cost = baseCost * (multiplier/100) ^ currentLevel
```

У Solidity немає дробів, тому використовуємо цілочисельну арифметику з циклом.

### optimalPurchaseQuantity

Скільки одиниць можна купити за наявне золото:
```
affordable = gold / cost
return min(affordable, quantity)
```

### regenerateEnergy

Відновлення енергії з часом (лінійне):
```
newEnergy = currentEnergy + regenRate * timePassed
return min(newEnergy, maxEnergy)
```

---

## 4. ResourceManager — використання бібліотеки

### Виклик функцій бібліотеки

```solidity
ResourceUtils.upgradeCost(UPGRADE_BASE_COST, level, UPGRADE_MULTIPLIER)
ResourceUtils.regenerateEnergy(...)
```

Бібліотека викликається як `LibraryName.functionName(args)`.

### Відновлення енергії за часом

При кожній дії (useEnergy, upgrade) викликається `_updateEnergy`, яка перераховує енергію з моменту останнього оновлення.

### view та зміна стану

`getMaxActions` — view, тому не може викликати `_updateEnergy` (вона змінює стан). Тому енергія може бути "застарілою". Для актуальності — окрема функція `updateEnergyBeforeAction()`.

---

## 5. Наслідування (inheritance)

### Базовий контракт

```solidity
contract WarriorGuild {
    // Спільні дані та логіка
    function attack(address _target) public virtual returns (uint256 damage) {
        // Базова реалізація
    }
    function _calculateDamage(...) internal view virtual returns (uint256) {
        return 10;  // Базовий урон
    }
}
```

### virtual та override

- **virtual** — функцію можна перевизначити в підкласі
- **override** — ця функція перевизначає батьківську

```solidity
contract Knight is WarriorGuild {
    function _calculateDamage(...) internal view override returns (uint256) {
        return KNIGHT_BASE_DAMAGE + (warriors[_attacker].level * 2);
    }
}
```

### super

Виклик батьківської реалізації:

```solidity
super.attack(_target);  // Викликає WarriorGuild.attack
```

### Доступ до змінних батька

Підклас має доступ до `warriors`, `warriorList`, `onlyRegistered` — вони успадковані.

---

## 6. Класи воїнів — унікальні механіки

### Knight (Лицар)

- **Урон**: стабільний, 15 + 2×рівень
- **Броня**: вхідний урон зменшується на 5
- Реалізація: перевизначений `attack()` з логікою `damage -= KNIGHT_ARMOR`

### Mage (Маг)

- **Урон**: випадковий у діапазоні 5–35 + 3×рівень
- Псевдо-рандом через `keccak256(block.timestamp, block.difficulty, ...)`
- `% (range + 1)` дає число від 0 до range

### Assassin (Асасин)

- **Урон**: 12 + 4×рівень
- **Критичний удар**: 30% шанс подвоїти урон
- `critRoll = hash % 100` — якщо < 30, то крит

---

## 7. Деплой

### Окремий деплой кожного підкласу

- **QuestManager** — без параметрів
- **ResourceManager** — без параметрів
- **Knight** — без параметрів (окремий контракт для лицарів)
- **Mage** — без параметрів (окремий для магів)
- **Assassin** — без параметрів (окремий для асасинів)

Кожен підклас WarriorGuild має власний `warriors` mapping — воїни різних класів не взаємодіють між контрактами.

### Послідовність для QuestManager

1. `registerPlayer()` — гравець
2. `addQuest(...)` — owner додає квест
3. `startQuest(1)` — гравець починає
4. Чекати `duration` секунд
5. `completeQuest(1)` — завершити та отримати нагороду

---

## 8. Поради

1. **Інтерфейси** — використовуй для абстракції та взаємодії між контрактами
2. **Бібліотеки** — для перевикористовуваної логіки без стану
3. **Наслідування** — для спільної бази з унікальними варіантами
