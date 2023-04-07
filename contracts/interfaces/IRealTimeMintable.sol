// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IRealTimeMintable {
    event PriceChanged(uint256 amount);

    function mint(address to) external payable returns (uint256);

    function safeMint(address to) external payable returns (uint256);

    function mintBatch(address[] memory recipients) external payable returns (uint256);

    function salePrice() external view returns (uint256);

    function setSalePrice(uint256 _salePrice) external;
}
