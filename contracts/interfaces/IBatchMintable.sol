// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IBatchMintable {
    function getPrimaryOwnersPointer(uint256 index) external view returns(address);

    function isPrimaryOwner(address tokenOwner) external view returns(bool);

    function mintBatch(bytes calldata addresses) external returns (uint256);

    function mintBatch(address pointer) external returns (uint256);
}
