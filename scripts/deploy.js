/* eslint-disable */
const hre = require("hardhat");

async function main() {
  const [deployer, treasury, addr1, addr2, addr3] = await hre.ethers.getSigners();

  const MockInvestToken = await hre.ethers.getContractFactory("FDAI");
  const iToken = await MockInvestToken.deploy();
  await iToken.deployed();
  const iTokenDecimals = await iToken.decimals();
  console.log("MockInvestToken deployed to:", iToken.address);
  console.log("MockInvestToken decimals:", iTokenDecimals);

  const MockPreSaleToken = await hre.ethers.getContractFactory("PDEFIRE");
  const pToken = await MockPreSaleToken.deploy();
  await pToken.deployed();
  const pTokenDecimals = await pToken.decimals();
  console.log("MockPreSaleToken deployed to:", pToken.address);
  console.log("MockPreSaleToken decimals:", pTokenDecimals);

  const MockPreSaleDToken = await hre.ethers.getContractFactory("DDEFIRE");
  const dToken = await MockPreSaleDToken.deploy();
  await dToken.deployed();
  const dTokenDecimals = await dToken.decimals();
  console.log("MockPreSaleToken Degen deployed to:", dToken.address);
  console.log("MockPreSaleToken Degen decimals:", dTokenDecimals);

  // starttime in seconds
  const startTime = Math.floor(Date.now() / 1000);
  //epoch duration
  const epochTime = 3600;
  //how many epochs
  const duration = 72;
  const pPrice = 15;
  const dPrice = 25;

  const DeFIRELaunchPool = await hre.ethers.getContractFactory("DeFIRELaunchPool");
  const presale = await DeFIRELaunchPool.deploy(pToken.address, dToken.address, treasury.address, iToken.address, startTime, epochTime, duration, pPrice, dPrice);
  await presale.deployed();
  console.log("Presale deployed to:", presale.address);

  // mint presale tokens
  await pToken.mint(presale.address, hre.ethers.utils.parseEther("100"));
  const pTokenBalance = await pToken.balanceOf(presale.address);
  console.log("- Presale contract balance of pDEFIRE:", hre.ethers.utils.formatEther(pTokenBalance));

  // mint presale tokens
  await dToken.mint(presale.address, hre.ethers.utils.parseEther("1500"));
  const dTokenBalance = await dToken.balanceOf(presale.address);
  console.log("- Presale contract balance of dDEFIRE:", hre.ethers.utils.formatEther(dTokenBalance));

  // whitelist address
  await presale.enableWhitelist(true);
  console.log("- whitelisting enabled");

  // whitelist address
  let currentEpoch = await presale.currentEpoch();

  console.log("startTime:", startTime);
  console.log("- e :", hre.ethers.utils.formatEther(currentEpoch));

  // whitelist address
  await presale.addWhitelist(addr1.address);
  const iswhitelisted = await presale.isWhitelisted(addr1.address);
  console.log("address1 whitelisted:", iswhitelisted);

  // dewhitelist address
  await presale.removeWhitelist(addr1.address);
  const notwhitelisted = await presale.isWhitelisted(addr1.address);
  console.log("address1 whitelisted:", notwhitelisted);

  // whitelist multiple address
  await presale.addMultipleWhitelist([addr1.address, addr2.address, addr3.address]);
  const is1whitelisted = await presale.isWhitelisted(addr1.address);
  const is2whitelisted = await presale.isWhitelisted(addr2.address);
  const is3whitelisted = await presale.isWhitelisted(addr3.address);
  console.log("address1 whitelisted:", is1whitelisted);
  console.log("address2 whitelisted:", is2whitelisted);
  console.log("address3 whitelisted:", is3whitelisted);

  // ------------------------------------ Address 1
  // mint some DAI for Address 1
  await iToken.mint(addr1.address, hre.ethers.utils.parseEther("6000"));
  const a1TokenBalance = await iToken.balanceOf(addr1.address);
  console.log("A1 balance of fDAI:", hre.ethers.utils.formatEther(a1TokenBalance));

  // 1 token = 1*(10**decimals)
  // buy degen

  await iToken.connect(addr1).approve(presale.address, hre.ethers.utils.parseEther("5000"));

  const buyAllowance = await presale.connect(addr1).investorCurrentBuyAllowance();
  console.log("A1 defire buy allowance:", hre.ethers.utils.formatEther(buyAllowance));

  await presale.connect(addr1).buyDDeFIRE(hre.ethers.utils.parseEther("500"));
  await presale.connect(addr1).buyPDeFIRE(hre.ethers.utils.parseEther("100"));

  const pTokenBalanceA1 = await pToken.connect(addr1).balanceOf(addr1.address);
  const dTokenBalanceA1 = await dToken.connect(addr1).balanceOf(addr1.address);
  const iTokenBalanceA1 = await iToken.connect(addr1).balanceOf(addr1.address);

  console.log("A1 balance of pDEFIRE:", hre.ethers.utils.formatEther(pTokenBalanceA1));
  console.log("A1 balance of dDEFIRE:", hre.ethers.utils.formatEther(dTokenBalanceA1));
  console.log("A1 balance of fDAI:", hre.ethers.utils.formatEther(iTokenBalanceA1));

  let contractBalance = await iToken.connect(treasury).balanceOf(presale.address);

  console.log("- Contract balance of fDAI:", hre.ethers.utils.formatEther(contractBalance));

  // purchase dDEFIRE
  await presale.connect(addr1).buyDDeFIRE(hre.ethers.utils.parseEther("100"));
  await presale.connect(addr1).buyDDeFIRE(hre.ethers.utils.parseEther("300"));
  await presale.connect(addr1).buyDDeFIRE(hre.ethers.utils.parseEther("200"));

  // purchase pDEFIRE
  await presale.connect(addr1).buyPDeFIRE(hre.ethers.utils.parseEther("100"));
  await presale.connect(addr1).buyPDeFIRE(hre.ethers.utils.parseEther("300"));
  await presale.connect(addr1).buyPDeFIRE(hre.ethers.utils.parseEther("1000"));

  // check investor details
  let investorStats = await presale.connect(addr1).checkInvestorDetails(addr1.address);

  console.log("A1 Investor Stats : pDeFIRE bought :", hre.ethers.utils.formatEther(investorStats[0]));
  console.log("A1 Investor Stats : dDeFIRE bought :", hre.ethers.utils.formatEther(investorStats[1]));
  console.log("A1 Investor Stats : Amount Invested :", hre.ethers.utils.formatEther(investorStats[2]));

  contractBalance = await iToken.connect(treasury).balanceOf(presale.address);
  console.log("- Contract balance of fDAI:", hre.ethers.utils.formatEther(contractBalance));

  // finalize
  await presale.withdrawInvestmentToTreasury();
  await presale.withdrawUnclaimedToTreasury();

  iTokenBalanceTreasury = await iToken.connect(treasury).balanceOf(treasury.address);
  pTokenBalanceTreasury = await pToken.connect(treasury).balanceOf(treasury.address);
  dTokenBalanceTreasury = await dToken.connect(treasury).balanceOf(treasury.address);

  console.log("- Treasury balance of fDAI:", hre.ethers.utils.formatEther(iTokenBalanceTreasury));
  console.log("- Treasury balance of pDEFIRE:", hre.ethers.utils.formatEther(pTokenBalanceTreasury));
  console.log("- Treasury balance of dDEFIRE:", hre.ethers.utils.formatEther(dTokenBalanceTreasury));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
