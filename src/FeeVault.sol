// SPDX-License-Identifier: None
pragma solidity ^0.8.25;

import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';
import {IWNative} from './interfaces/IWNative.sol';

contract FeeVault {
    using SafeERC20 for IERC20;
    // struct
    struct FeeInfo {
        address admin;
        address treasury;
        uint96 feeBps;
    }

    // constants
    uint96 private constant BPS = 10_000;
    // immutable
    address public immutable WNATIVE;
    // storage
    FeeInfo[] private _feeInfos; // feeInfos for each party

    /// @notice sum of feeBps in infos must be 100%
    /// @param infos Array of FeeInfo
    constructor(address wNative, FeeInfo[] memory infos) {
        WNATIVE = wNative;
        // note: deploy new contract to change feeBps
        uint totalFee;
        for (uint i; i < infos.length; ++i) {
            require(infos[i].admin != address(0), 'FeeVault: invalid admin');
            require(infos[i].treasury != address(0), 'FeeVault: invalid treasury');
            _feeInfos.push(infos[i]);
            totalFee += infos[i].feeBps;
        }
        // ensure total fee is 100%
        require(totalFee == BPS, 'FeeVault: invalid fee');
    }

    /// @param index Index of feeInfo in _feeInfos
    modifier onlyAdmin(uint index) {
        require(_feeInfos[index].admin == msg.sender, 'FeeVault: not admin');
        _;
    }

    /// @notice Claim fees for tokens (balance of must be > 0)
    /// @param tokens Array of tokens to claim fees
    function claim(address[] calldata tokens) external {
        for (uint i; i < tokens.length; ++i) {
            _distributeFees(tokens[i]);
        }
    }

    /// @notice Distribute fees to each treasury
    /// @param token Token address
    function _distributeFees(address token) internal {
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance != 0, 'FeeVault: no balance');
        uint length = _feeInfos.length;
        for (uint i; i < length; ++i) {
            // note: we can ignore rounding dust here
            // since token's balance will continue to grow
            uint fee = (balance * _feeInfos[i].feeBps) / BPS;
            if (fee > 0) {
                IERC20(token).safeTransfer(_feeInfos[i].treasury, fee);
            }
        }
    }

    /// @notice Set new admin for feeInfo
    /// @param index Index of feeInfo in _feeInfos
    /// @param newAdmin New admin address
    function setAdmin(uint index, address newAdmin) external onlyAdmin(index) {
        require(newAdmin != address(0), 'FeeVault: invalid admin');
        _feeInfos[index].admin = newAdmin;
    }

    /// @notice Set new treasury for feeInfo
    /// @param index Index of feeInfo in _feeInfos
    /// @param newTreasury New treasury address
    function setTreasury(uint index, address newTreasury) external onlyAdmin(index) {
        require(newTreasury != address(0), 'FeeVault: invalid treasury');
        _feeInfos[index].treasury = newTreasury;
    }

    /// @notice return all feeInfos
    function getFeeInfos() external view returns (FeeInfo[] memory infos) {
        infos = new FeeInfo[](_feeInfos.length);
        for (uint i; i < infos.length; ++i) {
            infos[i] = _feeInfos[i];
        }
    }

    receive() external payable {
        // send msg.value to wNative for wrapping
        IWNative(WNATIVE).deposit{value: msg.value}();
    }
}
