// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {Currency} from "v4-core/types/Currency.sol";

import {LendingCore} from "../src/LendingCore.sol";

contract LendingCoreTest is Test, Deployers {
    LendingCore lendingCore;

    Currency internal loanToken;

    function setUp() public {
        loanToken = currency0;

        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        deployMintAndApprove2Currencies();

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
    }

    function test_initialize() public {}
}
