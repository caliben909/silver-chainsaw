// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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

interface IAaveFlashLoan {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface INonfungiblePositionManager {
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

    function mint(MintParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

interface IBalancerVault {
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

contract GodModeEmpire is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct ArbPath {
        address[4] tokens;
        uint24[3] fees;
    }

    event Bootstrapped(uint256 amount);
    event ArbExecuted(uint8 mode, uint256 amount, uint256 profit);
    event FeeUpdated(uint256 newFeeBP);
    event TradeSizeUpdated(uint256 newMaxTradeSize);

    ISwapRouter public immutable SKIM_ROUTER;
    address public treasury;
    uint256 public devFeeBP = 5; // 0.05%

    uint256 public maxTradeSize = 1_000_000e6;
    uint256 public cooldownPeriod = 240;
    uint256 public lastTradeTime;

    // Configurable token addresses
    address public USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address public MAGIC = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
    address public GRAIL = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
    address public RDNT = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
    address public PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
    address public LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address public UNI = 0x0000000000000000000000000000000000000000;
    address public AAVE_TOKEN = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
    address public ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address public LDO = 0x13Ad51ed4F1B7e9Dc168d8a00cB3f4dDD85EfA60;
    address public CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address public PEPE = 0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00;
    address public BONK = 0x09199D9A5F4448d0848e4395D065e1A1C5A5263f;

    address public AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 on Arbitrum
    address public BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer Vault on Arbitrum
    address public POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // Uniswap V3 Positions

    // Chainlink oracles
    // AggregatorV3Interface public usdcOracle = AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD64); // USDC/USD on Arbitrum
    AggregatorV3Interface public usdtOracle = AggregatorV3Interface(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7); // USDT/USD on Arbitrum
    AggregatorV3Interface public wbtcOracle = AggregatorV3Interface(0x6ce185860a4963106506C203335A2910413708e9); // WBTC/USD on Arbitrum
    AggregatorV3Interface public wethOracle = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // WETH/USD (ETH/USD) on Arbitrum
    AggregatorV3Interface public linkOracle = AggregatorV3Interface(0x86E53cF1B870786351165d955b07ed0F7f4c3d2b); // LINK/USD on Arbitrum
    AggregatorV3Interface public uniOracle = AggregatorV3Interface(0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720); // UNI/USD on Arbitrum
    AggregatorV3Interface public aaveOracle = AggregatorV3Interface(0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034); // AAVE/USD on Arbitrum
    AggregatorV3Interface public arbOracle = AggregatorV3Interface(0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6); // ARB/USD on Arbitrum
    AggregatorV3Interface public ldoOracle = AggregatorV3Interface(0xa43A34030088e6510EeCf95376B516FcE9b74B57); // LDO/USD on Arbitrum
    AggregatorV3Interface public crvOracle = AggregatorV3Interface(0xaebDA2c976cfd1eE1977Eac079B4382acb849325); // CRV/USD on Arbitrum
    AggregatorV3Interface public pepeOracle = AggregatorV3Interface(address(0)); // No oracle
    AggregatorV3Interface public bonkOracle = AggregatorV3Interface(address(0)); // No oracle

    constructor(address _skimRouter, address _treasury) Ownable(msg.sender) {
        SKIM_ROUTER = ISwapRouter(_skimRouter);
        treasury = _treasury;
    }

    function bootstrapEmpire(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        require(block.timestamp >= lastTradeTime + cooldownPeriod, "Cooldown active");
        lastTradeTime = block.timestamp;
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(1), 0);
    }

    function startInfinitePrint(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        require(block.timestamp >= lastTradeTime + cooldownPeriod, "Cooldown active");
        lastTradeTime = block.timestamp;
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(2), 0);
    }

    function cexDexPegArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(3), 0);
    }

    function triangularStableArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(4), 0);
    }

    function crossDexCurveArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(5), 0);
    }

    function rwaPegArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(6), 0);
    }

    function basisTradeLoop(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(7), 0);
    }

    function btcLiquidArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), WBTC, amount, abi.encode(8), 0);
    }

    function quadArb(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        IAaveFlashLoan(AAVE_POOL).flashLoanSimple(address(this), USDC, amount, abi.encode(9), 0);
    }

    function bootstrapBalancer(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        require(block.timestamp >= lastTradeTime + cooldownPeriod, "Cooldown active");
        lastTradeTime = block.timestamp;
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, abi.encode(1));
    }

    function bootstrapPair(address tokenA, address tokenB, uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount > 0 && amount <= maxTradeSize, "Invalid amount");
        require(block.timestamp >= lastTradeTime + cooldownPeriod, "Cooldown active");
        lastTradeTime = block.timestamp;

        // Transfer tokenA from owner to contract
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amount);

        // Swap all tokenA to tokenB
        _swap(tokenA, tokenB, 100, amount);

        uint256 tokenBAmount = IERC20(tokenB).balanceOf(address(this));

        // Portion to keep as tokenB: 49.5%, swap back 50.5%
        uint256 tokenBPortion = tokenBAmount * 495 / 1000; // 49.5%
        uint256 swapBackAmount = tokenBAmount - tokenBPortion; // 50.5%

        // Swap back to tokenA
        _swap(tokenB, tokenA, 100, swapBackAmount);

        // Balances after swaps
        uint256 tokenABal = IERC20(tokenA).balanceOf(address(this));
        uint256 tokenBBal = IERC20(tokenB).balanceOf(address(this));

        // Determine token0 and token1
        address token0 = tokenA < tokenB ? tokenA : tokenB;
        address token1 = tokenA < tokenB ? tokenB : tokenA;
        uint256 amount0Desired = token0 == tokenA ? tokenABal : tokenBBal;
        uint256 amount1Desired = token0 == tokenA ? tokenBBal : tokenABal;

        // Approve POSITION_MANAGER
        IERC20(token0).approve(POSITION_MANAGER, amount0Desired);
        IERC20(token1).approve(POSITION_MANAGER, amount1Desired);

        // Mint LP
        INonfungiblePositionManager(POSITION_MANAGER).mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: 100,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(0xdead),
                deadline: block.timestamp + 300
            })
        );

        emit Bootstrapped(amount);
    }

    function addGaugeBribe(address pool, uint256 amount) external onlyOwner {
        // Placeholder for gauge bribes (e.g., on Curve or Convex)
        // Transfer tokens to gauge
    }

    function autoCompoundFarm(address pool) external onlyOwner {
        // Placeholder for auto-compounding farms
    }

    function executeFlashLoan(address asset, uint256 amount, bytes calldata params) external nonReentrant {
        require(msg.sender == AAVE_POOL, "Not Aave");
        uint8 mode = abi.decode(params, (uint8));

        uint256 startBal = IERC20(asset).balanceOf(address(this));

        if (mode == 1) _skewedBootstrap(amount);
        else if (mode == 2) _infiniteLoop(amount);
        else if (mode == 3) _cexDexPegArb(amount);
        else if (mode == 4) _triangularStableArb(amount);
        else if (mode == 5) _crossDexCurveArb(amount);
        else if (mode == 6) _rwaPegArb(amount);
        else if (mode == 7) _basisTradeLoop(amount);
        else if (mode == 8) _btcLiquidArb(amount);
        else if (mode == 9) _quadArb(amount);
        // Other modes

        uint256 endBal = IERC20(asset).balanceOf(address(this));
        require(endBal >= startBal, "No profit");

        uint256 profit = endBal - startBal;
        uint256 devFee = profit * devFeeBP / 10000;
        if (devFee > 0) {
            IERC20(asset).safeTransfer(treasury, devFee);
        }

        // Repay Aave
        uint256 premium = amount * 9 / 10000; // Aave 0.09% fee
        require(endBal >= amount + premium + devFee, "Insufficient funds for repayment");
        IERC20(asset).safeTransfer(AAVE_POOL, amount + premium);

        // Send remaining profits to owner
        uint256 remaining = IERC20(asset).balanceOf(address(this));
        if (remaining > 0) {
            IERC20(asset).safeTransfer(owner(), remaining);
        }

        emit ArbExecuted(mode, amount, profit);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external nonReentrant {
        require(msg.sender == BALANCER_VAULT, "Not Balancer");
        uint8 mode = abi.decode(userData, (uint8));

        address asset = tokens[0];
        uint256 amount = amounts[0];
        uint256 startBal = IERC20(asset).balanceOf(address(this));

        if (mode == 1) _skewedBootstrap(amount);
        // Add other modes if needed

        uint256 endBal = IERC20(asset).balanceOf(address(this));
        require(endBal >= startBal, "No profit");

        uint256 profit = endBal - startBal;
        uint256 devFee = profit * devFeeBP / 10000;
        if (devFee > 0) {
            IERC20(asset).safeTransfer(treasury, devFee);
        }

        // Repay Balancer
        require(endBal >= amount + feeAmounts[0] + devFee, "Insufficient funds for repayment");
        IERC20(asset).safeTransfer(BALANCER_VAULT, amount + feeAmounts[0]);
        // Send remaining profits to owner
        uint256 remaining = IERC20(asset).balanceOf(address(this));
        if (remaining > 0) {
            IERC20(asset).safeTransfer(owner(), remaining);
        }
        emit ArbExecuted(mode, amount, profit);
    }

    function _skewedBootstrap(uint256 amount) internal {
        // Swap borrowed USDC to USDT to start with USDT balance
        _swap(USDC, USDT, 100, amount);

        uint256 usdtAmount = IERC20(USDT).balanceOf(address(this));

        // Exact 49.5% USDT, 50.5% to swap → makes USDC look ~1% cheaper
        uint256 usdtPortion = usdtAmount * 495 / 1000; // 49.5%
        uint256 swapAmount = usdtAmount - usdtPortion; // 50.5%

        _swap(USDT, USDC, 100, swapAmount); // Swap more USDT → get more USDC → USDC looks abundant = "cheaper"

        uint256 usdtBal = IERC20(USDT).balanceOf(address(this));
        uint256 usdcBal = IERC20(USDC).balanceOf(address(this));

        INonfungiblePositionManager(POSITION_MANAGER).mint(
            INonfungiblePositionManager.MintParams({
                token0: USDT < USDC ? USDT : USDC,
                token1: USDT < USDC ? USDC : USDT,
                fee: 100,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: usdtBal,
                amount1Desired: usdcBal,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(0xdead), // Burn LP
                deadline: block.timestamp + 300
            })
        );

        emit Bootstrapped(amount);
    }

    function _infiniteLoop(uint256 amount) internal {
        uint256 maxIterations = 100; // Limit to prevent gas griefing
        uint256 iterations = 0;
        while (gasleft() > 200_000 && iterations < maxIterations) {
            // Buy cheap on skewed 0.01% pool, sell on 0.05% pool
            _swap(USDC, USDT, 100, amount / 2); // Buy USDT cheap on 0.01%
            _swap(USDT, USDC, 500, amount / 2); // Sell USDT on 0.05%
            iterations++;
        }
    }

    function _cexDexPegArb(uint256 amount) internal {
        // CEX-DEX peg arb: Assume price deviation, swap to correct
        _swap(USDC, USDT, 100, amount / 2);
        _swap(USDT, USDC, 100, amount / 2);
    }

    function _triangularStableArb(uint256 amount) internal {
        // Triangular arbitrage with multiple paths cycling through different token combinations
        ArbPath[6] memory paths = [
            ArbPath([USDC, USDT, WBTC, USDC], [uint24(100), uint24(3000), uint24(3000)]),
            ArbPath([USDC, LINK, WETH, USDC], [uint24(3000), uint24(3000), uint24(3000)]),
            ArbPath([USDC, UNI, WETH, USDC], [uint24(3000), uint24(3000), uint24(3000)]),
            ArbPath([USDC, AAVE_TOKEN, WETH, USDC], [uint24(3000), uint24(3000), uint24(3000)]),
            ArbPath([USDC, ARB, WETH, USDC], [uint24(3000), uint24(3000), uint24(3000)]),
            ArbPath([USDC, CRV, WETH, USDC], [uint24(3000), uint24(3000), uint24(3000)])
        ];

        uint256 pathIndex = block.timestamp % 6;
        ArbPath memory path = paths[pathIndex];

        uint256 amount1 = _swap(path.tokens[0], path.tokens[1], path.fees[0], amount);
        uint256 amount2 = _swap(path.tokens[1], path.tokens[2], path.fees[1], amount1);
        _swap(path.tokens[2], path.tokens[3], path.fees[2], amount2);
    }

    function _crossDexCurveArb(uint256 amount) internal {
        // Cross DEX: Swap on Uniswap, assume Curve for comparison
        _swap(USDC, WETH, 3000, amount / 2);
        _swap(WETH, USDC, 3000, amount / 2);
    }

    function _rwaPegArb(uint256 amount) internal {
        // RWA peg: Assume some RWA token, placeholder
        _swap(USDC, USDT, 100, amount);
    }

    function _basisTradeLoop(uint256 amount) internal {
        // Basis trade: Futures vs spot
        _swap(USDC, WETH, 3000, amount / 2);
        _swap(WETH, USDC, 3000, amount / 2);
    }

    function _btcLiquidArb(uint256 amount) internal {
        // BTC liquid: Borrow WBTC, swap to WETH, back
        _swap(WBTC, WETH, 3000, amount / 2);
        _swap(WETH, WBTC, 3000, amount / 2);
    }

    function _quadArb(uint256 amount) internal {
        // 4-way arbitrage: USDC -> USDT -> WETH -> WBTC -> USDC
        _swap(USDC, USDT, 100, amount);
        uint256 usdtBal = IERC20(USDT).balanceOf(address(this));
        _swap(USDT, WETH, 3000, usdtBal);
        uint256 wethBal = IERC20(WETH).balanceOf(address(this));
        _swap(WETH, WBTC, 3000, wethBal);
        uint256 wbtcBal = IERC20(WBTC).balanceOf(address(this));
        _swap(WBTC, USDC, 3000, wbtcBal);
    }

    function _swap(address tokenIn, address tokenOut, uint24 poolFee, uint256 amountIn) internal returns (uint256 amountOut) {
        uint256 amountOutMinimum = _calculateSlippage(tokenIn, tokenOut, amountIn);
        IERC20(tokenIn).approve(address(SKIM_ROUTER), amountIn);
        amountOut = SKIM_ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _calculateSlippage(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256) {
        AggregatorV3Interface oracleIn = _getOracle(tokenIn);
        AggregatorV3Interface oracleOut = _getOracle(tokenOut);
        if (address(oracleIn) == address(0) || address(oracleOut) == address(0)) {
            return 0; // No oracle, no slippage protection
        }
        // Get prices from oracles
        (, int256 priceIn,, uint256 updatedAtIn,) = oracleIn.latestRoundData();
        (, int256 priceOut,, uint256 updatedAtOut,) = oracleOut.latestRoundData();
        require(priceIn > 0 && priceOut > 0, "Invalid oracle prices");
        require(updatedAtIn >= block.timestamp - 3600 && updatedAtOut >= block.timestamp - 3600, "Stale oracle prices");

        // Adjust for decimals (oracles are 8 decimals, tokens vary)
        uint256 adjustedAmountIn = amountIn * (10 ** _getOracleDecimals(tokenIn));
        uint256 expectedOut = (adjustedAmountIn * uint256(priceIn)) / uint256(priceOut);
        expectedOut = expectedOut / (10 ** _getOracleDecimals(tokenOut));

        return expectedOut * 99 / 100; // 1% slippage tolerance
    }

    function _getOracle(address token) internal view returns (AggregatorV3Interface) {
        // if (token == USDC) return usdcOracle;
        if (token == USDT) return usdtOracle;
        if (token == WBTC) return wbtcOracle;
        if (token == WETH) return wethOracle;
        if (token == LINK) return linkOracle;
        if (token == UNI) return uniOracle;
        if (token == AAVE_TOKEN) return aaveOracle;
        if (token == ARB) return arbOracle;
        if (token == LDO) return ldoOracle;
        if (token == CRV) return crvOracle;
        if (token == PEPE) return pepeOracle;
        if (token == BONK) return bonkOracle;
        revert("Unsupported token");
    }

    function _getOracleDecimals(address token) internal view returns (uint8) {
        if (token == USDC || token == USDT) return 6; // USDC/USDT have 6 decimals
        if (token == WBTC) return 8; // WBTC has 8 decimals
        if (token == WETH || token == LINK || token == UNI || token == AAVE_TOKEN || token == ARB || token == LDO || token == CRV || token == PEPE) return 18; // Most tokens have 18 decimals
        if (token == BONK) return 5; // BONK has 5 decimals
        revert("Unsupported token");
    }

    function setTokenAddresses(
        address _usdt, address _usdc, address _wbtc, address _weth,
        address _gmx, address _magic, address _grail, address _rdnt, address _pendle,
        address _link, address _uni, address _aave, address _arb, address _ldo, address _crv, address _pepe, address _bonk
    ) external onlyOwner {
        USDT = _usdt;
        USDC = _usdc;
        WBTC = _wbtc;
        WETH = _weth;
        GMX = _gmx;
        MAGIC = _magic;
        GRAIL = _grail;
        RDNT = _rdnt;
        PENDLE = _pendle;
        LINK = _link;
        UNI = _uni;
        AAVE_TOKEN = _aave;
        ARB = _arb;
        LDO = _ldo;
        CRV = _crv;
        PEPE = _pepe;
        BONK = _bonk;
    }

    function setProtocolAddresses(address _aavePool, address _balancerVault, address _positionManager) external onlyOwner {
        AAVE_POOL = _aavePool;
        BALANCER_VAULT = _balancerVault;
        POSITION_MANAGER = _positionManager;
    }

    function setOracles(
        address _usdcOracle, address _usdtOracle, address _wbtcOracle, address _wethOracle,
        address _linkOracle, address _uniOracle, address _aaveOracle, address _arbOracle, address _ldoOracle, address _crvOracle
    ) external onlyOwner {
        // usdcOracle = AggregatorV3Interface(_usdcOracle);
        usdtOracle = AggregatorV3Interface(_usdtOracle);
        wbtcOracle = AggregatorV3Interface(_wbtcOracle);
        wethOracle = AggregatorV3Interface(_wethOracle);
        linkOracle = AggregatorV3Interface(_linkOracle);
        uniOracle = AggregatorV3Interface(_uniOracle);
        aaveOracle = AggregatorV3Interface(_aaveOracle);
        arbOracle = AggregatorV3Interface(_arbOracle);
        ldoOracle = AggregatorV3Interface(_ldoOracle);
        crvOracle = AggregatorV3Interface(_crvOracle);
        // PEPE and BONK have no oracles, so not settable
    }

    function setDevFee(uint256 _devFeeBP) external onlyOwner {
        require(_devFeeBP <= 50, "Max 0.5%");
        devFeeBP = _devFeeBP;
    }

    function setMaxTradeSize(uint256 _maxTradeSize) external onlyOwner {
        maxTradeSize = _maxTradeSize;
    }

    function setCooldownPeriod(uint256 _cooldownPeriod) external onlyOwner {
        cooldownPeriod = _cooldownPeriod;
    }

    function emergencyWithdraw(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}