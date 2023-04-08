// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

struct EditionState {
    // how many tokens have been minted (can not be more than editionSize)
    uint64 numberMinted;
    // reserved space to keep the state a uint256
    uint16 __reserved;
    // Price to mint in twei (1 twei = 1000 gwei), so the supported price range is 0.000001 to 4294.967295 ETH
    // To accept ERC20 or a different price range, use a specialized sales contract as the approved minter
    uint32 salePriceTwei;
    // Royalty amount in bps (uint16 is large enough to store 10000 bps)
    uint16 royaltyBPS;
    // the edition can be minted up to this timestamp in seconds -- 0 means no end date
    uint64 endOfMintPeriod;
    // Total size of edition that can be minted
    uint64 editionSize;
}

interface IEditionBase {
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);

    function contractURI() external view returns (string memory);

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

    function enableDefaultOperatorFilter() external;

    function endOfMintPeriod() external view returns (uint256);

    function isApprovedMinter(address minter) external view returns (bool);

    function isMintingEnded() external view returns (bool);

    function setApprovedMinter(address minter, bool allowed) external;

    function setExternalUrl(string calldata _externalUrl) external;

    function setOperatorFilter(address operatorFilter) external;

    function setStringProperties(string[] calldata names, string[] calldata values) external;

    function totalSupply() external view returns (uint256);

    function withdraw() external;
}
