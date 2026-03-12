// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Lesson 4 — Бібліотеки, модифікатори, події, складні контракти
 * @notice Збірка з 4 контрактів: ArrayUtils, GrandmaGifts, EducationGrantFund, EmergencyFund
 */

// ============================================
// 1. БІБЛІОТЕКА ТА КОНТРАКТ ArrayUtils
// ============================================
// Бібліотека (library) — набір функцій без власного стану.
// Використовується через "using ... for" — тоді масив отримує методи бібліотеки.

/**
 * @title ArrayLibrary
 * @notice Бібліотека з функціями для роботи з масивами uint256
 * @dev Функції internal — викликаються лише з контракту, що підключив бібліотеку
 */
library ArrayLibrary {
    /// @notice Шукає індекс елемента в масиві
    /// @param arr Масив для пошуку (storage — зміни зберігаються в блокчейні)
    /// @param value Значення для пошуку
    /// @return Індекс елемента або type(uint256).max (максимальне число) якщо не знайдено
    function indexOf(uint256[] storage arr, uint256 value) internal view returns (uint256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return i;
        }
        // type(uint256).max — "магічне" значення "не знайдено" (uint не може бути -1)
        return type(uint256).max;
    }

    /// @notice Видаляє елемент за індексом
    /// @dev Трюк: замінюємо елемент останнім, потім pop() — це O(1) замість O(n)
    function remove(uint256[] storage arr, uint256 index) internal {
        require(index < arr.length, "Index out of bounds");
        arr[index] = arr[arr.length - 1]; // Останній елемент переміщуємо на місце видаленого
        arr.pop(); // Прибираємо останній (тепер дублікат)
    }

    /// @notice Видаляє перше входження елемента за значенням
    function removeByValue(uint256[] storage arr, uint256 value) internal {
        uint256 idx = indexOf(arr, value);
        if (idx != type(uint256).max) remove(arr, idx);
    }

    /// @notice Сортує масив за зростанням (bubble sort — простий, але повільний для великих масивів)
    function sort(uint256[] storage arr) internal {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (arr[i] > arr[j]) {
                    // Обмін значень через tuple assignment
                    (arr[i], arr[j]) = (arr[j], arr[i]);
                }
            }
        }
    }

    /// @notice Перевіряє наявність значення в масиві
    function contains(uint256[] storage arr, uint256 value) internal view returns (bool) {
        return indexOf(arr, value) != type(uint256).max;
    }
}

/**
 * @title ArrayUtils
 * @notice Контракт, що використовує ArrayLibrary
 * @dev "using ArrayLibrary for uint256[]" — тепер можна писати data.remove(0) замість ArrayLibrary.remove(data, 0)
 */
contract ArrayUtils {
    using ArrayLibrary for uint256[]; // Розширює тип uint256[] методами з бібліотеки

    uint256[] private data; // Приватний масив — зберігає дані в блокчейні

    // Події — записуються в логах транзакцій, фронтенд може їх слухати
    event ElementAdded(uint256 value, uint256 index);
    event ElementRemoved(uint256 value, uint256 index);
    event ArraySorted();

    function add(uint256 _value) public {
        data.push(_value);
        emit ElementAdded(_value, data.length - 1);
    }

    function remove(uint256 _index) public {
        require(_index < data.length, "Index out of bounds");
        uint256 value = data[_index];
        data.remove(_index); // Виклик методу бібліотеки — data стає першим аргументом
        emit ElementRemoved(value, _index);
    }

    function removeByValue(uint256 _value) public {
        data.removeByValue(_value);
    }

    function sort() public {
        data.sort();
        emit ArraySorted();
    }

    function indexOf(uint256 _value) public view returns (uint256) {
        return data.indexOf(_value);
    }

    function contains(uint256 _value) public view returns (bool) {
        return data.contains(_value);
    }

    function getAll() public view returns (uint256[] memory) {
        return data;
    }

    function length() public view returns (uint256) {
        return data.length;
    }
}

// ============================================
// 2. БАБУСЯ ТА ОНУКИ (ПОДАРУНКИ НА ДЕНЬ НАРОДЖЕННЯ)
// ============================================
// Логіка: бабуся вносить ETH → сума ділиться на онуків → кожен забирає у свій ДН або після

/**
 * @title GrandmaGifts
 * @notice Бабуся вносить ETH, онуки забирають рівну частку у свій день народження або після
 * @dev День народження зберігається як число 1–365 (день року)
 */
contract GrandmaGifts {
    address public grandma;                    // Адреса бабусі (той, хто деплоїв)
    address[] public grandchildren;           // Список онуків
    mapping(address => uint16) public birthDayOfYear; // Адреса → день року (1=1 січня, 365=31 грудня)
    mapping(address => bool) public hasWithdrawn;     // Чи вже забрав подарунок
    uint256 public totalDeposited;            // Загальна сума на депозиті
    bool public depositClosed;                // Чи закрито прийом внесків

    event Deposited(address indexed byGrandma, uint256 amount);
    event Withdrawn(address indexed grandchild, uint256 amount);

    /// @notice Модифікатор: тільки бабуся може викликати функцію
    /// @dev _; — тут підставляється тіло функції, що використовує модифікатор
    modifier onlyGrandma() {
        require(msg.sender == grandma, "Only grandma");
        _;
    }

    /// @param _grandchildren Масив адрес онуків
    /// @param _birthDays Масив днів народження (1–365) — відповідно до _grandchildren
    constructor(address[] memory _grandchildren, uint16[] memory _birthDays) {
        require(_grandchildren.length == _birthDays.length, "Length mismatch");
        grandma = msg.sender; // Хто деплоїть — той і бабуся
        for (uint256 i = 0; i < _grandchildren.length; i++) {
            require(_birthDays[i] >= 1 && _birthDays[i] <= 365, "Invalid day");
            grandchildren.push(_grandchildren[i]);
            birthDayOfYear[_grandchildren[i]] = _birthDays[i];
        }
    }

    /// @notice Бабуся вносить ETH (можна кілька разів до closeDeposit)
    function deposit() public payable onlyGrandma {
        require(!depositClosed || totalDeposited == 0, "Deposit closed");
        totalDeposited += msg.value; // msg.value — сума ETH, надіслана з транзакцією
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Бабуся закриває депозит — подальші внески неможливі
    function closeDeposit() public onlyGrandma {
        depositClosed = true;
    }

    /// @notice Онук забирає свою частку (після дня народження в поточному році)
    /// @dev dayOfYear = ((block.timestamp / 1 days) % 365) + 1 — приблизний день року (1–365)
    function withdraw() public {
        require(grandchildren.length > 0, "No grandchildren");
        require(!hasWithdrawn[msg.sender], "Already withdrawn");
        require(birthDayOfYear[msg.sender] > 0, "Not a grandchild");

        uint16 bd = birthDayOfYear[msg.sender];
        // Поточний день року: дні з епохи Unix % 365 + 1 (приблизно, без високосних років)
        uint256 dayOfYear = ((block.timestamp / 1 days) % 365) + 1;
        require(dayOfYear >= bd, "Birthday not yet this year");

        hasWithdrawn[msg.sender] = true;
        uint256 share = totalDeposited / grandchildren.length; // Рівна частка (цілочисельне ділення)
        payable(msg.sender).transfer(share); // payable() — щоб можна було надіслати ETH
        emit Withdrawn(msg.sender, share);
    }

    function getShare() public view returns (uint256) {
        return grandchildren.length > 0 ? totalDeposited / grandchildren.length : 0;
    }
}

// ============================================
// 3. ФОНД ОСВІТНІХ ГРАНТІВ
// ============================================
// Студенти накопичують → owner підтверджує досягнення мети → студент забирає грант
// Owner може заморозити при порушенні умов

/**
 * @title EducationGrantFund
 * @notice Фонд грантів: накопичення, виплата при досягненні мети, заморозка при невиконанні
 */
contract EducationGrantFund {
    /// @notice Стани гранту: Active (активний), Frozen (заморожено), Paid (виплачено)
    enum GrantStatus { Active, Frozen, Paid }

    /// @notice Структура даних студента
    struct Student {
        address wallet;      // Адреса гаманця
        uint256 balance;     // Накопичена сума
        uint256 goalAmount;  // Цільова сума для отримання гранту
        bool goalReached;    // Чи підтверджено досягнення мети (тільки owner)
        GrantStatus status;  // Поточний стан
    }

    mapping(address => Student) public students; // Адреса → дані студента
    address[] public studentList;               // Список усіх студентів
    address public owner;                       // Власник контракту (підтверджує мети, заморожує)
    uint256 public totalFund;                    // Загальна сума в фонді

    // Події для відстеження в фронтенді
    event Deposit(address indexed student, uint256 amount);
    event GoalReached(address indexed student, uint256 amount);
    event GrantPaid(address indexed student, uint256 amount);
    event StudentFrozen(address indexed student, string reason);
    event StudentUnfrozen(address indexed student);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyStudent(address _student) {
        require(students[_student].wallet != address(0), "Not a student"); // address(0) = не зареєстрований
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Owner реєструє нового студента з цільовою сумою
    function registerStudent(address _student, uint256 _goalAmount) public onlyOwner {
        require(students[_student].wallet == address(0), "Already registered");
        students[_student] = Student(_student, 0, _goalAmount, false, GrantStatus.Active);
        studentList.push(_student);
    }

    /// @notice Студент або родичі вносять кошти на його рахунок
    function deposit() public payable {
        require(students[msg.sender].wallet != address(0), "Not registered");
        require(students[msg.sender].status == GrantStatus.Active, "Account frozen or paid");

        students[msg.sender].balance += msg.value;
        totalFund += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Owner підтверджує, що студент досяг мети (напр. вступив до університету)
    function confirmGoalReached(address _student) public onlyOwner onlyStudent(_student) {
        Student storage s = students[_student]; // storage — посилання, зміни зберігаються
        require(s.status == GrantStatus.Active, "Invalid status");
        require(s.balance >= s.goalAmount, "Goal not reached");

        s.goalReached = true;
        emit GoalReached(_student, s.balance);
    }

    /// @notice Студент забирає грант після підтвердження мети
    function withdrawGrant() public onlyStudent(msg.sender) {
        Student storage s = students[msg.sender];
        require(s.status == GrantStatus.Active, "Frozen or already paid");
        require(s.goalReached, "Goal not confirmed");

        s.status = GrantStatus.Paid;
        uint256 amount = s.balance;
        s.balance = 0;
        totalFund -= amount;
        payable(msg.sender).transfer(amount);
        emit GrantPaid(msg.sender, amount);
    }

    /// @notice Owner заморожує студента (напр. не виконав умови)
    function freezeStudent(address _student, string calldata _reason) public onlyOwner onlyStudent(_student) {
        students[_student].status = GrantStatus.Frozen;
        emit StudentFrozen(_student, _reason);
    }

    /// @notice Owner розморожує студента
    function unfreezeStudent(address _student) public onlyOwner onlyStudent(_student) {
        require(students[_student].status == GrantStatus.Frozen, "Not frozen");
        students[_student].status = GrantStatus.Active;
        emit StudentUnfrozen(_student);
    }

    function getStudentInfo(address _student) public view returns (
        uint256 balance,
        uint256 goalAmount,
        bool goalReached,
        GrantStatus status
    ) {
        Student storage s = students[_student];
        return (s.balance, s.goalAmount, s.goalReached, s.status);
    }
}

// ============================================
// 4. ФОНД ЕКСТРЕНОЇ ДОПОМОГИ (МЕДИЧНИЙ)
// ============================================
// Учасники вносять кошти → хтось створює заявку на виплату → інші підтверджують →
// owner або medicalAuthority виконує виплату після достатньої кількості підтверджень

/**
 * @title EmergencyFund
 * @notice Накопичувальний фонд для екстрених ситуацій з багатостороннім підтвердженням
 */
contract EmergencyFund {
    address[] public participants;                    // Список учасників
    mapping(address => bool) public isParticipant;    // Чи є учасником
    mapping(address => uint256) public contributions; // Скільки кожен вніс
    uint256 public totalFund;                          // Загальна сума в фонді

    uint256 public requiredConfirmations;             // Скільки підтверджень потрібно для виплати
    mapping(bytes32 => uint256) public requestConfirmations; // Заявка → кількість підтверджень
    mapping(bytes32 => bool) public requestExecuted;  // Чи виконано заявку

    address public medicalAuthority;                  // Медична організація (може виконувати виплати)
    address public owner;                             // Власник контракту

    event Contributed(address indexed participant, uint256 amount);
    event WithdrawalRequested(bytes32 indexed requestId, address indexed beneficiary, uint256 amount, string reason);
    event WithdrawalConfirmed(bytes32 indexed requestId, address indexed confirmator);
    event WithdrawalExecuted(bytes32 indexed requestId, address indexed beneficiary, uint256 amount);

    modifier onlyParticipant() {
        require(isParticipant[msg.sender], "Not a participant");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @param _participants Адреси учасників фонду
    /// @param _requiredConfirmations Скільки учасників мають підтвердити заявку
    /// @param _medicalAuthority Адреса медичної організації (може виконувати виплати)
    constructor(address[] memory _participants, uint256 _requiredConfirmations, address _medicalAuthority) {
        owner = msg.sender;
        medicalAuthority = _medicalAuthority;
        requiredConfirmations = _requiredConfirmations;
        for (uint256 i = 0; i < _participants.length; i++) {
            participants.push(_participants[i]);
            isParticipant[_participants[i]] = true;
        }
    }

    /// @notice Учасник вносить кошти до фонду
    function contribute() public payable onlyParticipant {
        contributions[msg.sender] += msg.value;
        totalFund += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    /// @notice Структура заявки на виплату
    struct WithdrawalRequest {
        address beneficiary;  // Хто отримає кошти
        uint256 amount;      // Сума
        string reason;       // Причина (напр. "лікування")
        bool exists;         // Чи існує заявка
    }
    mapping(bytes32 => WithdrawalRequest) public requests;

    /// @notice Створити заявку на виплату (beneficiary має бути учасником)
    /// @return requestId — унікальний ID заявки (потрібен для confirm та execute)
    function requestWithdrawal(
        address _beneficiary,
        uint256 _amount,
        string calldata _reason
    ) public onlyParticipant returns (bytes32) {
        require(_amount <= totalFund, "Insufficient fund");
        require(isParticipant[_beneficiary] || _beneficiary == msg.sender, "Invalid beneficiary");

        // keccak256 — хеш-функція; abi.encodePacked — упаковка даних
        // Результат — унікальний 32-байтний ID заявки
        bytes32 requestId = keccak256(abi.encodePacked(block.timestamp, msg.sender, _beneficiary, _amount, _reason));
        requests[requestId] = WithdrawalRequest(_beneficiary, _amount, _reason, true);
        requestConfirmations[requestId] = 0;
        requestExecuted[requestId] = false;
        emit WithdrawalRequested(requestId, _beneficiary, _amount, _reason);
        return requestId;
    }

    /// @notice Учасник підтверджує заявку (потрібно requiredConfirmations підтверджень)
    function confirmWithdrawal(bytes32 _requestId) public onlyParticipant {
        require(!requestExecuted[_requestId], "Already executed");
        require(requests[_requestId].exists, "Request not found");
        requestConfirmations[_requestId]++;
        emit WithdrawalConfirmed(_requestId, msg.sender);
    }

    /// @notice Owner або medicalAuthority виконує виплату (після достатньої кількості підтверджень)
    function executeWithdrawal(bytes32 _requestId) public {
        require(msg.sender == owner || msg.sender == medicalAuthority, "Not authorized");
        require(!requestExecuted[_requestId], "Already executed");
        require(requests[_requestId].exists, "Request not found");
        require(requestConfirmations[_requestId] >= requiredConfirmations, "Not enough confirmations");

        WithdrawalRequest storage req = requests[_requestId];
        require(req.amount <= totalFund, "Insufficient fund");

        requestExecuted[_requestId] = true;
        totalFund -= req.amount;
        payable(req.beneficiary).transfer(req.amount);
        emit WithdrawalExecuted(_requestId, req.beneficiary, req.amount);
    }

    function getTotalFund() public view returns (uint256) {
        return totalFund;
    }

    function getParticipantCount() public view returns (uint256) {
        return participants.length;
    }
}
