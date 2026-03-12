const abi = [
    {
      "inputs": [
        { "internalType": "string", "name": "_name", "type": "string" },
        { "internalType": "string", "name": "_description", "type": "string" },
        { "internalType": "uint256", "name": "_price", "type": "uint256" },
        { "internalType": "string", "name": "_imageUrl", "type": "string" }
      ],
      "name": "createProduct",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{ "internalType": "uint256", "name": "index", "type": "uint256" }],
      "name": "getProduct",
      "outputs": [
        { "internalType": "string", "name": "name", "type": "string" },
        { "internalType": "string", "name": "description", "type": "string" },
        { "internalType": "uint256", "name": "price", "type": "uint256" },
        { "internalType": "address", "name": "creator", "type": "address" },
        { "internalType": "uint256", "name": "timestamp", "type": "uint256" },
        { "internalType": "string", "name": "imageUrl", "type": "string" }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getProductsCount",
      "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "get_user",
      "outputs": [
        {
          "components": [
            { "internalType": "string", "name": "name", "type": "string" },
            { "internalType": "uint256", "name": "age", "type": "uint256" }
          ],
          "internalType": "struct Sample.User",
          "name": "",
          "type": "tuple"
        }
      ],
      "stateMutability": "pure",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "get_value",
      "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{ "internalType": "uint256", "name": "_value", "type": "uint256" }],
      "name": "set_value",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]
