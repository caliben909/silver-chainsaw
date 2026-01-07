// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IUniswapV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IStargateRouter {
    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256 nativeFee, uint256 zroFee);
    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;
}

struct lzTxObj {
    uint256 dstGasForCall;
    uint256 dstNativeAmount;
    bytes dstNativeAddr;
}

interface IMCPDistributor {
    function getWallets() external view returns (address[10] memory);
}

interface IPositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external returns (uint256, uint128, uint256, uint256);
    function burn(uint256 tokenId) external returns (uint256, uint256);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IQuoter {
    function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160 sqrtPriceLimitX96) external returns (uint256 amountOut);
}

interface ISkimRouter {
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);
}

contract GodModeEmpire is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public treasury;
    uint256 public constant DEV_FEE_BPS = 5; // 0.05%
    uint256 public constant MAX_SKEW_BPS = 15; // 1.5% max
    uint256 public constant SLIPPAGE_BPS = 100; // 1%

    // === 18 TOKENS (ARBITRUM) ===
    address public USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public stETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address public GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public MAGIC = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
    address public GRAIL = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
    address public RDNT = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
    address public PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
    address public LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public UNI = 0x6FD9D7AD17242C41F7131d257212c54a11213923;
    address public AAVE_TOKEN = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
    address public ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address public LDO = 0x13Ad51ed4F1B7e9Dc168d8a00cB3f4dDD85EfA60;
    address public CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address public PEPE = 0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00;
    address public BONK = 0x09199D9A5F4448d0848e4395D065e1A1C5A5263f;
    address public SXAU = 0x9D5f8C42F21d0234eFF8274de832C6E123c2B46a;

    // === ORACLES (ARBITRUM) ===
    AggregatorV3Interface public usdcOracle = AggregatorV3Interface(0x50834f3163758fCC1Df9973B6e91f0f0f0434AD6);
    AggregatorV3Interface public usdtOracle = AggregatorV3Interface(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7);
    AggregatorV3Interface public wbtcOracle = AggregatorV3Interface(0x6ce185860a4963106506C203335A2910413708e9);
    AggregatorV3Interface public wethOracle = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
    AggregatorV3Interface public linkOracle = AggregatorV3Interface(0x86E53cF1B870786351165d955b07ed0F7f4c3d2b);
    AggregatorV3Interface public uniOracle = AggregatorV3Interface(0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720);
    AggregatorV3Interface public aaveOracle = AggregatorV3Interface(0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034);
    AggregatorV3Interface public arbOracle = AggregatorV3Interface(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6);
    AggregatorV3Interface public ldoOracle = AggregatorV3Interface(0xa43A34030088e6510EeCf95376B516FcE9b74B57);
    AggregatorV3Interface public crvOracle = AggregatorV3Interface(0xaebDA2c976cfd1eE1977Eac079B4382acb849325);
    AggregatorV3Interface public sxauOracle = AggregatorV3Interface(0x8F383361A85268365259F3a8824c3f1d9BC4f9A0);
    // PEPE/BONK: no oracles → skip price check

    // === UNISWAP V3 INFRA ===
    address public constant POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6; // Uniswap V3 Quoter on Arbitrum
    address public skimRouter; // To be set after deployment

    // === POOL MAPPING ===
    mapping(bytes32 => address) public pairToPool;

    address public constant STARGATE_ROUTER = 0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614;
    uint16 public constant BSC_CHAIN_ID = 102;
    uint256 public constant ETH_POOL_ID = 1;
    uint256 public constant BNB_POOL_ID = 2;
    address public mcpDistributor;
    mapping(address => uint8) public tokenDecimals;

    constructor(address _treasury) {
        treasury = _treasury;
        mcpDistributor = _treasury;
        // Initialize pools with actual Uniswap V3 addresses on Arbitrum
        pairToPool[keccak256(abi.encodePacked(USDC, USDT))] = 0x6c60E6Ab82D73491e345FC3333D3C875211e5f3F; // 0.01%
        pairToPool[keccak256(abi.encodePacked(USDC, WETH))] = 0x03f73225F2a68e94F23752F8384D9e5A1E5A1A98; // 0.05%
        pairToPool[keccak256(abi.encodePacked(WBTC, WETH))] = 0x2f5e87C9312fa29aed5c179E456625D79015299c; // 0.3%
        pairToPool[keccak256(abi.encodePacked(LINK, WETH))] = 0x4A5A2a152E985078e1a4Aa9C3362c7B8ae3D1a5f; // 0.3%
        pairToPool[keccak256(abi.encodePacked(ARB, WETH))] = 0x0d4D12115904c50e02333028B4D8d75A76247315; // 0.3%
        pairToPool[keccak256(abi.encodePacked(DAI, USDC))] = 0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6; // 0.01%
        // Add more pools as needed for triangular and cross-pool arbitrage
        pairToPool[keccak256(abi.encodePacked(USDT, DAI))] = 0x0000000000000000000000000000000000000000; // Placeholder, find actual
        pairToPool[keccak256(abi.encodePacked(WETH, ARB))] = 0x0d4D12115904c50e02333028B4D8d75A76247315; // Same as ARB/WETH
            tokenDecimals[USDC] = 6;
            tokenDecimals[USDT] = 6;
            tokenDecimals[DAI] = 6;
            tokenDecimals[WBTC] = 8;
            tokenDecimals[WETH] = 18;
            tokenDecimals[stETH] = 18;
            tokenDecimals[GMX] = 18;
            tokenDecimals[MAGIC] = 18;
            tokenDecimals[GRAIL] = 18;
            tokenDecimals[RDNT] = 18;
            tokenDecimals[PENDLE] = 18;
            tokenDecimals[LINK] = 18;
            tokenDecimals[UNI] = 18;
            tokenDecimals[AAVE_TOKEN] = 18;
            tokenDecimals[ARB] = 18;
            tokenDecimals[LDO] = 18;
            tokenDecimals[CRV] = 18;
            tokenDecimals[PEPE] = 18;
            tokenDecimals[BONK] = 18;
            tokenDecimals[SXAU] = 18;
        }

    function setSkimRouter(address _skimRouter) external onlyOwner {
        skimRouter = _skimRouter;
    }

    // === TRIGGER FLASHLOAN ARB ===
    function executeSkewArb(address tokenIn, address tokenOut, uint256 amount) external onlyOwner {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        address pool = pairToPool[key];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(uint8(1), tokenIn, tokenOut, amount));
    }

    // === TRIGGER TRIANGULAR ARB ===
    function executeTriangularArb(uint256 amount) external onlyOwner {
        // Triangular: USDC -> USDT -> DAI -> USDC
        address pool = pairToPool[keccak256(abi.encodePacked(USDC, USDT))];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(uint8(5), USDC, USDT, amount));
    }

    // === TRIGGER LIQUID ARB MODES ===
    function executeLiquidArbUSDCWETH(uint256 amount) external onlyOwner {
        address pool = pairToPool[keccak256(abi.encodePacked(USDC, WETH))];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(uint8(7), USDC, WETH, amount));
    }

    function executeLiquidArbWBTCWETH(uint256 amount) external onlyOwner {
        address pool = pairToPool[keccak256(abi.encodePacked(WBTC, WETH))];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), 0, amount, abi.encode(uint8(8), WBTC, WETH, amount));
    }

    function executeCrossPoolArb(uint256 amount) external onlyOwner {
        address pool = pairToPool[keccak256(abi.encodePacked(USDC, WETH))];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(uint8(9), USDC, WETH, amount));
    }

    function executeAdvancedArb(uint256 amount) external onlyOwner {
        address pool = pairToPool[keccak256(abi.encodePacked(WETH, ARB))];
        require(pool != address(0), "POOL_NOT_FOUND");
        IUniswapV3Pool(pool).flash(address(this), 0, amount, abi.encode(uint8(10), WETH, ARB, amount));
    }

    // === FLASHLOAN CALLBACK ===
    function uniswapV3FlashCallback(uint256 fee0, uint256, bytes calldata data) external nonReentrant {
        (uint8 mode, address tokenIn, address tokenOut, uint256 amount) = abi.decode(data, (uint8, address, address, uint256));
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        address pool = pairToPool[key];
        require(msg.sender == pool, "INVALID_POOL");
        require(mode == 1 || mode == 5 || mode == 7 || mode == 8 || mode == 9 || mode == 10, "INVALID_MODE");

        // Risk checks
        require(_checkVolatility(tokenIn, tokenOut), "High volatility");
        uint256 estimatedProfit = _simulateProfit(mode, tokenIn, tokenOut, amount);
        require(estimatedProfit > (amount * 1) / 100, "Insufficient profit"); // 1% min

        uint256 startBal = IERC20(tokenIn).balanceOf(address(this));

        if (mode == 1) {
            // Skewed arbitrage
            uint256 marketPrice = _getMarketPrice(tokenIn, tokenOut);
            uint256 maxSkew = (marketPrice * MAX_SKEW_BPS) / 10000; // 1.5%
            uint256 skewedPrice = marketPrice - maxSkew;

            (uint256 tokenId,,) = _bootstrapSkewedLiquidity(pool, tokenIn, tokenOut, amount, skewedPrice);

            uint256 tokenOutAmt = _swap(tokenIn, tokenOut, amount);
            uint256 tokenInFinal = _swap(tokenOut, tokenIn, tokenOutAmt);

            IPositionManager(POSITION_MANAGER).burn(tokenId);
        } else if (mode == 5) {
            // Triangular arbitrage: USDC -> USDT -> DAI -> USDC
            uint256 amt1 = _swap(USDC, USDT, amount);
            uint256 amt2 = _swap(USDT, DAI, amt1);
            _swap(DAI, USDC, amt2);
        } else if (mode == 7) {
            // Liquid arbitrage: USDC -> WETH -> USDC
            uint256 wethAmt = _swap(USDC, WETH, amount);
            _swap(WETH, USDC, wethAmt);
        } else if (mode == 8) {
            // Liquid arbitrage: WBTC -> WETH -> WBTC
            uint256 wethAmt = _swap(WBTC, WETH, amount);
            _swap(WETH, WBTC, wethAmt);
        } else if (mode == 9) {
            // Cross-pool arbitrage: USDC -> WETH -> WBTC -> USDC
            uint256 wethAmt = _swap(USDC, WETH, amount);
            uint256 wbtcAmt = _swap(WETH, WBTC, wethAmt);
            _swap(WBTC, USDC, wbtcAmt);
        } else if (mode == 10) {
            // Advanced arbitrage: WETH -> ARB -> WETH
            uint256 arbAmt = _swap(WETH, ARB, amount);
            _swap(ARB, WETH, arbAmt);
        }

        // 5. REPAY FLASHLOAN
        uint256 repayAmount = amount + (tokenIn == IUniswapV3Pool(pool).token0() ? fee0 : 0);
        SafeERC20.forceApprove(IERC20(tokenIn), pool, repayAmount);
        IERC20(tokenIn).safeTransfer(pool, repayAmount);

        // 6. SEND PROFIT
        uint256 profit = IERC20(tokenIn).balanceOf(address(this)) - startBal;
        if (profit > 0) {
            uint256 devFee = (profit * DEV_FEE_BPS) / 10000;
            IERC20(tokenIn).safeTransfer(owner(), devFee);
            uint256 netProfit = profit - devFee;
            // Convert netProfit to ETH
            uint256 ethProfit = _swap(tokenIn, WETH, netProfit);
            // Reserve 10% for gas
            uint256 gasReserve = ethProfit / 10;
            uint256 distributable = ethProfit - gasReserve;
            // Get wallets
            address[10] memory wallets = IMCPDistributor(mcpDistributor).getWallets();
            // Amount per wallet
            uint256 amountPerWallet = distributable / 10;
            // Calculate fee
            (uint256 fee,) = IStargateRouter(STARGATE_ROUTER).quoteLayerZeroFee(BSC_CHAIN_ID, 1, abi.encode(wallets[0]), "", lzTxObj(0, 0, ""));
            uint256 totalFee = fee * 10;
            require(gasReserve >= totalFee, "Insufficient gas reserve");
            // Approve WETH to router
            SafeERC20.forceApprove(IERC20(WETH), STARGATE_ROUTER, distributable);
            // Bridge each
            for (uint i = 0; i < 10; i++) {
                IStargateRouter(STARGATE_ROUTER).swap{value: fee}(
                    BSC_CHAIN_ID,
                    ETH_POOL_ID,
                    BNB_POOL_ID,
                    payable(owner()),
                    amountPerWallet,
                    amountPerWallet * 95 / 100,
                    lzTxObj(0, 0, ""),
                    abi.encode(wallets[i]),
                    ""
                );
            }
            // Send remaining gasReserve to owner
            IERC20(WETH).safeTransfer(owner(), gasReserve - totalFee);
        }
    }

    function _bootstrapSkewedLiquidity(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 skewedPrice
    ) internal returns (uint256 tokenId, uint256 token0Amt, uint256 token1Amt) {
        address t0 = IUniswapV3Pool(pool).token0();
        address t1 = IUniswapV3Pool(pool).token1();
        bool inIsToken0 = (tokenIn == t0);

        // Calculate skewed reserves
        uint256 amt0 = inIsToken0 ? amount : (amount * 1e18) / skewedPrice;
        uint256 amt1 = inIsToken0 ? (amount * 1e18) / skewedPrice : amount;

        // Get second token via swap
        if (inIsToken0) {
            amt1 = _swap(tokenIn, tokenOut, amt0);
        } else {
            uint256 token0Simulated = _swap(tokenOut, tokenIn, amt1);
            amt0 = token0Simulated;
        }

        SafeERC20.forceApprove(IERC20(t0), POSITION_MANAGER, amt0);
        SafeERC20.forceApprove(IERC20(t1), POSITION_MANAGER, amt1);

        (tokenId, , token0Amt, token1Amt) = IPositionManager(POSITION_MANAGER).mint(
            IPositionManager.MintParams({
                token0: t0,
                token1: t1,
                fee: _getPoolFee(pool),
                tickLower: -887272,
                tickUpper: 887272,
                amount0Desired: amt0,
                amount1Desired: amt1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 300
            })
        );
    }

    function _getMarketPrice(address tokenA, address tokenB) internal returns (uint256) {
        AggregatorV3Interface oracleA = _getOracle(tokenA);
        AggregatorV3Interface oracleB = _getOracle(tokenB);

        // Try oracles first
        if (address(oracleA) != address(0) && address(oracleB) != address(0)) {
            (, int256 priceA,,,) = oracleA.latestRoundData();
            (, int256 priceB,,,) = oracleB.latestRoundData();
            if (priceA > 0 && priceB > 0) {
                return (uint256(priceA) * 1e18) / uint256(priceB);
            }
        }

        // Fallback to TWAP for oracle-less or invalid oracle tokens
        return _getTWAPPrice(tokenA, tokenB);
    }

    function _getTWAPPrice(address tokenA, address tokenB) internal returns (uint256) {
        // For simplicity, assume tokenA/tokenB pool exists and use quoter
        // In practice, may need to handle multiple pools or DEXs
        address pool = pairToPool[keccak256(abi.encodePacked(tokenA, tokenB))];
        if (pool == address(0)) return 1e18; // Assume 1:1 if no pool
        uint24 fee = _getPoolFee(pool);
        try IQuoter(QUOTER).quoteExactInputSingle(tokenA, tokenB, fee, 1e18, 0) returns (uint256 amountOut) {
            return amountOut;
        } catch {
            return 1e18; // Fallback
        }
    }

    function _checkVolatility(address tokenA, address tokenB) internal returns (bool) {
        // Simple volatility check: compare oracle price with TWAP
        uint256 oraclePrice = _getMarketPrice(tokenA, tokenB);
        uint256 twapPrice = _getTWAPPrice(tokenA, tokenB);
        uint256 deviation = oraclePrice > twapPrice ? (oraclePrice - twapPrice) * 10000 / twapPrice : (twapPrice - oraclePrice) * 10000 / oraclePrice;
        return deviation <= 500; // 5% max deviation
    }

    function _simulateProfit(uint8 mode, address tokenIn, address tokenOut, uint256 amount) internal returns (uint256) {
        // Simplified simulation: estimate output based on current prices
        if (mode == 1) {
            // Skewed arb: swap in -> out -> in
            uint256 outAmt = _estimateSwap(tokenIn, tokenOut, amount);
            uint256 finalAmt = _estimateSwap(tokenOut, tokenIn, outAmt);
            return finalAmt > amount ? finalAmt - amount : 0;
        } else if (mode == 5) {
            // Triangular
            uint256 amt1 = _estimateSwap(USDC, USDT, amount);
            uint256 amt2 = _estimateSwap(USDT, DAI, amt1);
            uint256 finalAmt = _estimateSwap(DAI, USDC, amt2);
            return finalAmt > amount ? finalAmt - amount : 0;
        }
        // Add for other modes
        return 0;
    }

    function _estimateSwap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256) {
        // Use quoter for estimation
        address pool = pairToPool[keccak256(abi.encodePacked(tokenIn, tokenOut))];
        if (pool == address(0)) return amountIn; // Assume 1:1
        uint24 fee = _getPoolFee(pool);
        try IQuoter(QUOTER).quoteExactInputSingle(tokenIn, tokenOut, fee, amountIn, 0) returns (uint256 amountOut) {
            return amountOut;
        } catch {
            return amountIn; // Fallback
        }
    }

    function _getOracle(address token) internal view returns (AggregatorV3Interface) {
        if (token == USDC) return usdcOracle;
        if (token == USDT) return usdtOracle;
        if (token == WBTC) return wbtcOracle;
        if (token == WETH) return wethOracle;
        if (token == LINK) return linkOracle;
        if (token == UNI) return uniOracle;
        if (token == AAVE_TOKEN) return aaveOracle;
        if (token == ARB) return arbOracle;
        if (token == LDO) return ldoOracle;
        if (token == CRV) return crvOracle;
        if (token == SXAU) return sxauOracle;
        return AggregatorV3Interface(address(0)); // No oracle
    }

    function _getPoolFee(address pool) internal view returns (uint24) {
        if (pool == pairToPool[keccak256(abi.encodePacked(USDC, USDT))]) {
            return 100; // 0.01%
        }
        return 3000; // 0.3%
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
        if (skimRouter != address(0)) {
            SafeERC20.forceApprove(IERC20(tokenIn), skimRouter, amountIn);
            return ISkimRouter(skimRouter).swapExactInputSingle(
                tokenIn,
                tokenOut,
                _getPoolFeeForPair(tokenIn, tokenOut),
                amountIn,
                _calculateMinOutput(tokenIn, tokenOut, amountIn),
                address(this)
            );
        } else {
            SafeERC20.forceApprove(IERC20(tokenIn), ROUTER, amountIn);
            return ISwapRouter(ROUTER).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: _getPoolFeeForPair(tokenIn, tokenOut),
                    recipient: address(this),
                    deadline: block.timestamp + 300,
                    amountIn: amountIn,
                    amountOutMinimum: _calculateMinOutput(tokenIn, tokenOut, amountIn),
                    sqrtPriceLimitX96: 0
                })
            );
        }
    }

    function _getPoolFeeForPair(address tokenIn, address tokenOut) internal view returns (uint24) {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        return _getPoolFee(pairToPool[key]);
    }
    
    function _calculateMinOutput(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256) {
        uint8 dIn = tokenDecimals[tokenIn];
        uint8 dOut = tokenDecimals[tokenOut];
        if (dIn == 0 || dOut == 0) return 0;
        AggregatorV3Interface oracleIn = _getOracle(tokenIn);
        AggregatorV3Interface oracleOut = _getOracle(tokenOut);
        if (address(oracleIn) == address(0) || address(oracleOut) == address(0)) {
            return 0;
        }
        (, int256 priceIn,,,) = oracleIn.latestRoundData();
        (, int256 priceOut,,,) = oracleOut.latestRoundData();
        if (priceIn <= 0 || priceOut <= 0) return 0;
        uint256 expectedOut = (amountIn * uint256(priceIn) * (10 ** dOut)) / (uint256(priceOut) * (10 ** dIn));
        uint256 minOut = (expectedOut * (10000 - SLIPPAGE_BPS)) / 10000;
        return minOut;
    }

    function rescueToken(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}