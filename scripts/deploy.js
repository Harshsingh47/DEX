// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const DEX = await hre.ethers.deployContract("DEX");
  await DEX.waitForDeployment();

  const tokenA = await hre.ethers.deployContract("TokenA",[1000])
  await tokenA.waitForDeployment()
  const tokenB = await hre.ethers.deployContract("TokenB",[1000])
  await tokenB.waitForDeployment();
  console.log("DEX address:",await DEX.getAddress());
  console.log("tokenA address:",await tokenA.getAddress());
  console.log("tokenB address:",await tokenB.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
