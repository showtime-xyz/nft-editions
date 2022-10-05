// SPDX-License-Identifier: GPL-3.0

/**

█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█

 */

pragma solidity ^0.8.6;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {EditionMetadataRenderer} from "./EditionMetadataRenderer.sol";
import {IEdition, StringAttribute} from "./interfaces/IEdition.sol";

/// @notice This is a smart contract for handling dynamic contract minting.
/// @dev This allows creators to mint a unique serial edition of the same media within a custom contract
/// @dev This is a fork of ZORA Editions for Showtime Drops
/// @author iain nash [ZORA Editions](https://github.com/ourzora/nft-editions)
/// @author karmacoma [Showtime Drops](https://github.com/showtime-xyz/nft-editions)
contract Edition is
    EditionMetadataRenderer,
    ERC721Upgradeable,
    IEdition,
    IERC2981Upgradeable,
    OwnableUpgradeable
{
    // Total size of edition that can be minted
    uint256 public editionSize;

    // How many tokens have been currently minted
    uint256 public totalSupply;

    // Royalty amount in bps
    uint256 royaltyBPS;

    // Addresses allowed to mint edition
    mapping(address => bool) allowedMinters;

    // Price for sale
    uint256 public salePrice;

    // the metadata can be update by the owner up to this timestamp
    uint256 internal endOfMetadataGracePeriod;

    // Global constructor for factory
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to create a new edition. Can only be called by the allowed creator
    ///         Sets the only allowed minter to the address that creates/owns the edition.
    ///         This can be re-assigned or updated later
    /// @param _owner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    /// @param _name Name of edition, used in the title as "$NAME NUMBER/TOTAL"
    /// @param _symbol Symbol of the new token contract
    /// @param _description Description of edition, used in the description field of the NFT
    /// @param _imageUrl Image URL of the edition. Strongly encouraged to be used, if necessary, only animation URL can be used. One of animation and image url need to exist in a edition to render the NFT.
    /// @param _animationUrl Animation URL of the edition. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
    /// @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
    /// @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    /// @param metadataGracePeriodSeconds The amount of time in seconds that the metadata can be updated after the contract is deployed, 0 to have no grace period
    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 metadataGracePeriodSeconds
    ) public override initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        // Set ownership to original sender of contract call
        transferOwnership(_owner);
        description = _description;
        animationUrl = _animationUrl;
        imageUrl = _imageUrl;
        editionSize = _editionSize;
        royaltyBPS = _royaltyBPS;

        if (metadataGracePeriodSeconds > 0) {
            endOfMetadataGracePeriod =
                block.timestamp +
                metadataGracePeriodSeconds;
        }
    }

    /*//////////////////////////////////////////////////////////////
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier notFrozen() {
        require(!isMetadataFrozen(), "metadata is frozen");
        _;
    }

    /// @notice This sets a simple ETH sales price
    /// Setting a sales price allows users to mint the edition until it sells out.
    /// For more granular sales, use an external sales contract.
    /// @param _salePrice sale price in wei, 0 to disable sales
    function setSalePrice(uint256 _salePrice) external onlyOwner {
        salePrice = _salePrice;
        emit PriceChanged(salePrice);
    }

    /// @dev This withdraws ETH from the contract to the contract owner.
    function withdraw() external onlyOwner {
        // No need for gas limit to trusted address.
        AddressUpgradeable.sendValue(payable(owner()), address(this).balance);
    }

    /// @notice Sets the approved minting status of the given address.
    /// @param minter address to set approved minting status for
    /// @param allowed boolean if that address is allowed to mint
    /// @dev This requires that msg.sender is the owner of the given edition id.
    /// @dev If the ZeroAddress (address(0x0)) is set as a minter, anyone will be allowed to mint.
    /// @dev This setup is similar to setApprovalForAll in the ERC721 spec.
    function setApprovedMinter(address minter, bool allowed) public onlyOwner {
        allowedMinters[minter] = allowed;
    }

    function setDescription(string calldata _description)
        public
        override
        onlyOwner
        notFrozen
    {
        // log the current description
        emit DescriptionUpdated(description, _description);

        // switch to the new one
        description = _description;
    }

    /// @dev Allows the owner to update the animation url for the edition
    function setAnimationUrl(string calldata _animationUrl)
        public
        override
        onlyOwner
        notFrozen
    {
        // log the current animation url
        emit AnimationUrlUpdated(animationUrl, _animationUrl);

        // switch to the new one
        animationUrl = _animationUrl;
    }

    /// @dev Allows the owner to update the image url for the edition
    function setImageUrl(string calldata _imageUrl)
        public
        override
        onlyOwner
        notFrozen
    {
        // log the current image url
        emit ImageUrlUpdated(imageUrl, _imageUrl);

        // switch to the new one
        imageUrl = _imageUrl;
    }

    /// @notice Updates the external_url field in the metadata
    /// @notice can be updated by the owner regardless of the grace period
    function setExternalUrl(string calldata _externalUrl) public onlyOwner {
        // log the current external url
        emit ExternalUrlUpdated(externalUrl, _externalUrl);

        externalUrl = _externalUrl;
    }

    function setStringProperties(
        string[] calldata names,
        string[] calldata values
    ) public onlyOwner {
        require(names.length == values.length, "length mismatch");
        uint256 length = names.length;

        namesOfStringProperties = names;
        for (uint256 i = 0; i < length; ) {
            string calldata name = names[i];
            string calldata value = values[i];
            if (bytes(name).length == 0 || bytes(value).length == 0) {
                revert("bad attribute");
            }

            emit PropertyUpdated(name, stringProperties[name], value);

            stringProperties[name] = value;

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                   COLLECTOR / TOKEN OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev This allows the user to purchase a single edition at the configured sale price
    function purchase() external payable returns (uint256) {
        require(salePrice > 0, "Not for sale");
        require(msg.value == salePrice, "Wrong price");

        emit EditionSold(salePrice, msg.sender);
        return _mintEdition(msg.sender);
    }

    /// @param to address to send the newly minted edition to
    /// @dev This mints one edition to the given address by an allowed minter on the edition instance.
    function mintEdition(address to) external override returns (uint256) {
        require(_isAllowedToMint(), "Needs to be an allowed minter");

        return _mintEdition(to);
    }

    /// @param recipients list of addresses to send the newly minted editions to
    /// @dev This mints multiple editions to the given list of addresses.
    function mintEditions(address[] calldata recipients)
        external
        override
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        return _mintEditions(recipients);
    }

    /// @notice User burn function for token id
    /// @param tokenId Token ID to burn
    function burn(uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        _burn(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev guarantees that totalSupply can not exceed maxSupply
    function updateTotalSupply(uint256 _totalSupply) private {
        require(_totalSupply <= maxSupply(), "Sold out");
        totalSupply = _totalSupply;
    }

    /// @dev Private function to mint without any access checks or supply checks
    /// @return tokenId the id of the newly minted token
    function _mintEdition(address recipient)
        internal
        returns (uint256 tokenId)
    {
        // can not realistically overflow
        unchecked {
            updateTotalSupply(totalSupply + 1);
        }

        tokenId = totalSupply;
        _safeMint(recipient, tokenId);
    }

    /// @dev Private function to batch mint without any access checks
    function _mintEditions(address[] calldata recipients)
        internal
        returns (uint256)
    {
        uint256 n = recipients.length;
        require(n > 0, "No recipients");

        uint256 tokenId;

        unchecked {
            for (uint256 i = 0; i < n; ) {
                tokenId = totalSupply + i + 1;
                _safeMint(recipients[i], tokenId);

                ++i;
            }
        }

        // only update storage outside of the loop
        updateTotalSupply(tokenId);
        return tokenId;
    }

    /// @dev This helper function checks if the msg.sender is allowed to mint
    function _isAllowedToMint() internal view returns (bool) {
        if (owner() == msg.sender) {
            return true;
        }
        if (allowedMinters[address(0x0)]) {
            return true;
        }
        return allowedMinters[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Returns whether metadata (image URL, animation URL, description) can be updated
    /// The external URL can be updated at any time
    function isMetadataFrozen() public view returns (bool) {
        return block.timestamp > endOfMetadataGracePeriod;
    }

    /// Returns the number of editions left to mint (max_uint256 when open edition)
    function maxSupply() public view override returns (uint256) {
        // Return max int if open edition
        if (editionSize == 0) {
            return type(uint256).max;
        }

        return editionSize;
    }

    /// @notice Get the base64-encoded json metadata for a token
    /// @param tokenId the token id to get the metadata for
    /// @return base64-encoded json metadata object
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "No token");

        return createTokenMetadata(name(), tokenId, editionSize);
    }

    /// @notice Get the base64-encoded json metadata object for the edition
    function contractURI() public view returns (string memory) {
        return createContractMetadata(name(), royaltyBPS, owner());
    }

    /// @notice Get royalty information for token
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (owner() == address(0x0)) {
            return (owner(), 0);
        }
        return (owner(), (_salePrice * royaltyBPS) / 10_000);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            ERC721Upgradeable.supportsInterface(interfaceId);
    }
}
