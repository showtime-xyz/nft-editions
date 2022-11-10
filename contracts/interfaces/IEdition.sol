// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

struct StringAttribute {
    string name;
    string value;
}

interface IEdition {
    error BadAttribute(string name, string value);
    error IntegerOverflow(uint256 value);
    error InvalidArgument();
    error LengthMismatch();
    error NotForSale();
    error PriceTooLow();
    error SoldOut();
    error TimeLimitReached();
    error Unauthorized();
    error WrongPrice();

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

    function mint(address to) external payable returns (uint256);

    function safeMint(address to) external payable returns (uint256);

    function mintBatch(address[] memory recipients)
        external
        payable
        returns (uint256);

    function salePrice() external view returns (uint256);

    function setApprovedMinter(address minter, bool allowed) external;

    function setSalePrice(uint256 _salePrice) external;

    function totalSupply() external view returns (uint256);

    function withdraw() external;
}
