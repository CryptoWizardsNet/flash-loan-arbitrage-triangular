const { ethers } = require("ethers");
const { PRIVATE_KEY } = require("./utils/private_key");

const {
  abi: ERC20ABI,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

const {
  abi: FlashABI,
} = require("../artifacts/contracts/FlashTri.sol/ContractFlashTri.json");

// Addresses
const deployedAddress = "0x5B7ff4E29697ebed11eE4c10B04307cCEe7f6742"; // DEPLOYED CONTRACT
const factoryPancake = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
const routerPancake = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const tokenA = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
const tokenB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
const tokenC = "0x89675DcCFE0c19bca178A0E0384Bd8E273a45cbA";

// Inputs
const factories = [factoryPancake, factoryPancake, factoryPancake];
const routers = [routerPancake, routerPancake, routerPancake];
const tokens = [tokenA, tokenB, tokenC];
const borrowAmount = ethers.utils.parseUnits("2", 18);
console.log(borrowAmount.toString());

// Provider (MAINNET)
const provider = new ethers.providers.JsonRpcProvider(
  "https://bsc-dataseed.binance.org/"
);

// Wallet Signer (MAINNET)
const privateKey = PRIVATE_KEY;
const walletSigner = new ethers.Wallet(privateKey, provider);

// Contract (MAINNET)
const contractFlashSwap = new ethers.Contract(
  deployedAddress,
  FlashABI,
  walletSigner
);

// Call Arbitrage
async function getArbitrage() {
  const arbTx = await contractFlashSwap.triangularArbitrage(
    factories,
    routers,
    tokens,
    borrowAmount,
    {
      gasLimit: 6000000,
      gasPrice: ethers.utils.parseUnits("5.5", "gwei"),
    }
  );
  console.log(arbTx);
}

// 0.4519
getArbitrage();

// txHash = "0x402dcce770515ec0aea2193d6a6dbe85e954ce885207db8b683de0dfacd4740a";
