// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @title Universal store of current contract time for testing environments.
 */
contract Timer {

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }
}