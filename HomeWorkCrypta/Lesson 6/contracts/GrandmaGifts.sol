// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GrandmaGifts
 * @notice Бабуся вносить ETH, онуки забирають рівну частку у свій день народження або після
 * @dev Контракт з Lesson 4 — для тестування в Lesson 6
 */
contract GrandmaGifts {
    address public grandma;
    address[] public grandchildren;
    mapping(address => uint16) public birthDayOfYear;
    mapping(address => bool) public hasWithdrawn;
    uint256 public totalDeposited;
    bool public depositClosed;

    event Deposited(address indexed byGrandma, uint256 amount);
    event Withdrawn(address indexed grandchild, uint256 amount);

    modifier onlyGrandma() {
        require(msg.sender == grandma, "Only grandma");
        _;
    }

    constructor(address[] memory _grandchildren, uint16[] memory _birthDays) {
        require(_grandchildren.length == _birthDays.length, "Length mismatch");
        grandma = msg.sender;
        for (uint256 i = 0; i < _grandchildren.length; i++) {
            require(_birthDays[i] >= 1 && _birthDays[i] <= 365, "Invalid day");
            grandchildren.push(_grandchildren[i]);
            birthDayOfYear[_grandchildren[i]] = _birthDays[i];
        }
    }

    function deposit() public payable onlyGrandma {
        require(!depositClosed || totalDeposited == 0, "Deposit closed");
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function closeDeposit() public onlyGrandma {
        depositClosed = true;
    }

    function withdraw() public {
        require(grandchildren.length > 0, "No grandchildren");
        require(!hasWithdrawn[msg.sender], "Already withdrawn");
        require(birthDayOfYear[msg.sender] > 0, "Not a grandchild");

        uint16 bd = birthDayOfYear[msg.sender];
        uint256 dayOfYear = ((block.timestamp / 1 days) % 365) + 1;
        require(dayOfYear >= bd, "Birthday not yet this year");

        hasWithdrawn[msg.sender] = true;
        uint256 share = totalDeposited / grandchildren.length;
        payable(msg.sender).transfer(share);
        emit Withdrawn(msg.sender, share);
    }

    function getShare() public view returns (uint256) {
        return grandchildren.length > 0 ? totalDeposited / grandchildren.length : 0;
    }
}
