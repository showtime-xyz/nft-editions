// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

struct StringAttribute {
    string name;
    string value;
}

interface IEdition {
    error BadAttribute(string name, string value);
    error IntegerOverflow(uint256 value);
    error LengthMismatch();
    error MintingEnded();
    error Unauthorized();
    error NotForSale();
    error PriceTooLow();
    error SoldOut();
    error WrongPrice();

    event EditionSold(uint256 price, address owner);
    event PriceChanged(uint256 amount);
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);

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

    function mintEdition(address to) external returns (uint256);

    function safeMintEdition(address to) external returns (uint256);

    function mintEditions(address[] memory recipients)
        external
        returns (uint256);

    function purchase() external payable returns (uint256);

    function salePrice() external view returns (uint256);

    function setApprovedMinter(address minter, bool allowed) external;

    function setSalePrice(uint256 _salePrice) external;

    function totalSupply() external view returns (uint256);

    function withdraw() external;
}
