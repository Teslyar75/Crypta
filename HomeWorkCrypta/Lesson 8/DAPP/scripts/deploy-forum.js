const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const Forum = await ethers.getContractFactory("Forum");
    const forum = await Forum.deploy();
    await forum.waitForDeployment();
    const address = await forum.getAddress();
    console.log("Forum deployed to:", address);

    const configPath = path.join(__dirname, "..", "public", "contract-addresses.json");
    const config = { forum: address };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log("Address saved to public/contract-addresses.json");
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
