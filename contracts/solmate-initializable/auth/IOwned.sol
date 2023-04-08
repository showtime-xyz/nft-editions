// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

interface IOwned {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;
}
