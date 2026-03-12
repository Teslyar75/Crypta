// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Lesson 5 — Інтерфейси, бібліотеки, наслідування
 * @notice Ігрові контракти: квести, ресурси, класи воїнів
 */

// ============================================
// 1. ІНТЕРФЕЙС IQuest ТА КОНТРАКТ QuestManager
// ============================================

/**
 * @title IQuest
 * @notice Інтерфейс для системи квестів
 * @dev Інтерфейс визначає "контракт" — які методи мають бути реалізовані
 */
interface IQuest {
    function startQuest(uint256 _questId) external returns (bool);
    function completeQuest(uint256 _questId) external returns (bool);
    function getReward(uint256 _questId) external returns (uint256);
}

/**
 * @title QuestManager
 * @notice Управління квестами, нагородами та рівнями гравців
 */
contract QuestManager is IQuest {
    // --- Структури ---
    struct Quest {
        uint256 id;
        string name;
        uint256 requiredLevel;   // Мінімальний рівень для старту
        uint256 rewardGold;     // Нагорода золотом
        uint256 rewardExp;      // Нагорода досвідом
        uint256 duration;       // Тривалість у секундах
        bool exists;
    }

    struct PlayerProgress {
        uint256 level;          // Рівень гравця
        uint256 experience;     // Досвід (exp для підвищення рівня)
        uint256 gold;           // Золото
        uint256 activeQuestId;  // ID активного квесту (0 = немає)
        uint256 questStartTime; // Час старту квесту
    }

    // --- Змінні ---
    mapping(uint256 => Quest) public quests;
    mapping(address => PlayerProgress) public players;
    uint256 public questCount;
    address public owner;

    // Константи для системи рівнів
    uint256 public constant EXP_PER_LEVEL = 100;  // Скільки exp потрібно для кожного рівня

    // --- Події ---
    event QuestStarted(address indexed player, uint256 questId);
    event QuestCompleted(address indexed player, uint256 questId, uint256 goldReward, uint256 expReward);
    event RewardClaimed(address indexed player, uint256 questId, uint256 gold);
    event LevelUp(address indexed player, uint256 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Owner додає новий квест
    function addQuest(
        string memory _name,
        uint256 _requiredLevel,
        uint256 _rewardGold,
        uint256 _rewardExp,
        uint256 _duration
    ) public onlyOwner {
        questCount++;
        quests[questCount] = Quest(
            questCount,
            _name,
            _requiredLevel,
            _rewardGold,
            _rewardExp,
            _duration,
            true
        );
    }

    /// @notice Почати квест (реалізація IQuest)
    function startQuest(uint256 _questId) external override returns (bool) {
        require(quests[_questId].exists, "Quest does not exist");
        require(players[msg.sender].activeQuestId == 0, "Already have active quest");
        require(players[msg.sender].level >= quests[_questId].requiredLevel, "Level too low");

        players[msg.sender].activeQuestId = _questId;
        players[msg.sender].questStartTime = block.timestamp;

        emit QuestStarted(msg.sender, _questId);
        return true;
    }

    /// @notice Завершити квест (реалізація IQuest)
    function completeQuest(uint256 _questId) external override returns (bool) {
        require(quests[_questId].exists, "Quest does not exist");
        require(players[msg.sender].activeQuestId == _questId, "Not your active quest");

        uint256 elapsed = block.timestamp - players[msg.sender].questStartTime;
        require(elapsed >= quests[_questId].duration, "Quest not finished yet");

        Quest memory q = quests[_questId];

        // Очищаємо активний квест
        players[msg.sender].activeQuestId = 0;
        players[msg.sender].questStartTime = 0;

        // Додаємо нагороди
        players[msg.sender].gold += q.rewardGold;
        _addExperience(msg.sender, q.rewardExp);

        emit QuestCompleted(msg.sender, _questId, q.rewardGold, q.rewardExp);
        return true;
    }

    /// @notice Отримати нагороду (для квестів з відкладеною нагородою)
    /// @dev У цій реалізації нагорода видається при completeQuest, тут — симуляція
    function getReward(uint256 _questId) external override returns (uint256) {
        require(quests[_questId].exists, "Quest does not exist");
        // У спрощеній версії нагорода вже при completeQuest, повертаємо 0
        return 0;
    }

    /// @notice Додати досвід та перевірити підвищення рівня
    function _addExperience(address _player, uint256 _exp) internal {
        players[_player].experience += _exp;

        // Перевіряємо, чи можна підвищити рівень
        while (players[_player].experience >= _expForNextLevel(players[_player].level)) {
            players[_player].experience -= _expForNextLevel(players[_player].level);
            players[_player].level++;
            emit LevelUp(_player, players[_player].level);
        }
    }

    /// @notice Скільки exp потрібно для наступного рівня
    function _expForNextLevel(uint256 _level) internal pure returns (uint256) {
        return EXP_PER_LEVEL * (_level + 1);
    }

    /// @notice Реєстрація нового гравця (рівень 1)
    function registerPlayer() public {
        require(players[msg.sender].level == 0, "Already registered");
        players[msg.sender] = PlayerProgress(1, 0, 0, 0, 0);
    }

    function getPlayerInfo(address _player) public view returns (
        uint256 level,
        uint256 experience,
        uint256 gold,
        uint256 activeQuestId
    ) {
        PlayerProgress storage p = players[_player];
        return (p.level, p.experience, p.gold, p.activeQuestId);
    }
}

// ============================================
// 2. БІБЛІОТЕКА ResourceUtils ТА ResourceManager
// ============================================

/**
 * @title ResourceUtils
 * @notice Бібліотека з функціями для управління ігровими ресурсами
 * @dev internal pure — не змінює стан, не зберігає даних
 */
library ResourceUtils {
    /// @notice Розподіл енергії між діями (енергія обмежена, треба вибирати)
    /// @param totalEnergy Загальна енергія
    /// @param actionCost Вартість однієї дії
    /// @return Кількість дій, які можна виконати
    function maxActionsFromEnergy(uint256 totalEnergy, uint256 actionCost) internal pure returns (uint256) {
        if (actionCost == 0) return type(uint256).max;
        return totalEnergy / actionCost;
    }

    /// @notice Вартість апгрейду (залежить від поточного рівня — експоненційне зростання)
    /// @param baseCost Базова вартість
    /// @param currentLevel Поточний рівень
    /// @param multiplier Множник (напр. 1.5 = 50% збільшення за рівень)
    function upgradeCost(
        uint256 baseCost,
        uint256 currentLevel,
        uint256 multiplier
    ) internal pure returns (uint256) {
        // Спрощена формула: baseCost * (multiplier ^ currentLevel)
        // Для Solidity без дробів: baseCost * (multiplier ** currentLevel) / (100 ** currentLevel)
        if (currentLevel == 0) return baseCost;
        uint256 cost = baseCost;
        for (uint256 i = 0; i < currentLevel; i++) {
            cost = (cost * multiplier) / 100;
        }
        return cost;
    }

    /// @notice Оптимізація витрату золота — перевірка, чи вистачає на покупку
    /// @param gold Поточне золото
    /// @param cost Вартість
    /// @param quantity Кількість
    /// @return Максимальна кількість, яку можна купити
    function optimalPurchaseQuantity(
        uint256 gold,
        uint256 cost,
        uint256 quantity
    ) internal pure returns (uint256) {
        if (cost == 0) return quantity;
        uint256 affordable = gold / cost;
        return affordable < quantity ? affordable : quantity;
    }

    /// @notice Відновлення енергії з часом (лінійне)
    /// @param currentEnergy Поточна енергія
    /// @param maxEnergy Максимум
    /// @param regenRate Швидкість відновлення (одиниць за секунду)
    /// @param timePassed Час у секундах
    function regenerateEnergy(
        uint256 currentEnergy,
        uint256 maxEnergy,
        uint256 regenRate,
        uint256 timePassed
    ) internal pure returns (uint256) {
        uint256 regenerated = regenRate * timePassed;
        uint256 newEnergy = currentEnergy + regenerated;
        return newEnergy > maxEnergy ? maxEnergy : newEnergy;
    }
}

/**
 * @title ResourceManager
 * @notice Управління ресурсами гравців (енергія, золото, апгрейди)
 */
contract ResourceManager {
    struct PlayerResources {
        uint256 energy;
        uint256 maxEnergy;
        uint256 gold;
        uint256 lastUpdateTime;  // Для відновлення енергії
        uint256 upgradeLevel;    // Рівень апгрейду
    }

    mapping(address => PlayerResources) public resources;

    uint256 public constant ENERGY_REGEN_RATE = 1;      // 1 енергія/сек
    uint256 public constant MAX_ENERGY_BASE = 100;
    uint256 public constant UPGRADE_BASE_COST = 50;
    uint256 public constant UPGRADE_MULTIPLIER = 120;   // 120% за рівень (1.2)

    event EnergyUsed(address indexed player, uint256 amount);
    event GoldEarned(address indexed player, uint256 amount);
    event Upgraded(address indexed player, uint256 newLevel);

    modifier hasResources() {
        require(resources[msg.sender].maxEnergy > 0, "Not registered");
        _;
    }

    constructor() {}

    /// @notice Реєстрація гравця
    function register() public {
        require(resources[msg.sender].maxEnergy == 0, "Already registered");
        resources[msg.sender] = PlayerResources({
            energy: MAX_ENERGY_BASE,
            maxEnergy: MAX_ENERGY_BASE,
            gold: 0,
            lastUpdateTime: block.timestamp,
            upgradeLevel: 0
        });
    }

    /// @notice Оновити енергію (за часом)
    function _updateEnergy(address _player) internal {
        PlayerResources storage r = resources[_player];
        uint256 timePassed = block.timestamp - r.lastUpdateTime;
        r.energy = ResourceUtils.regenerateEnergy(r.energy, r.maxEnergy, ENERGY_REGEN_RATE, timePassed);
        r.lastUpdateTime = block.timestamp;
    }

    /// @notice Використати енергію на дію
    function useEnergy(uint256 _amount) public hasResources {
        _updateEnergy(msg.sender);
        require(resources[msg.sender].energy >= _amount, "Not enough energy");
        resources[msg.sender].energy -= _amount;
        emit EnergyUsed(msg.sender, _amount);
    }

    /// @notice Додати золото (напр. за квест)
    function addGold(uint256 _amount) public hasResources {
        resources[msg.sender].gold += _amount;
        emit GoldEarned(msg.sender, _amount);
    }

    /// @notice Апгрейд (збільшує maxEnergy)
    function upgrade() public hasResources {
        uint256 cost = ResourceUtils.upgradeCost(
            UPGRADE_BASE_COST,
            resources[msg.sender].upgradeLevel,
            UPGRADE_MULTIPLIER
        );
        require(resources[msg.sender].gold >= cost, "Not enough gold");

        resources[msg.sender].gold -= cost;
        resources[msg.sender].upgradeLevel++;
        resources[msg.sender].maxEnergy += 20;

        emit Upgraded(msg.sender, resources[msg.sender].upgradeLevel);
    }

    /// @notice Скільки дій можна виконати з поточною енергією (викликай updateEnergyBeforeAction перед цим для актуальних даних)
    function getMaxActions(uint256 _actionCost) public view returns (uint256) {
        return ResourceUtils.maxActionsFromEnergy(resources[msg.sender].energy, _actionCost);
    }

    /// @notice Оновити енергію перед перевіркою (викликай перед getMaxActions для актуальності)
    function updateEnergyBeforeAction() public hasResources {
        _updateEnergy(msg.sender);
    }

    function getUpgradeCost() public view returns (uint256) {
        return ResourceUtils.upgradeCost(
            UPGRADE_BASE_COST,
            resources[msg.sender].upgradeLevel,
            UPGRADE_MULTIPLIER
        );
    }
}

// ============================================
// 3. БАЗОВИЙ КОНТРАКТ WarriorGuild ТА ПІДКЛАСИ
// ============================================

/**
 * @title WarriorGuild
 * @notice Базовий контракт для реєстрації воїнів
 * @dev virtual — функції можна перевизначити в підкласах; override — перевизначення
 */
contract WarriorGuild {
    struct Warrior {
        address owner;
        string name;
        uint256 health;
        uint256 maxHealth;
        uint256 level;
        bool registered;
    }

    mapping(address => Warrior) public warriors;
    address[] public warriorList;

    event WarriorRegistered(address indexed owner, string name);
    event WarriorAttacked(address indexed attacker, address indexed target, uint256 damage);

    modifier onlyRegistered() {
        require(warriors[msg.sender].registered, "Not registered");
        _;
    }

    /// @notice Реєстрація воїна
    function registerWarrior(string memory _name) public virtual {
        require(!warriors[msg.sender].registered, "Already registered");
        warriors[msg.sender] = Warrior({
            owner: msg.sender,
            name: _name,
            health: 100,
            maxHealth: 100,
            level: 1,
            registered: true
        });
        warriorList.push(msg.sender);
        emit WarriorRegistered(msg.sender, _name);
    }

    /// @notice Виртуальна функція — кожен підклас перевизначає (override) зі своєю логікою
    /// @dev virtual дозволяє override в Knight, Mage, Assassin
    function attack(address _target) public virtual onlyRegistered returns (uint256 damage) {
        require(warriors[_target].registered, "Target not registered");
        require(warriors[_target].health > 0, "Target already dead");

        damage = _calculateDamage(msg.sender, _target);
        warriors[_target].health = warriors[_target].health > damage
            ? warriors[_target].health - damage
            : 0;

        emit WarriorAttacked(msg.sender, _target, damage);
        return damage;
    }

    /// @notice Базова формула урону (перевизначається в підкласах)
    function _calculateDamage(address _attacker, address _target) internal view virtual returns (uint256) {
        return 10; // Базовий урон
    }

    /// @notice Відновлення здоров'я
    function heal(uint256 _amount) public onlyRegistered {
        require(warriors[msg.sender].health < warriors[msg.sender].maxHealth, "Already full health");
        warriors[msg.sender].health += _amount;
        if (warriors[msg.sender].health > warriors[msg.sender].maxHealth) {
            warriors[msg.sender].health = warriors[msg.sender].maxHealth;
        }
    }

    function getWarriorInfo(address _addr) public view returns (
        string memory name,
        uint256 health,
        uint256 maxHealth,
        uint256 level
    ) {
        Warrior storage w = warriors[_addr];
        return (w.name, w.health, w.maxHealth, w.level);
    }
}

/**
 * @title Knight
 * @notice Лицар — високий захист (броня), стабільний урон
 */
contract Knight is WarriorGuild {
    uint256 public constant KNIGHT_BASE_DAMAGE = 15;
    uint256 public constant KNIGHT_ARMOR = 5;  // Зменшення вхідного урону (броня)

    function _calculateDamage(address _attacker, address _target) internal view override returns (uint256) {
        // Лицар: стабільний урон + бонус за рівень
        return KNIGHT_BASE_DAMAGE + (warriors[_attacker].level * 2);
    }

    /// @notice Лицар має броню — вхідний урон зменшується на KNIGHT_ARMOR
    function attack(address _target) public override onlyRegistered returns (uint256 damage) {
        require(warriors[_target].registered, "Target not registered");
        require(warriors[_target].health > 0, "Target already dead");

        damage = _calculateDamage(msg.sender, _target);
        damage = damage > KNIGHT_ARMOR ? damage - KNIGHT_ARMOR : 0; // Броня зменшує урон
        warriors[_target].health = warriors[_target].health > damage
            ? warriors[_target].health - damage
            : 0;

        emit WarriorAttacked(msg.sender, _target, damage);
        return damage;
    }
}

/**
 * @title Mage
 * @notice Маг — сильний урон, але випадковий (симуляція через хеш)
 */
contract Mage is WarriorGuild {
    uint256 public constant MAGE_MIN_DAMAGE = 5;
    uint256 public constant MAGE_MAX_DAMAGE = 35;

    function _calculateDamage(address _attacker, address _target) internal view override returns (uint256) {
        // Маг: випадковий урон у діапазоні (псевдо-рандом через block)
        uint256 range = MAGE_MAX_DAMAGE - MAGE_MIN_DAMAGE;
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            _attacker,
            _target
        ))) % (range + 1);
        return MAGE_MIN_DAMAGE + random + (warriors[_attacker].level * 3);
    }
}

/**
 * @title Assassin
 * @notice Асасин — критичний удар (шанс подвоїти урон)
 */
contract Assassin is WarriorGuild {
    uint256 public constant ASSASSIN_BASE_DAMAGE = 12;
    uint256 public constant CRIT_CHANCE = 30;  // 30% шанс криту

    function _calculateDamage(address _attacker, address _target) internal view override returns (uint256) {
        uint256 base = ASSASSIN_BASE_DAMAGE + (warriors[_attacker].level * 4);
        uint256 critRoll = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            _attacker,
            _target
        ))) % 100;
        if (critRoll < CRIT_CHANCE) {
            return base * 2; // Критичний удар
        }
        return base;
    }
}
