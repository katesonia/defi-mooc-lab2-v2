//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

// ----------------------INTERFACE------------------------------

// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool

interface ILendingPool {
    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (DataTypes.ReserveData memory);

    function getReservesList() external view returns (address[] memory);

    /**
     * @dev Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     **/
    function getUserConfiguration(address user)
        external
        view
        returns (DataTypes.UserConfigurationMap memory);
}

// UniswapV2

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20
interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    /**
     * Allows _spender to withdraw from your account multiple times, up to the _value amount.
     * If this function is called again it overwrites the current allowance with _value.
     * Lets msg.sender set their allowance for a spender.
     **/
    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    /**
     * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
     * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
     * Lets msg.sender send pool tokens to an address.
     **/
    function transfer(address to, uint256 value) external returns (bool);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee
interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
interface IUniswapV2Pair {
    /**
     * Swaps tokens. For regular swaps, data.length must be 0.
     * Also see [Flash Swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps).
     **/
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    /**
     * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * See Pricing[https://docs.uniswap.org/protocol/V2/concepts/advanced-topics/pricing].
     * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
     **/
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// ----------------------LIBRARIES-----------------------------------

library DataTypes {
    // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }
}

library UserConfiguration {
    /**
     * @dev Used to validate if a user has been using the reserve for borrowing
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing, false otherwise
     **/
    function isBorrowing(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        require(reserveIndex < 128, "INVALID INDEX! has to be less than 128.");
        return (self.data >> (reserveIndex * 2)) & 1 != 0;
    }

    /**
     * @dev Used to validate if a user has been using the reserve as collateral
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve as collateral, false otherwise
     **/
    function isUsingAsCollateral(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        require(reserveIndex < 128, "INVALID INDEX! has to be less than 128.");
        return (self.data >> (reserveIndex * 2 + 1)) & 1 != 0;
    }
}

// ----------------------IMPLEMENTATION------------------------------

contract LiquidationOperator is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    address private USER = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;
    address private AAVE_LENDING_POOL =
        0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address private UNI_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    // WBTC < WETH < USDT
    address private USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    using UserConfiguration for DataTypes.UserConfigurationMap;

    // END TODO

    // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    // Return user debt for asset.
    function getUserDebt(address user, address asset)
        private
        view
        returns (uint256 stableDebt, uint256 variableDebt)
    {
        DataTypes.ReserveData memory reserve = ILendingPool(AAVE_LENDING_POOL)
            .getReserveData(asset);
        stableDebt = IERC20(reserve.stableDebtTokenAddress).balanceOf(user);
        variableDebt = IERC20(reserve.variableDebtTokenAddress).balanceOf(user);
    }

    function printUserPosition(address user) private view {
        ILendingPool pool = ILendingPool(AAVE_LENDING_POOL);
        // Get reserves and user config.
        address[] memory reserves = pool.getReservesList();
        DataTypes.UserConfigurationMap memory userConfig = pool
            .getUserConfiguration(user);

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserve = pool.getReserveData(
                reserves[i]
            );
            // if use as debt.
            if (userConfig.isBorrowing(reserve.id)) {
                uint256 stableDebt = IERC20(reserve.stableDebtTokenAddress)
                    .balanceOf(user);
                uint256 variableDebt = IERC20(reserve.variableDebtTokenAddress)
                    .balanceOf(user);
                string memory symbol = IERC20(reserves[i]).symbol();
                uint256 decimals = IERC20(reserves[i]).decimals();
                console.log(
                    "user debt %s: stableDebt %s, variableDebt %s",
                    symbol,
                    stableDebt / 10**decimals,
                    variableDebt / 10**decimals
                );
            }
            // if use as collateral.
            if (userConfig.isUsingAsCollateral(reserve.id)) {
                uint256 collateral = IERC20(reserve.aTokenAddress).balanceOf(
                    user
                );
                string memory symbol = IERC20(reserves[i]).symbol();
                uint256 decimals = IERC20(reserves[i]).decimals();
                console.log(
                    "user collateral %s: %s",
                    symbol,
                    collateral / 10**decimals
                );
            }
            // skip.
        }
    }

    constructor() {
        // TODO: (optional) initialize your contract
        //   *** Your code here ***
        // END TODO
    }

    // TODO: add a `receive` function so that you can withdraw your WETH
    //   *** Your code here ***
    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // TODO: implement your liquidation logic
        // 0. security checks and initializing variables
        uint256 healthFactor;
        // 1. get the target user account data & make sure it is liquidatable
        (, , , , , healthFactor) = ILendingPool(AAVE_LENDING_POOL)
            .getUserAccountData(USER);
        require(healthFactor < 1e18, "user cannot be liquidated.");
        // uint256 stableDebt;
        // uint256 variableDebt;
        // (stableDebt, variableDebt) = getUserDebt(USER, USDT);
        // console.log(
        //     "stableDebt %s, variableDebt %s",
        //     stableDebt / 1e6,
        //     variableDebt / 1e6
        // );
        printUserPosition(USER);

        // 2. call flash swap to liquidate the target user
        // based on https://etherscan.io/tx/0xac7df37a43fab1b130318bbb761861b8357650db2e2c6493b73d6da3d9581077
        // we know that the target user borrowed USDT with WBTC as collateral
        // we should borrow USDT, liquidate the target user and get the WBTC, then swap WBTC to repay uniswap
        // (please feel free to develop other workflows as long as they liquidate the target user successfully)
        //    *** Your code here ***
        // 3. Convert the profit into ETH and send back to sender
        //    *** Your code here ***
        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external override {
        // TODO: implement your liquidation logic
        // 2.0. security checks and initializing variables
        //    *** Your code here ***
        // 2.1 liquidate the target user
        //    *** Your code here ***
        // 2.2 swap WBTC for other things or repay directly
        //    *** Your code here ***
        // 2.3 repay
        //    *** Your code here ***
        // END TODO
    }
}
