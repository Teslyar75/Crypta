const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Counter", function () {
  it("Should increment and decrement", async function () {
    const Counter = await ethers.getContractFactory("Counter");
    const counter = await Counter.deploy();
    expect(await counter.count()).to.equal(0);
    await counter.increment();
    expect(await counter.count()).to.equal(1);
    await counter.decrement();
    expect(await counter.count()).to.equal(0);
  });
});
