// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {LendingCore, MarketKey, Position} from "../src/LendingCore.sol";

contract LendingCoreTest is Test, Deployers {
    LendingCore lendingCore;

    Currency internal loanToken;
    Currency internal collateralToken;

    function setUp() public {
        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        deployMintAndApprove2Currencies();
        loanToken = currency0;
        collateralToken = currency1;

        address hookAddress = address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));

        vm.txGasPrice(10 gwei);
        deployCodeTo("LendingCore", abi.encode(manager, loanToken), hookAddress);
        lendingCore = LendingCore(hookAddress);

        (key,) = initPool(
            currency0,
            currency1,
            lendingCore,
            LPFeeLibrary.DYNAMIC_FEE_FLAG, // Set the `DYNAMIC_FEE_FLAG` in place of specifying a fixed fee
            60,
            SQRT_PRICE_1_1
        );

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_supply() public {
        MarketKey memory marketKey =
            MarketKey({collateralToken: Currency.unwrap(collateralToken), irm: address(this), lltv: 10000});
        bytes32 marketId = lendingCore.getMarketId(Currency.unwrap(collateralToken), address(this));

        IERC20(Currency.unwrap(loanToken)).approve(address(lendingCore), 100 ether);

        lendingCore.supply(marketKey, address(this), 100 ether);

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            lendingCore.positions(marketId, address(this));

        assertEq(supplyShares, 100 ether);
        assertEq(borrowShares, 0);
        assertEq(collateral, 0);
    }

    function test_withdraw() public {
        MarketKey memory marketKey =
            MarketKey({collateralToken: Currency.unwrap(collateralToken), irm: address(this), lltv: 10000});
        bytes32 marketId = lendingCore.getMarketId(Currency.unwrap(collateralToken), address(this));

        IERC20(Currency.unwrap(loanToken)).approve(address(lendingCore), 100 ether);
        lendingCore.supply(marketKey, address(this), 100 ether);

        // Act
        lendingCore.withdraw(marketKey, address(this), 100 ether);

        // Assert
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            lendingCore.positions(marketId, address(this));

        assertEq(supplyShares, 0);
        assertEq(borrowShares, 0);
        assertEq(collateral, 0);
    }
}
