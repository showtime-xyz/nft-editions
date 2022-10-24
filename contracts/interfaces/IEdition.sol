// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

struct StringAttribute {
    string name;
    string value;
}

interface IEdition {
    event EditionSold(uint256 price, address owner);
    event PriceChanged(uint256 amount);
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);

    function burn(uint256 tokenId) external;

    function editionSize() external view returns (uint256);

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _mintPeriodSeconds
    ) external;

    function maxSupply() external view returns (uint256);

    function mintEdition(address to) external returns (uint256);

    function mintEditions(address[] memory recipients)
        external
        returns (uint256);

    function numberCanMint() external view returns (uint256);

    function purchase() external payable returns (uint256);

    function salePrice() external view returns (uint256);

    function setApprovedMinter(address minter, bool allowed) external;

    function setSalePrice(uint256 _salePrice) external;

    function totalSupply() external view returns (uint256);

    function withdraw() external;
}
