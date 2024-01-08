// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Permission IDs for `JBPermissions`.
library JB721PermissionIds {
    // 1-20 - `JBPermissionIds`
    // 21 - `JBHandlePermissionIds`
    uint256 public constant ADJUST_TIERS = 22;
    uint256 public constant UPDATE_METADATA = 23;
    uint256 public constant MINT = 24;
}
