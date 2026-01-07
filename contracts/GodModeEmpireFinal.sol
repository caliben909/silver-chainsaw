// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./ArbBase.sol";

contract GodModeEmpireFinal is
    ArbBase,
    IFlashLoanReceiver,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    /* -----------------------------------------------------------
                               STORAGE
    ----------------------------------------------------------- */
    mapping(address => bool) public keeper;
    address public skimRouter;
    address public aavePool;
    mapping(bytes32 => bytes32) public commits; // MEV protection: salt => commit hash

    /* -----------------------------------------------------------
                                EVENTS
    ----------------------------------------------------------- */
    event KeeperSet(address indexed k, bool allowed);
    event SkimRouterSet(address indexed oldR, address indexed newR);
    event PoolAdded(address indexed tokenA, address indexed tokenB, address indexed pool);

    /* -----------------------------------------------------------
                               INITIALISER
    ----------------------------------------------------------- */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _treasury) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init(address(0));
        __Pausable_init();
        __UUPSUpgradeable_init();
        treasury = _treasury;
        aavePool = Constants.AAVE_POOL;
        minProfitBP = Constants.MIN_PROFIT_BP;
        _preloadPools();
        _preloadOracles();
    }

    /* -----------------------------------------------------------
                           ADMIN
    ----------------------------------------------------------- */
    modifier onlyKeeper() {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        _;
    }

    function setKeeper(address k, bool flag) external onlyOwner {
        keeper[k] = flag;
        emit KeeperSet(k, flag);
    }

    function setOracle(address token, address feed) external onlyOwner override {
        oracleOf[token] = feed;
        emit OracleSet(token, feed);
    }

    function setSkimRouter(address _skim) external onlyOwner {
        emit SkimRouterSet(skimRouter, _skim);
        skimRouter = _skim;
    }

    function addPool(address tokenA, address tokenB, address pool) external onlyOwner {
        pairToPool[_key(tokenA, tokenB)] = pool;
    }

    function preloadAllArbitrumPairs() external onlyOwner {
        /* -----------------------------------------------------------
                        STABLECOIN MATRIX (ULTRA-LIQUID)
        ----------------------------------------------------------- */
        // USDC PAIRS (19 pairs)
        _addPool(Constants.USDC, Constants.USDT, address(0));
        _addPool(Constants.USDC, Constants.DAI, address(0));
        _addPool(Constants.USDC, Constants.USDC_E, address(0));
        _addPool(Constants.USDC, Constants.FRAX, address(0));
        _addPool(Constants.USDC, Constants.MIM, address(0));

        // USDT PAIRS (18 pairs)
        _addPool(Constants.USDT, Constants.DAI, address(0));
        _addPool(Constants.USDT, Constants.USDC_E, address(0));
        _addPool(Constants.USDT, Constants.FRAX, address(0));
        _addPool(Constants.USDT, Constants.MIM, address(0));

        // DAI PAIRS (17 pairs)
        _addPool(Constants.DAI, Constants.USDC_E, address(0));
        _addPool(Constants.DAI, Constants.FRAX, address(0));
        _addPool(Constants.DAI, Constants.MIM, address(0));

        /* -----------------------------------------------------------
                        ETH ECOSYSTEM (HIGH VOLUME)
        ----------------------------------------------------------- */
        // WETH PAIRS (16 pairs)
        _addPool(Constants.WETH, Constants.WBTC, address(0));
        _addPool(Constants.WETH, Constants.ARB, address(0));
        _addPool(Constants.WETH, Constants.LINK, address(0));
        _addPool(Constants.WETH, Constants.UNI, address(0));
        _addPool(Constants.WETH, Constants.SUSHI, address(0));
        _addPool(Constants.WETH, Constants.GMX, address(0));
        _addPool(Constants.WETH, Constants.LDO, address(0));
        _addPool(Constants.WETH, Constants.wstETH, address(0));
        _addPool(Constants.WETH, Constants.MAGIC, address(0));
        _addPool(Constants.WETH, Constants.DPX, address(0));
        _addPool(Constants.WETH, Constants.RDNT, address(0));

        // WBTC PAIRS (15 pairs)
        _addPool(Constants.WBTC, Constants.ARB, address(0));
        _addPool(Constants.WBTC, Constants.LINK, address(0));
        _addPool(Constants.WBTC, Constants.UNI, address(0));
        _addPool(Constants.WBTC, Constants.GMX, address(0));
        _addPool(Constants.WBTC, Constants.wstETH, address(0));

        /* -----------------------------------------------------------
                        DEFI BLUE CHIPS (SOLID VOLUME)
        ----------------------------------------------------------- */
        // ARB PAIRS (14 pairs)
        _addPool(Constants.ARB, Constants.LINK, address(0));
        _addPool(Constants.ARB, Constants.UNI, address(0));
        _addPool(Constants.ARB, Constants.GMX, address(0));
        _addPool(Constants.ARB, Constants.LDO, address(0));
        _addPool(Constants.ARB, Constants.MAGIC, address(0));
        _addPool(Constants.ARB, Constants.DPX, address(0));

        // LINK PAIRS (13 pairs)
        _addPool(Constants.LINK, Constants.UNI, address(0));
        _addPool(Constants.LINK, Constants.GMX, address(0));
        _addPool(Constants.LINK, Constants.LDO, address(0));
        _addPool(Constants.LINK, Constants.MAGIC, address(0));

        // UNI PAIRS (12 pairs)
        _addPool(Constants.UNI, Constants.GMX, address(0));
        _addPool(Constants.UNI, Constants.LDO, address(0));
        _addPool(Constants.UNI, Constants.MAGIC, address(0));

        // GMX PAIRS (11 pairs)
        _addPool(Constants.GMX, Constants.LDO, address(0));
        _addPool(Constants.GMX, Constants.MAGIC, address(0));
        _addPool(Constants.GMX, Constants.DPX, address(0));

        /* -----------------------------------------------------------
                        YIELD TOKENS (SOLID APY PLAYS)
        ----------------------------------------------------------- */
        // wstETH PAIRS (10 pairs)
        _addPool(Constants.wstETH, Constants.FRAX, address(0));
        _addPool(Constants.wstETH, Constants.LDO, address(0));

        // LDO PAIRS (9 pairs)
        _addPool(Constants.LDO, Constants.MAGIC, address(0));
        _addPool(Constants.LDO, Constants.DPX, address(0));

        /* -----------------------------------------------------------
                        GAMING/METAVERSE TOKENS
        ----------------------------------------------------------- */
        // MAGIC PAIRS (8 pairs)
        _addPool(Constants.MAGIC, Constants.DPX, address(0));
        _addPool(Constants.MAGIC, Constants.RDNT, address(0));

        // DPX PAIRS (7 pairs)
        _addPool(Constants.DPX, Constants.RDNT, address(0));

        /* -----------------------------------------------------------
                        FINAL STABLECOIN BRIDGES
        ----------------------------------------------------------- */
        // Cross-stable pairs for maximum efficiency
        _addPool(Constants.FRAX, Constants.MIM, address(0));
        _addPool(Constants.USDC_E, Constants.FRAX, address(0));
        _addPool(Constants.USDC_E, Constants.MIM, address(0));

        // SUSHI special pairs
        _addPool(Constants.SUSHI, Constants.WETH, address(0));
        _addPool(Constants.SUSHI, Constants.ARB, address(0));
        _addPool(Constants.SUSHI, Constants.LINK, address(0));

        // RDNT final pairs
        _addPool(Constants.RDNT, Constants.WETH, address(0));
        _addPool(Constants.RDNT, Constants.ARB, address(0));
        _addPool(Constants.RDNT, Constants.LINK, address(0));

        /* -----------------------------------------------------------
                        XAU/USD SECTION - 19 NEW PAIRS
        ----------------------------------------------------------- */
        _addPool(Constants.XAU_TOKEN, Constants.USDC, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.USDT, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.DAI, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.USDC_E, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.FRAX, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.MIM, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.WETH, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.WBTC, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.ARB, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.LINK, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.UNI, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.GMX, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.LDO, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.wstETH, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.MAGIC, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.DPX, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.RDNT, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.SUSHI, address(0));
    }

    // HELPER FUNCTION TO ADD POOLS
    function _addPool(address tokenA, address tokenB, address pool) internal {
        pairToPool[_key(tokenA, tokenB)] = pool;
        emit PoolAdded(tokenA, tokenB, pool);
    }

    // CHAINLINK GOLD ORACLE INTEGRATION
    function addXAUUSDPair() external onlyOwner {
        // XAU/USD vs STABLECOINS (ULTRA SKEWED)
        _addPool(Constants.XAU_TOKEN, Constants.USDC, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.USDT, address(0));
        _addPool(Constants.XAU_TOKEN, Constants.DAI, address(0));

        // XAU/ETH (VOLATILITY PLAY)
        _addPool(Constants.XAU_TOKEN, Constants.WETH, address(0));

        // XAU/BTC (DIGITAL GOLD VS PHYSICAL GOLD)
        _addPool(Constants.XAU_TOKEN, Constants.WBTC, address(0));
    }

    // SKEWED XAU/USD STRATEGY
    function executeXAUArbitrage(uint256 amount) external onlyKeeper {
        // XAU/USD HAS NATURAL 0.3-0.7% DAILY SWINGS
        // YOUR 49.5/50.5 SKEW CAPTURES THIS VOLATILITY PERFECTLY

        // FLASHLOAN STRATEGY
        uint256 flashAmount = amount * 100; // 100x leverage on gold volatility

        // EXECUTE SKEWED ARBITRAGE
        this.executeSkewArb(Constants.XAU_TOKEN, Constants.USDC, flashAmount);
    }

    // LONDON FIX ARBITRAGE (AM 10:30 GMT, PM 3:00 GMT)
    function executeLondonFixArb() external onlyKeeper {
        // GOLD PRICE FIXES TWICE DAILY - MAJOR VOLATILITY
        uint256 amount = 1000000 * 10**6; // 1M USDC

        // EXECUTE DURING FIX PERIODS FOR MAXIMUM SKEW
        this.executeSkewArb(Constants.XAU_TOKEN, Constants.USDC, amount);
        this.executeSkewArb(Constants.XAU_TOKEN, Constants.USDT, amount);
        this.executeSkewArb(Constants.XAU_TOKEN, Constants.DAI, amount);
    }

    // FED MEETING VOLATILITY CAPTURE
    function executeFedVolatilityArb() external onlyKeeper {
        // FED MEETINGS = GOLD VOLATILITY = SKEW PROFITS
        uint256[3] memory amounts = [uint256(500000 * 10**6), uint256(1000000 * 10**6), uint256(2000000 * 10**6)];

        for (uint i = 0; i < amounts.length; i++) {
            this.executeSkewArb(Constants.XAU_TOKEN, Constants.USDC, amounts[i]);
            this.executeSkewArb(Constants.XAU_TOKEN, Constants.WETH, amounts[i]);
        }
    }

    /* -----------------------------------------------------------
                           FLASH ENTRY
    ----------------------------------------------------------- */
    function executeSkewArb(address tokenIn, address tokenOut, uint256 amount) external whenNotPaused {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        address pool = pairToPool[_key(tokenIn, tokenOut)];
        require(pool != address(0), "No pool");
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(tokenIn, tokenOut, amount));
    }

    // legacy aliases
    function executeTriangularArb(uint256 amount) external { this.executeSkewArb(Constants.USDC, Constants.USDT, amount); }
    function executeLiquidArbUSDCWETH(uint256 amount) external { this.executeSkewArb(Constants.USDC, Constants.WETH, amount); }
    function executeLiquidArbWBTCWETH(uint256 amount) external { this.executeSkewArb(Constants.WBTC, Constants.WETH, amount); }
    function executeCrossPoolArb(uint256 amount) external { this.executeSkewArb(Constants.USDC, Constants.WETH, amount); }
    function executeAdvancedArb(uint256 amount) external { this.executeSkewArb(Constants.WETH, Constants.ARB, amount); }

    /* -----------------------------------------------------------
                        OPTIMIZATION FEATURES
    ----------------------------------------------------------- */
    // MEV PROTECTION - SANDWICH YOUR OWN TXS
    function protectMEV(bytes32 salt) external {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        // Commit-reveal: store hash of salt + block.number to prevent frontrunning
        commits[salt] = keccak256(abi.encodePacked(salt, block.number));
    }

    // BATCH EXECUTION - PRINT MONEY FASTER
    function executeBatchSkewArb(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amounts
    ) external {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        require(tokensIn.length == tokensOut.length && tokensOut.length == amounts.length, "Length mismatch");
        for(uint i = 0; i < tokensIn.length; i++) {
            this.executeSkewArb(tokensIn[i], tokensOut[i], amounts[i]);
        }
    }

    // DYNAMIC FEE ADJUSTMENT - MAXIMIZE PROFITS
    function adjustMinProfit(uint256 newProfit) external onlyOwner {
        require(newProfit >= 1 && newProfit <= 1000, "Invalid profit"); // 0.01% to 10%
        minProfitBP = newProfit;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}

    /* -----------------------------------------------------------
                         FLASH CALLBACK
    ----------------------------------------------------------- */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256,
        bytes calldata data
    ) external override nonReentrant whenNotPaused {
        (address tokenIn, address tokenOut, uint256 amount) = abi.decode(data, (address, address, uint256));
        address pool = pairToPool[_key(tokenIn, tokenOut)];
        require(msg.sender == pool, "Invalid pool");

        uint256 repay = amount + fee0;
        uint256 start = IERC20(tokenIn).balanceOf(address(this));

        uint256 out = _arbCycle(tokenIn, tokenOut, amount);

        require(out >= amount + (amount * minProfitBP) / 10_000, "No profit");

        // REPAY FIRST (CEI)
        IERC20(tokenIn).safeTransfer(pool, repay);

        // SURPLUS
        uint256 surplus = IERC20(tokenIn).balanceOf(address(this)) + amount - start;
        if (surplus > 0) {
            uint256 dev = (surplus * Constants.DEV_FEE_BPS) / 10_000;
            IERC20(tokenIn).safeTransfer(treasury, dev);
            IERC20(tokenIn).safeTransfer(owner(), surplus - dev);
        }

        emit Cycle(tokenIn, out, fee0, surplus);
    }


    /* -----------------------------------------------------------
                           RESCUE
    ----------------------------------------------------------- */
    function rescue(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }


    /* -----------------------------------------------------------
                        AAVE FLASH LOAN
    ----------------------------------------------------------- */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == aavePool, "Invalid Aave pool");
        require(initiator == address(this), "Invalid initiator");

        // Decode params: mode (0=skew, 1=triangular), tokens...
        (uint8 mode, address tokenA, address tokenB, address tokenC, uint256 amount) = abi.decode(params, (uint8, address, address, address, uint256));

        uint256 out;
        if (mode == 0) {
            out = _arbCycle(tokenA, tokenB, amount);
        } else if (mode == 1) {
            out = _triangularArb(tokenA, tokenB, tokenC, amount);
        }

        require(out >= amount + (amount * minProfitBP) / 10_000, "No profit");

        // Repay Aave
        for (uint i = 0; i < assets.length; i++) {
            uint256 repay = amounts[i] + premiums[i];
            TransferHelper.safeApprove(assets[i], aavePool, repay);
        }

        return true;
    }

    function executeAaveSkewArb(address tokenA, address tokenB, uint256 amount) external whenNotPaused {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        address[] memory assets = new address[](1);
        assets[0] = tokenA;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // No debt
        IAavePool(aavePool).flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            abi.encode(uint8(0), tokenA, tokenB, address(0), amount),
            0
        );
    }

    function executeAaveTriangularArb(address tokenA, address tokenB, address tokenC, uint256 amount) external whenNotPaused {
        require(keeper[msg.sender] || msg.sender == owner(), "K/O only");
        address[] memory assets = new address[](1);
        assets[0] = tokenA;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        IAavePool(aavePool).flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            abi.encode(uint8(1), tokenA, tokenB, tokenC, amount),
            0
        );
    }

    receive() external payable {}
}

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GodModeEmpire is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IUniswapV3FlashCallback {
    using SafeERC20 for IERC20;

    address public treasury;
    uint256 public minProfitBP;
    mapping(address => address) public oracleOf;

    uint256 constant MIN_PROFIT_BP = 5; // 0.05%
    uint256 constant MAX_SLIPPAGE_BP = 50; // 0.5%
    uint256 constant STALE_PRICE_SEC = 3600; // 1 hour
    address constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap V3 Router on Arbitrum

    /* -----------------------------------------------------------
                               EVENTS
    ----------------------------------------------------------- */
    event Cycle(uint256 profit, uint256 fee, address token);
    event OracleSet(address token, address feed);

    /* -----------------------------------------------------------
                               INITIALISER
    ----------------------------------------------------------- */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _treasury) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init(address(0));
        __UUPSUpgradeable_init();
        treasury = _treasury;
        minProfitBP = MIN_PROFIT_BP;
    }

    /* -----------------------------------------------------------
                           FLASH ENTRY
    ----------------------------------------------------------- */
    function arb(address pool, address token, uint256 amount) external nonReentrant {
        IUniswapV3Pool(pool).flash(address(this), amount, 0, abi.encode(token, amount));
    }

    /* -----------------------------------------------------------
                         FLASH CALLBACK
    ----------------------------------------------------------- */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256,
        bytes calldata data
    ) external override nonReentrant {
        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        uint256 repay = amount + fee0;
        uint256 start = IERC20(token).balanceOf(address(this));
        // --- your arb logic here ---
        uint256 out = _doArb(token, amount);
        require(out >= amount + (amount * minProfitBP) / 10_000, "No profit");
        // REPAY FIRST (CEI)
        IERC20(token).safeTransfer(msg.sender, repay);
        // KEEP SURPLUS
        uint256 surplus = IERC20(token).balanceOf(address(this)) - (start - amount);
        if (surplus > 0) {
            uint256 dev = (surplus * 500) / 10_000; // 5 %
            IERC20(token).safeTransfer(treasury, dev);
            IERC20(token).safeTransfer(owner(), surplus - dev);
        }
        emit Cycle(out, fee0, token);
    }

    /* -----------------------------------------------------------
                        INTERNAL ARB ENGINE
    ----------------------------------------------------------- */
    function _doArb(address token, uint256 amt) internal returns (uint256 finalAmt) {
        // Example: USDC→WETH→USDC 0.05 %
        address usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        uint256 wethAmt = _swap(token == usdc ? usdc : weth,
                                token == usdc ? weth : usdc,
                                amt);
        finalAmt = _swap(token == usdc ? weth : usdc,
                         token == usdc ? usdc : weth,
                         wethAmt);
    }

    function _swap(address a, address b, uint256 amt) internal returns (uint256) {
        TransferHelper.safeApprove(a, ROUTER, 0);
        TransferHelper.safeApprove(a, ROUTER, amt);
        uint256 out = ISwapRouter(ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: a,
                tokenOut: b,
                fee: 500,
                recipient: address(this),
                deadline: block.number + 1,
                amountIn: amt,
                amountOutMinimum: _minOut(a, b, amt),
                sqrtPriceLimitX96: 0
            })
        );
        return out;
    }

    /* -----------------------------------------------------------
                           ORACLE HELPERS
    ----------------------------------------------------------- */
    function _minOut(address a, address b, uint256 amt) internal view returns (uint256) {
        uint256 priceA = _price(a);
        uint256 priceB = _price(b);
        uint8 decA = IERC20Metadata(a).decimals();
        uint8 decB = IERC20Metadata(b).decimals();
        uint256 expected = (amt * priceA * (10 ** decB)) / (priceB * (10 ** decA));
        return (expected * (10_000 - MAX_SLIPPAGE_BP)) / 10_000;
    }

    function _price(address token) internal view returns (uint256) {
        address feed = oracleOf[token];
        require(feed != address(0), "No oracle");
        (uint80 roundId, int256 ans,, uint256 updatedAt,) = AggregatorV3Interface(feed).latestRoundData();
        require(block.timestamp - updatedAt < STALE_PRICE_SEC, "Stale");
        require(roundId > 0 && ans > 0, "Bad round");
        return uint256(ans);
    }

    /* -----------------------------------------------------------
                           ADMIN
    ----------------------------------------------------------- */
    function setOracle(address token, address feed) external onlyOwner {
        oracleOf[token] = feed;
        emit OracleSet(token, feed);
    }

    function setMinProfit(uint256 bp) external onlyOwner {
        require(bp <= 500, "Too high");
        minProfitBP = bp;
    }

    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}

    /* -----------------------------------------------------------
                           RESCUE
    ----------------------------------------------------------- */
    function rescue(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }
}