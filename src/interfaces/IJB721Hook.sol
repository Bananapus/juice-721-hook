// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";

interface IJB721Hook {
    function projectId() external view returns (uint256);

    function DIRECTORY() external view returns (IJBDirectory);
}
