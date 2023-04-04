const hre = require("hardhat");
const Web3 = require('web3');

async function main() {

  let rewardTokenAddress = '0x577B08faE2F7fEDD5BFeDe95E02445ed56D02e0e';
  let lendingContractAddress = '0x577B08faE2F7fEDD5BFeDe95E02445ed56D02e0e';
  let rewardPerEpoch = Web3.utils.toWei('10000', 'ether');
  let epochDuration = 86400 * 7; // week
  let rewardDuration = 86400 * 7; // week

  const Rewarding = await hre.ethers.getContractFactory("Rewards");
  const rewarding = await Rewarding.deploy(
    rewardPerEpoch,
    epochDuration,
    rewardDuration,
    lendingContractAddress,
    rewardTokenAddress);
  await rewarding.deployed();
  console.log(`Rewarding contract deployed to ${rewarding.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});