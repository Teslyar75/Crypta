// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Sample{
    uint value;

    struct User{
        string name;
        uint age;
    }

    struct Product{
        string name;        // назва продукту
        string description; // опис
        uint price;         // ціна (wei)
        address creator;    // адреса акаунта (хто створив)
        uint timestamp;     // часова мітка створення
        string imageUrl;    // URL-картинка
    }

    Product[] public products;

    function get_user() external pure returns(User memory){
        return User("Tom", 24);
    }

    function set_value(uint _value) external{
        value = _value;
    }

    function get_value() external view returns (uint) {
        return value;
    }

    function createProduct(
        string calldata _name,
        string calldata _description,
        uint _price,
        string calldata _imageUrl
    ) external {
        products.push(Product({
            name: _name,
            description: _description,
            price: _price,
            creator: msg.sender,
            timestamp: block.timestamp,
            imageUrl: _imageUrl
        }));
    }

    function getProductsCount() external view returns (uint) {
        return products.length;
    }

    function getProduct(uint index) external view returns (
        string memory name,
        string memory description,
        uint price,
        address creator,
        uint timestamp,
        string memory imageUrl
    ) {
        require(index < products.length, "Invalid index");
        Product storage p = products[index];
        return (p.name, p.description, p.price, p.creator, p.timestamp, p.imageUrl);
    }
}