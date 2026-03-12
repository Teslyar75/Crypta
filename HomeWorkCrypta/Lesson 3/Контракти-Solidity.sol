// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Навчальні смарт-контракти Solidity
 * @notice Збірка з 6 контрактів для вивчення основ розробки в Solidity
 * @dev Lesson 3 — базові структури даних, mapping, payable, доступ
 */

// ============================================
// 1. КОНТРАКТ-ЛІЧИЛЬНИК
// ============================================
/**
 * @title Counter
 * @notice Простий лічильник з можливістю збільшення та зменшення
 */
contract Counter {
    /// @notice Поточне значення лічильника (приватне — не видно ззовні)
    int256 private count;

    /// @notice Збільшує лічильник на 1
    function increment() public {
        count++;
    }

    /// @notice Зменшує лічильник на 1
    function decrement() public {
        count--;
    }

    /// @notice Повертає поточне значення лічильника
    /// @return Поточне значення (може бути від'ємним)
    function getCount() public view returns (int256) {
        return count;
    }
}

// ============================================
// 2. КОНТРАКТ СПИСКУ ЗАДАЧ
// ============================================
/**
 * @title TaskList
 * @notice Зберігання списку задач з можливістю додавання та видалення
 */
contract TaskList {
    /// @notice Масив рядків — список задач
    string[] private tasks;

    /// @notice Додає нову задачу до списку
    /// @param _task Текст задачі (рядок)
    function addTask(string memory _task) public {
        tasks.push(_task);
    }

    /// @notice Видаляє задачу за індексом (заміна останнім елементом для O(1))
    /// @param _index Індекс задачі для видалення (0-based)
    function deleteTask(uint256 _index) public {
        require(_index < tasks.length, "Index out of bounds");
        // Замінюємо елемент, що видаляється, останнім
        tasks[_index] = tasks[tasks.length - 1];
        tasks.pop();
    }

    /// @notice Повертає всі задачі зі списку
    /// @return Масив рядків — усі задачі
    function getAllTasks() public view returns (string[] memory) {
        return tasks;
    }

    /// @notice Повертає кількість задач у списку
    /// @return Кількість елементів у масиві tasks
    function getTaskCount() public view returns (uint256) {
        return tasks.length;
    }
}

// ============================================
// 3. КОНТРАКТ МАГАЗИНУ (ТОВАРИ)
// ============================================
/**
 * @title Shop
 * @notice Магазин з товарами, оплата в ETH (msg.value)
 */
contract Shop {
    /// @notice Структура товару
    struct Product {
        string name;   /// Назва товару
        uint256 price; /// Ціна в wei (1 ETH = 10^18 wei)
        bool exists;  /// Чи доступний для покупки (false = продано)
    }

    /// @notice Масив усіх товарів
    Product[] private products;
    /// @notice Адреса власника магазину (тільки він додає товари)
    address public owner;

    /// @notice При деплої власник = той, хто створив контракт
    constructor() {
        owner = msg.sender;
    }

    /// @notice Додає новий товар (тільки для власника)
    /// @param _name Назва товару
    /// @param _price Ціна в wei
    function addProduct(string memory _name, uint256 _price) public {
        require(msg.sender == owner, "Only owner can add products");
        products.push(Product(_name, _price, true));
    }

    /// @notice Купує товар за індексом (потрібно надіслати ETH з транзакцією)
    /// @param _index Індекс товару в масиві
    /// @dev msg.value — сума ETH, надіслана покупцем; решта повертається
    function buyProduct(uint256 _index) public payable {
        require(_index < products.length, "Product does not exist");
        Product storage product = products[_index];
        require(product.exists, "Product is not available");
        require(msg.value >= product.price, "Insufficient balance");

        // Решта — повертаємо покупцю
        uint256 change = msg.value - product.price;
        if (change > 0) {
            payable(msg.sender).transfer(change);
        }
        // Оплата — власнику магазину
        payable(owner).transfer(product.price);

        // Позначаємо товар як проданий
        product.exists = false;
    }

    /// @notice Повертає список усіх товарів з їхніми параметрами
    /// @return names Назви товарів
    /// @return prices Ціни
    /// @return available Чи доступні для покупки
    function getAllProducts() public view returns (
        string[] memory names,
        uint256[] memory prices,
        bool[] memory available
    ) {
        uint256 len = products.length;
        names = new string[](len);
        prices = new uint256[](len);
        available = new bool[](len);

        for (uint256 i = 0; i < len; i++) {
            names[i] = products[i].name;
            prices[i] = products[i].price;
            available[i] = products[i].exists;
        }
    }
}

// ============================================
// 4. КОНТРАКТ ГОЛОСУВАННЯ
// ============================================
/**
 * @title Voting
 * @notice Проста система голосування за кандидатів (один голос на адресу)
 */
contract Voting {
    /// @notice Структура кандидата
    struct Candidate {
        string name;     /// Ім'я кандидата
        uint256 voteCount; /// Кількість голосів
    }

    /// @notice Масив кандидатів
    Candidate[] public candidates;
    /// @notice Чи проголосувала вже ця адреса (захист від подвійного голосу)
    mapping(address => bool) public hasVoted;

    /// @notice Конструктор — створює кандидатів з масиву імен
    /// @param _candidateNames Масив імен кандидатів, напр. ["Alice", "Bob", "Carol"]
    constructor(string[] memory _candidateNames) {
        for (uint256 i = 0; i < _candidateNames.length; i++) {
            candidates.push(Candidate(_candidateNames[i], 0));
        }
    }

    /// @notice Проголосувати за кандидата за індексом
    /// @param _candidateIndex Індекс кандидата (0-based)
    function vote(uint256 _candidateIndex) public {
        require(_candidateIndex < candidates.length, "Invalid candidate");
        require(!hasVoted[msg.sender], "Already voted");

        hasVoted[msg.sender] = true;
        candidates[_candidateIndex].voteCount++;
    }

    /// @notice Отримати результати голосування
    /// @return names Імена кандидатів
    /// @return votes Кількість голосів кожного
    function getResults() public view returns (
        string[] memory names,
        uint256[] memory votes
    ) {
        uint256 len = candidates.length;
        names = new string[](len);
        votes = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            names[i] = candidates[i].name;
            votes[i] = candidates[i].voteCount;
        }
    }

    /// @notice Знайти переможця (кандидат з найбільшою кількістю голосів)
    /// @return winnerName Ім'я переможця
    /// @return winnerVotes Кількість його голосів
    function getWinner() public view returns (string memory winnerName, uint256 winnerVotes) {
        require(candidates.length > 0, "No candidates");
        uint256 maxVotes = 0;
        uint256 winnerIndex = 0;

        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount > maxVotes) {
                maxVotes = candidates[i].voteCount;
                winnerIndex = i;
            }
        }
        return (candidates[winnerIndex].name, maxVotes);
    }
}

// ============================================
// 5. КОНТРАКТ ПІДПИСОК
// ============================================
/**
 * @title Subscription
 * @notice Платна підписка на послугу (оплата в ETH, термін 30 днів)
 */
contract Subscription {
    /// @notice Час закінчення підписки для кожної адреси (timestamp)
    mapping(address => uint256) public subscriptionEnd;
    /// @notice Вартість підписки в wei (може змінювати адмін)
    uint256 public subscriptionPrice;
    /// @notice Адреса адміністратора
    address public admin;

    /// @notice Встановлює ціну підписки при деплої
    /// @param _price Ціна в wei
    constructor(uint256 _price) {
        admin = msg.sender;
        subscriptionPrice = _price;
    }

    /// @notice Оформити або продовжити підписку (надіслати ETH)
    /// @dev Якщо підписка ще активна — додає 30 днів; інакше — починає з поточного моменту
    function subscribe() public payable {
        require(msg.value >= subscriptionPrice, "Insufficient payment");
        uint256 duration = 30 days; // Solidity: 30 * 24 * 60 * 60 секунд

        if (subscriptionEnd[msg.sender] > block.timestamp) {
            // Підписка активна — продовжуємо
            subscriptionEnd[msg.sender] += duration;
        } else {
            // Нова підписка
            subscriptionEnd[msg.sender] = block.timestamp + duration;
        }
        // Решта — повертаємо
        if (msg.value > subscriptionPrice) {
            payable(msg.sender).transfer(msg.value - subscriptionPrice);
        }
        payable(admin).transfer(subscriptionPrice);
    }

    /// @notice Перевірити, чи активна підписка у користувача
    /// @param _user Адреса для перевірки
    /// @return true якщо subscriptionEnd > поточний час
    function isSubscriptionActive(address _user) public view returns (bool) {
        return subscriptionEnd[_user] > block.timestamp;
    }

    /// @notice Змінити вартість підписки (тільки адмін)
    /// @param _newPrice Нова ціна в wei
    function setSubscriptionPrice(uint256 _newPrice) public {
        require(msg.sender == admin, "Only admin");
        subscriptionPrice = _newPrice;
    }
}

// ============================================
// 6. КОНТРАКТ ФІНАНСУВАННЯ ПРОЄКТІВ
// ============================================
/**
 * @title CommunityFunding
 * @notice Спільнота пропонує проєкти, голосує, фінансує переможців з казни
 */
contract CommunityFunding {
    /// @notice Структура проєкту
    struct Project {
        address proposer;      /// Хто запропонував
        string description;    /// Опис проєкту
        uint256 requiredAmount; /// Потрібна сума в wei
        uint256 votes;         /// Кількість голосів
        bool funded;           /// Чи вже отримав фінансування
    }

    /// @notice Масив усіх проєктів
    Project[] public projects;
    /// @notice Чи голосував користувач за проєкт: hasVotedForProject[projectIndex][address]
    mapping(uint256 => mapping(address => bool)) public hasVotedForProject;
    /// @notice Казна — сума ETH для фінансування проєктів
    uint256 public treasury;
    /// @notice Адреса адміністратора
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    /// @notice Дозволяє контракту приймати ETH при звичайному переказі (без виклику функції)
    receive() external payable {
        treasury += msg.value;
    }

    /// @notice Запропонувати новий проєкт
    /// @param _description Опис проєкту
    /// @param _requiredAmount Потрібна сума в wei
    function proposeProject(string memory _description, uint256 _requiredAmount) public {
        projects.push(Project(msg.sender, _description, _requiredAmount, 0, false));
    }

    /// @notice Проголосувати за проєкт
    /// @param _projectIndex Індекс проєкту
    function voteForProject(uint256 _projectIndex) public {
        require(_projectIndex < projects.length, "Invalid project");
        require(!projects[_projectIndex].funded, "Project already funded");
        require(!hasVotedForProject[_projectIndex][msg.sender], "Already voted");

        hasVotedForProject[_projectIndex][msg.sender] = true;
        projects[_projectIndex].votes++;
    }

    /// @notice Виплатити кошти пропоненту проєкту (якщо є голоси та достатньо в казні)
    /// @param _projectIndex Індекс проєкту для фінансування
    function fundProject(uint256 _projectIndex) public {
        require(_projectIndex < projects.length, "Invalid project");
        Project storage project = projects[_projectIndex];
        require(!project.funded, "Already funded");
        require(treasury >= project.requiredAmount, "Insufficient treasury");
        require(project.votes > 0, "No votes");

        project.funded = true;
        treasury -= project.requiredAmount;
        payable(project.proposer).transfer(project.requiredAmount);
    }

    /// @notice Отримати список усіх проєктів
    /// @return proposers Адреси пропонентів
    /// @return descriptions Опис
    /// @return amounts Потрібні суми
    /// @return voteCounts Кількість голосів
    /// @return funded Чи вже отримали фінансування
    function getProjects() public view returns (
        address[] memory proposers,
        string[] memory descriptions,
        uint256[] memory amounts,
        uint256[] memory voteCounts,
        bool[] memory funded
    ) {
        uint256 len = projects.length;
        proposers = new address[](len);
        descriptions = new string[](len);
        amounts = new uint256[](len);
        voteCounts = new uint256[](len);
        funded = new bool[](len);

        for (uint256 i = 0; i < len; i++) {
            proposers[i] = projects[i].proposer;
            descriptions[i] = projects[i].description;
            amounts[i] = projects[i].requiredAmount;
            voteCounts[i] = projects[i].votes;
            funded[i] = projects[i].funded;
        }
    }

    /// @notice Поповнити казну (надіслати ETH разом з викликом)
    function depositToTreasury() public payable {
        treasury += msg.value;
    }
}
