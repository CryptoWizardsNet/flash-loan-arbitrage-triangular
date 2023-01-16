//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "hardhat/console.sol";

// import "./interfaces/Uniswap.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

contract ContractFlashTri {
    using SafeERC20 for IERC20;

    // Trade Variables
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Trade Struct
    struct TradeDetails {
        address factoryT1;
        address factoryT2;
        address factoryT3;
        address routerT1;
        address routerT2;
        address routerT3;
        address tokenA;
        address tokenB;
        address tokenC;
    }

    // Trade Mapping
    mapping(address => TradeDetails) public tradeDetails;

    // FUND SWAP CONTRACT
    // Provides a runction to allow contract to be funded
    function fundFlashSwapContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, address(this), _amount);
    }

    // GET CONTRACT BALANCE
    // Allows public view of balance for contract
    function getBalanceOfToken(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    // PLACE A TRADE
    // Executes placing a trade
    function placeTrade(
        address _factory,
        address _router,
        address _fromToken,
        address _toToken,
        uint256 _amountIn
    ) private returns (uint256) {
        address pair = IUniswapV2Factory(_factory).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "Pool does not exist");

        // Perform Arbitrage - Swap for another token on Uniswap
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRequired = IUniswapV2Router01(_router).getAmountsOut(
            _amountIn,
            path
        )[1];

        uint256 deadline = block.timestamp + 30 minutes;

        uint256 amountReceived = IUniswapV2Router01(_router)
            .swapExactTokensForTokens(
                _amountIn, // amountIn
                amountRequired, // amountOutMin
                path, // contract addresses
                address(this), // address to
                deadline // block deadline
            )[1];

        // Return output
        require(amountReceived > 0, "Aborted Tx: Trade returned zero");
        return amountReceived;
    }

    // CHECK PROFITABILITY
    // Checks whether output > input
    function checkProfitability(uint256 _input, uint256 _output)
        private
        pure
        returns (bool)
    {
        return _output > _input;
    }

    // INITIATE ARBITRAGE
    // Begins the arbitrage for receiving a Flash Loan
    function triangularArbitrage(
        address[3] calldata _factories,
        address[3] calldata _routers,
        address[3] calldata _tokens,
        uint256 _amountBorrow
    ) external {
        // Approve contract to make transactions
        if (_routers[0] == _routers[1] && _routers[1] == _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
        } else if (_routers[0] == _routers[1] && _routers[1] != _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[2]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[2]), MAX_INT);
        } else if (_routers[0] != _routers[1] && _routers[1] == _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[0]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[1]), MAX_INT);
        } else if (_routers[0] != _routers[1] && _routers[1] != _routers[2]) {
            IERC20(_tokens[0]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[0]), MAX_INT);
            IERC20(_tokens[1]).approve(address(_routers[1]), MAX_INT);
            IERC20(_tokens[2]).approve(address(_routers[1]), MAX_INT);
        }

        // Assign dummy token change if needed
        address dummyToken;
        if (_tokens[0] != WBNB && _tokens[1] != WBNB && _tokens[2] != WBNB) {
            dummyToken = WBNB;
        } else if (
            _tokens[0] != BUSD && _tokens[1] != BUSD && _tokens[2] != BUSD
        ) {
            dummyToken = BUSD;
        } else if (
            _tokens[0] != CAKE && _tokens[1] != CAKE && _tokens[2] != CAKE
        ) {
            dummyToken = CAKE;
        } else {
            dummyToken = USDC;
        }

        // Get Factory pair address for combined tokens
        address pair = IUniswapV2Factory(_factories[0]).getPair(
            _tokens[0],
            dummyToken
        );
        require(pair != address(0), "Pool does not exist");

        // Figure out which token (0 or 1) has the amount and assign
        // Assumes borrowing tokenA
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = _tokens[0] == token0 ? _amountBorrow : 0;
        uint256 amount1Out = _tokens[0] == token1 ? _amountBorrow : 0;

        // Passing data triggers pancakeCall as this is what constitutes a loan
        // TokenA is the token being borrowed
        bytes memory data = abi.encode(_tokens[0], _amountBorrow, msg.sender);

        // Save trade data to tradeDetails mapping
        tradeDetails[msg.sender] = TradeDetails(
            _factories[0],
            _factories[1],
            _factories[2],
            _routers[0],
            _routers[1],
            _routers[2],
            _tokens[0],
            _tokens[1],
            _tokens[2]
        );

        // Execute the initial swap with the loan
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    // RECEIVE LOAN AND EXECUTE TRADES
    // This function is called from the .swap in startArbitrage if there is byte data
    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        // Decode data for calculating repayment
        (address tokenA, uint256 amountBorrow, address sender) = abi.decode(
            _data,
            (address, uint256, address)
        );

        // Ensure this request came from the contract
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(tradeDetails[sender].factoryT1)
            .getPair(token0, token1);
        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "Sender should match this contract");

        // Calculate amount to repay at the end
        uint256 fee = ((amountBorrow * 3) / 997) + 1;
        uint256 amountToRepay = amountBorrow + fee;

        // Extract amount of acquired token going into next trade
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        // Trade 1
        uint256 trade1AcquiredCoin = placeTrade(
            tradeDetails[sender].factoryT1,
            tradeDetails[sender].routerT1,
            tradeDetails[sender].tokenA,
            tradeDetails[sender].tokenB,
            loanAmount
        );

        // Trade 2
        uint256 trade2AcquiredCoin = placeTrade(
            tradeDetails[sender].factoryT2,
            tradeDetails[sender].routerT2,
            tradeDetails[sender].tokenB,
            tradeDetails[sender].tokenC,
            trade1AcquiredCoin
        );

        // Trade 3
        uint256 trade3AcquiredCoin = placeTrade(
            tradeDetails[sender].factoryT3,
            tradeDetails[sender].routerT3,
            tradeDetails[sender].tokenC,
            tradeDetails[sender].tokenA,
            trade2AcquiredCoin
        );

        // Profit check
        bool profCheck = checkProfitability(loanAmount, trade3AcquiredCoin);
        require(profCheck, "Arbitrage not profitable");

        // Pay yourself back first
        IERC20 otherToken = IERC20(tradeDetails[sender].tokenA);
        otherToken.transfer(sender, trade3AcquiredCoin - amountToRepay);

        // Pay loan back
        // Token A as borrowed token
        IERC20(tokenA).transfer(pair, amountToRepay);
    }
}
