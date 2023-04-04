const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const Web3 = require('web3');

describe("Rewards", function () {

  let rewardPerEpoch = Web3.utils.toWei('10000', 'ether');
  let epochDuration = 86400 * 7; // week
  let rewardDuration = 86400 * 7; // week

  let rewarding, owner, rwToken, account1, account2, account3, account4;
  
  async function deploy() {
    [owner, account1, account2, account3, account4] = await ethers.getSigners();
    const Rewarding = await ethers.getContractFactory("Rewards");
    const RwToken = await ethers.getContractFactory("Token");
    rwToken = await RwToken.deploy();
    rewarding = await Rewarding.deploy(rewardPerEpoch, epochDuration, rewardDuration, owner.address, rwToken.address);
  }

  describe("Deployment", function () {

    it("Deploy", async function () {
      await deploy();
      expect(await rewarding.rewardPerEpoch()).to.equal(rewardPerEpoch);
      expect(await rwToken.owner()).to.equal(owner.address);
    });

    it("Transfer and Supply", async function () {
      
      let balanceAmount = await rwToken.balanceOf(owner.address);
      await rwToken.transfer(rewarding.address, balanceAmount);
      let amount = Web3.utils.toWei('100', 'ether');
      await rewarding.supply(owner.address, amount);
      await rewarding.supply(account1.address, amount);
      await rewarding.supply(account2.address, amount);
      await rewarding.supply(account3.address, amount);
      // await rewarding.supply(account4.address, amount);

      expect(await rwToken.balanceOf(rewarding.address)).to.equal(balanceAmount);

    });

    // it("Withdraw now", async function () {
      
    //   let withdrawingAmount = Web3.utils.toWei('1', 'ether');

    //   await rewarding.withdraw(owner.address, withdrawingAmount);
    //   await rewarding.withdraw(account1.address, withdrawingAmount);
    //   await rewarding.withdraw(account2.address, withdrawingAmount);
    //   await rewarding.withdraw(account3.address, withdrawingAmount);
    //   await rewarding.withdraw(account4.address, withdrawingAmount);
    //   await expect(rewarding.connect(account1).withdraw(account4.address, withdrawingAmount)).to.be.reverted;

    // });

    it("Claim now", async function () {

      await rewarding.claim();
      await rewarding.connect(account1).claim();
      await rewarding.connect(account2).claim();
      await rewarding.connect(account3).claim();
      await expect(rewarding.connect(account4).claim()).to.be.revertedWith("Nothing to claim");

      console.log('owner: ', BigInt(await rwToken.balanceOf(owner.address)));
      console.log('account1: ', BigInt(await rwToken.balanceOf(account1.address)));
      console.log('account2: ', BigInt(await rwToken.balanceOf(account2.address)));
      console.log('account3: ', BigInt(await rwToken.balanceOf(account3.address)));
      console.log('account4: ', BigInt(await rwToken.balanceOf(account4.address)));

    });

    // it("Withdraw after week", async function () {
      
    //   let withdrawingAmount = Web3.utils.toWei('1', 'ether');
    //   await time.increase(epochDuration);

    //   await expect(rewarding.withdraw(owner.address, withdrawingAmount)).to.emit(rewarding, "Withdraw").withArgs(owner.address, withdrawingAmount, anyValue);

    // });

    it("Claim after week", async function () {

      await time.increase(epochDuration);

      await rewarding.claim();
      await rewarding.connect(account1).claim();
      await rewarding.connect(account2).claim();
      await rewarding.connect(account3).claim();
      await expect(rewarding.connect(account4).claim()).to.be.revertedWith("Nothing to claim");

      console.log('owner: ', BigInt(await rwToken.balanceOf(owner.address)));
      console.log('account1: ', BigInt(await rwToken.balanceOf(account1.address)));
      console.log('account2: ', BigInt(await rwToken.balanceOf(account2.address)));
      console.log('account3: ', BigInt(await rwToken.balanceOf(account3.address)));
      console.log('account4: ', BigInt(await rwToken.balanceOf(account4.address)));

    });

    // it("Set parameters", async function () {
    //   rewardPerEpoch = Web3.utils.toWei('5000', 'ether');
    //   await rewarding.setParameters(rewardPerEpoch, epochDuration, rewardDuration);
    // });

    it("Claim after 2 week", async function () {

      // console.log('_availableReward-account1: ', BigInt(await rewarding._availableReward(account1.address)));
      // console.log('getUserInfo-account1: ', await rewarding.getUserInfo([account1.address]));
      // console.log('getData: ', await rewarding.getData());
      await time.increase(epochDuration);
      // console.log('_availableReward-account1: ', BigInt(await rewarding._availableReward(account1.address)));
      // console.log('getUserInfo-account1: ', await rewarding.getUserInfo([account1.address]));
      // console.log('getData: ', await rewarding.getData());
      
      await rewarding.claim();
      await rewarding.connect(account1).claim();
      await rewarding.connect(account2).claim();
      await rewarding.connect(account3).claim();
      await expect(rewarding.connect(account4).claim()).to.be.revertedWith("Nothing to claim");

      console.log('owner: ', BigInt(await rwToken.balanceOf(owner.address)));
      console.log('account1: ', BigInt(await rwToken.balanceOf(account1.address)));
      console.log('account2: ', BigInt(await rwToken.balanceOf(account2.address)));
      console.log('account3: ', BigInt(await rwToken.balanceOf(account3.address)));
      console.log('account4: ', BigInt(await rwToken.balanceOf(account4.address)));

    });

    it("Get data", async function () {
      console.log('Data: ', await rewarding.getData());
    });

    it("Claim after 3 week", async function () {

      await time.increase(epochDuration);

      await rewarding.claim();
      await rewarding.connect(account1).claim();
      await rewarding.connect(account2).claim();
      await rewarding.connect(account3).claim();

      console.log('owner: ', BigInt(await rwToken.balanceOf(owner.address)));
      console.log('account1: ', BigInt(await rwToken.balanceOf(account1.address)));
      console.log('account2: ', BigInt(await rwToken.balanceOf(account2.address)));
      console.log('account3: ', BigInt(await rwToken.balanceOf(account3.address)));

    });

    // // it("Should revert with the right error if called too soon", async function () {
    // //   await expect(lock.withdraw()).to.be.revertedWith("You can't withdraw yet");
    // // });

    // // it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
    // //   await time.increaseTo(unlockTime);
    // //   await expect(lock.withdraw()).not.to.be.reverted;
    // // });

  });

});
