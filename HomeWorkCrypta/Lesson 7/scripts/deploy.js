const { ethers } = require("hardhat");

(async () => {
    const factory = await ethers.getContractFactory("Sample");
    const contract = await factory.deploy();

    await contract.waitForDeployment();
    console.log(`Contract deployed at address: \u001b[32m${await contract.getAddress()}\u001b[0m`)
})().catch((error)=>{
    console.error(error);
    process.exitCode = -1;
})