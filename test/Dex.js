const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("DEX", async function () {
    async function deployment() {
        const [owner] = await ethers.getSigners();
        const DEX = await ethers.getContractFactory("DEX");
        const dex = await DEX.deploy();

        const TokenA = await ethers.getContractFactory("TokenA")
        const tokenA = await TokenA.deploy(1000);

        const TokenB = await ethers.getContractFactory("TokenA")
        const tokenB = await TokenB.deploy(1000);

        return{owner, dex, tokenA, tokenB}
    }

    it("Should succesfully create a pair", async function () {
        const {dex, tokenA, tokenB, owner} = await deployment();
        const amountA = 1000000;
        const amountB = 1000000;

        tokenA.approve(dex.getAddress(), amountA);
        tokenB.approve(dex.getAddress(), amountB);

        expect(tokenA.allowance(owner, dex.getAddress()));
        expect(tokenB.allowance(owner, dex.getAddress()));

        await dex.createPair(tokenA.getAddress(), tokenB.getAddress(), amountA, amountB);

        expect(await tokenA.balanceOf(dex.getAddress())).to.be.greaterThan(0);
        expect(await tokenB.balanceOf(dex.getAddress())).to.be.greaterThan(0);
    })

    it("Should succesfully add liquidity", async function () {
        const {dex, tokenA, tokenB, owner} = await deployment();
        const [addr1, addr2] = await ethers.getSigners();
        const amount = 1000000

        await tokenA.transfer(addr2, amount*2);
        await tokenB.transfer(addr2, amount*2);

        expect(await tokenA.balanceOf(addr2)).to.be.equal(amount*2)
        expect(await tokenB.balanceOf(addr2)).to.be.equal(amount*2)

        await tokenA.connect(addr2).approve(dex.getAddress(), amount*2);
        await tokenB.connect(addr2).approve(dex.getAddress(), amount*2);

        expect(await tokenA.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);
        expect(await tokenB.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);

        await dex.connect(addr2).createPair(tokenA.getAddress(), tokenB.getAddress(), amount, amount);
        await dex.connect(addr2).addLiquidity(tokenA.getAddress(), tokenB.getAddress(), amount, amount);

        expect(await tokenA.balanceOf(dex.getAddress())).to.be.greaterThan(amount);
        expect(await tokenB.balanceOf(dex.getAddress())).to.be.greaterThan(amount);
    })

    it("Should succesfully remove the liquidity", async function () {
        const {dex, tokenA, tokenB, owner} = await deployment();
        const [addr1, addr2] = await ethers.getSigners();
        const amount = 1000000

        await tokenA.transfer(addr2, amount*2);
        await tokenB.transfer(addr2, amount*2);

        expect(await tokenA.balanceOf(addr2)).to.be.equal(amount*2)
        expect(await tokenB.balanceOf(addr2)).to.be.equal(amount*2)

        await tokenA.connect(addr2).approve(dex.getAddress(), amount*2);
        await tokenB.connect(addr2).approve(dex.getAddress(), amount*2);

        expect(await tokenA.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);
        expect(await tokenB.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);

        await dex.connect(addr2).createPair(tokenA.getAddress(), tokenB.getAddress(), amount, amount);
        await dex.connect(addr2).addLiquidity(tokenA.getAddress(), tokenB.getAddress(), amount, amount);

        expect(await tokenA.balanceOf(dex.getAddress())).to.be.greaterThan(amount);
        expect(await tokenB.balanceOf(dex.getAddress())).to.be.greaterThan(amount);

        const addr2TokenABalance = await tokenA.balanceOf(addr2); 
        const addr2TokenBBalance = await tokenB.balanceOf(addr2); 
        await dex.connect(addr2).removeLiquidity(tokenA.getAddress(), tokenB.getAddress());

        expect(await await tokenA.balanceOf(addr2)).to.be.greaterThan(addr2TokenABalance);
        expect(await await tokenB.balanceOf(addr2)).to.be.greaterThan(addr2TokenBBalance);

    })

    it("Should succesfully swap the tokens", async function () {
        const {dex, tokenA, tokenB, owner} = await deployment();
        const [addr1, addr2, addr3] = await ethers.getSigners();
        const amount = 1000000

        await tokenA.transfer(addr2, amount*2);
        await tokenB.transfer(addr2, amount*2);
        await tokenA.transfer(addr3, amount*2);

        expect(await tokenA.balanceOf(addr2)).to.be.equal(amount*2)
        expect(await tokenB.balanceOf(addr2)).to.be.equal(amount*2)
        expect(await tokenA.balanceOf(addr3)).to.be.equal(amount*2)

        await tokenA.connect(addr2).approve(dex.getAddress(), amount*2);
        await tokenA.connect(addr3).approve(dex.getAddress(), amount*2);
        await tokenB.connect(addr2).approve(dex.getAddress(), amount*2);

        expect(await tokenA.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);
        expect(await tokenA.allowance(addr3, dex.getAddress())).to.be.equal(amount*2);
        expect(await tokenB.allowance(addr2, dex.getAddress())).to.be.equal(amount*2);

        await dex.connect(addr2).createPair(tokenA.getAddress(), tokenB.getAddress(), amount, amount);
        await dex.connect(addr2).addLiquidity(tokenA.getAddress(), tokenB.getAddress(), amount, amount);

        expect(await tokenA.balanceOf(dex.getAddress())).to.be.greaterThan(amount);
        expect(await tokenB.balanceOf(dex.getAddress())).to.be.greaterThan(amount);

        const addr3TokenABalance = await tokenA.balanceOf(addr3);
        await dex.connect(addr3).swap(tokenA.getAddress(), tokenB.getAddress(), amount);
        
        expect(await tokenA.balanceOf(addr3)).to.be.lessThan(addr3TokenABalance);
        expect(await tokenB.balanceOf(addr3)).to.be.greaterThan(0);

    })
})
