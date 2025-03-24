// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

struct MarketKey {
    address collateralToken;
    address irm;
    uint256 lltv;
}

struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares; // TODO: not work now
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares; // TODO: not work now
    uint128 lastUpdate;
    uint128 fee;
}

struct Position {
    uint256 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
}

event Supply(bytes32 marketId, address onBehalf, uint256 assetsAmount);

event Withdraw(bytes32 marketId, address onBehalf, uint256 sharesAmount);

contract LendingCore is BaseHook {
    address public loanToken;

    mapping(bytes32 id => Market) public markets;

    mapping(bytes32 marketId => mapping(address user => Position position)) public positions;

    constructor(IPoolManager _poolManager, address _loanToken) BaseHook(_poolManager) {
        loanToken = _loanToken;
    }

    // Required override function for BaseHook to let the PoolManager know which hooks are implemented
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function supply(MarketKey memory market, address onBehalf, uint256 assetsAmount) public {
        bytes32 id = _getMarketId(market.collateralToken, market.irm);
        uint256 shares = _getShares(assetsAmount, markets[id].totalSupplyAssets, markets[id].totalSupplyShares);
        markets[id].totalSupplyAssets += uint128(assetsAmount);
        markets[id].totalSupplyShares += uint128(shares);

        positions[id][onBehalf].supplyShares += shares;

        emit Supply(id, onBehalf, assetsAmount);

        IERC20(market.collateralToken).transferFrom(onBehalf, address(this), assetsAmount);
    }

    function withdraw(MarketKey memory market, address onBehalf, uint256 shares) public {
        bytes32 id = _getMarketId(market.collateralToken, market.irm);
        uint256 assetsAmount = _getAssets(shares, markets[id].totalSupplyAssets, markets[id].totalSupplyShares);

        markets[id].totalSupplyAssets -= uint128(assetsAmount);
        markets[id].totalSupplyShares -= uint128(shares);

        positions[id][onBehalf].supplyShares -= shares;

        emit Withdraw(id, onBehalf, shares);

        IERC20(market.collateralToken).transfer(onBehalf, assetsAmount);
    }

    function _afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        // TODO: internal oracle (for _afterSwap)
        return (this.afterSwap.selector, 0);
    }

    function createMarket(MarketKey memory market) public {
        bytes32 id = _getMarketId(market.collateralToken, market.irm);
        markets[id].lastUpdate = uint128(block.timestamp);
    }

    function _getMarketId(address collateralToken, address interestRateModel) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(collateralToken, interestRateModel));
    }

    function _getShares(uint256 assets, uint256 totalSupplyAssets, uint256 totalSupplyShares)
        internal
        pure
        returns (uint256)
    {
        return (assets * totalSupplyShares) / totalSupplyAssets;
    }

    function _getAssets(uint256 shares, uint256 totalSupplyAssets, uint256 totalSupplyShares)
        internal
        pure
        returns (uint256)
    {
        return (shares * totalSupplyAssets) / totalSupplyShares;
    }

    function _interestRateModel() internal {}
}
