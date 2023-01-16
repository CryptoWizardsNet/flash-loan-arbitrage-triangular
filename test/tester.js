// IMPORTS
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { impersonateFundErc20 } = require("../utils/utilities");

const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

const provider = waffle.provider;

describe("Token contract", () => {
  let FLASHSWAP,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFundingHuman,
    txArbitrage,
    gasUsedUSD;

  const DECIMALS = 18;

  const FACTORY_PANCAKE = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
  const FACTORY_APESWAP = "0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6";
  const ROUTER_PANCAKE = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
  const ROUTER_APESWAP = "0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7";

  const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const TOKEN_A = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"; // BUSD
  const TOKEN_B = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"; // WBNB
  const TOKEN_C = "0x37dfACfaeDA801437Ff648A1559d73f4C40aAcb7"; // APYS

  // Assume borrowing Token A
  const tokenBase = new ethers.Contract(TOKEN_A, abi, provider);

  beforeEach(async () => {
    // Get owner as signer
    [owner] = await ethers.getSigners();

    // Ensure Whale has balance
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.equal("0");

    // Deploy smart contract
    const FlashSwap = await ethers.getContractFactory("ContractFlashTri");
    FLASHSWAP = await FlashSwap.deploy();
    await FLASHSWAP.deployed();

    // Configure Borrowing
    const borrowAmountHuman = "1"; // borrow anything, even 1m
    BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmountHuman, DECIMALS);

    // Configure Funding
    initialFundingHuman = "100"; // 100 assigned just to pass payback of loan whilst testing
    FUND_AMOUNT = ethers.utils.parseUnits(initialFundingHuman, DECIMALS);

    await impersonateFundErc20(
      tokenBase,
      BUSD_WHALE,
      FLASHSWAP.address,
      initialFundingHuman
    );
  });

  describe("Arbitrage execution", () => {
    it("ensures contract is funded", async () => {
      const flashSwapBalance = await FLASHSWAP.getBalanceOfToken(TOKEN_A);

      const flashSwapBalanceHuman = ethers.utils.formatUnits(
        flashSwapBalance,
        DECIMALS
      );
      expect(Number(flashSwapBalanceHuman)).equal(Number(initialFundingHuman));
    });

    it("executes the arbitrage", async () => {
      // console.log(ethers.utils.formatUnits("8211184147365292123", 18));

      txArbitrage = await FLASHSWAP.triangularArbitrage(
        [FACTORY_PANCAKE, FACTORY_PANCAKE, FACTORY_PANCAKE],
        [ROUTER_PANCAKE, ROUTER_PANCAKE, ROUTER_PANCAKE],
        [TOKEN_A, TOKEN_B, TOKEN_C],
        BORROW_AMOUNT
      );

      assert(txArbitrage);

      // Print balances
      const contractBalanceTOKENA = await FLASHSWAP.getBalanceOfToken(TOKEN_A);

      const formattedBalTOKENA = Number(
        ethers.utils.formatUnits(contractBalanceTOKENA, 18)
      );
      const contractBalanceTOKENB = await FLASHSWAP.getBalanceOfToken(TOKEN_B);

      console.log("Balance Of TOKEN A: " + formattedBalTOKENA);

      console.log(
        "Balance Of TOKEN B: " +
          ethers.utils.formatUnits(contractBalanceTOKENB, 18)
      );
    });

    it("provides GAS output", async () => {
      const txReceipt = await provider.getTransactionReceipt(txArbitrage.hash);

      const effGasPrice = txReceipt.effectiveGasPrice;
      const txGasUsed = txReceipt.gasUsed;
      const gasUsedBNB = effGasPrice * txGasUsed;
      gasUsedUSD = ethers.utils.formatUnits(gasUsedBNB, 18) * 395; // USD to BNB price today

      console.log("Total Gas USD: " + gasUsedUSD);

      expect(gasUsedUSD).gte(0.1);
    });
  });
});
