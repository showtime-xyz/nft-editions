// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface IEdition {
    event EditionSold(uint256 price, address owner);
    event PriceChanged(uint256 amount);

    function burn(uint256 tokenId) external;

    function description() external view returns (string memory);

    function editionSize() external view returns (uint256);

    function getURIs()
        external
        view
        returns (
            string memory,
            string memory
        );

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) external;

    function maxSupply() external view returns (uint256);

    function mintEdition(address to) external returns (uint256);

    function mintEditions(address[] memory recipients)
        external
        returns (uint256);

    function purchase() external payable returns (uint256);

    function salePrice() external view returns (uint256);

    function setApprovedMinter(address minter, bool allowed) external;

    function setSalePrice(uint256 _salePrice) external;

    function totalSupply() external view returns (uint256);

    function updateEditionURLs(
        string memory _imageUrl,
        string memory _animationUrl
    ) external;

    function withdraw() external;
}
