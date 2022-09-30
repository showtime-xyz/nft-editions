// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IEdition {
    event EditionSold(uint256 price, address owner);
    event PriceChanged(uint256 amount);

    function animationUrl() external view returns (string memory);

    function burn(uint256 tokenId) external;

    function description() external view returns (string memory);

    function editionSize() external view returns (uint256);

    function imageUrl() external view returns (string memory);

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 metadataGracePeriod
    ) external;

    function maxSupply() external view returns (uint256);

    function mintEdition(address to) external returns (uint256);

    function mintEditions(address[] memory recipients)
        external
        returns (uint256);

    function purchase() external payable returns (uint256);

    function salePrice() external view returns (uint256);

    function setAnimationUrl(string calldata animationUrl) external;

    function setApprovedMinter(address minter, bool allowed) external;

    function setDescription(string calldata description) external;

    function setImageUrl(string calldata imageUrl) external;

    function setSalePrice(uint256 _salePrice) external;

    function totalSupply() external view returns (uint256);


    function withdraw() external;
}
