// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

interface ISingleBatchEdition {
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);

    function contractURI() external view returns (string memory);

    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _royaltyBPS,
        address _minter
    ) external;

    function mintBatch(bytes calldata addresses) external returns (uint256);

    function setExternalUrl(string calldata _externalUrl) external;

    function setStringProperties(
        string[] calldata names,
        string[] calldata values
    ) external;

    function totalSupply() external view returns (uint256);

    function withdraw() external;
}
