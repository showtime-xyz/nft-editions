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

import {SharedNFTLogic} from "./SharedNFTLogic.sol";
import {IEdition} from "./interfaces/IEdition.sol";

/// @notice This is a smart contract for handling dynamic contract minting.
/// @dev This allows creators to mint a unique serial edition of the same media within a custom contract
/// @dev This is a fork of ZORA Editions for Showtime Drops
/// @author iain nash [ZORA Editions](https://github.com/ourzora/nft-editions)
/// @author karmacoma [Showtime Drops](https://github.com/showtime-xyz/nft-editions)
contract Edition is
    ERC721Upgradeable,
    IEdition,
    IERC2981Upgradeable,
    OwnableUpgradeable
{
    // metadata
    string public description;

    // Media Urls
    // animation_url field in the metadata
    string public animationUrl;

    // Image in the metadata
    string public imageUrl;

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

    // NFT rendering logic contract
    SharedNFTLogic private immutable sharedNFTLogic;

    // Global constructor for factory
    constructor(SharedNFTLogic _sharedNFTLogic) {
        sharedNFTLogic = _sharedNFTLogic;

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
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) public initializer override {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        // Set ownership to original sender of contract call
        transferOwnership(_owner);
        description = _description;
        animationUrl = _animationUrl;
        imageUrl = _imageUrl;
        editionSize = _editionSize;
        royaltyBPS = _royaltyBPS;
    }


    /*//////////////////////////////////////////////////////////////
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /// @dev Allows for updates of edition urls by the owner of the edition.
    function updateEditionURLs(
        string memory _imageUrl,
        string memory _animationUrl
    ) public onlyOwner {
        imageUrl = _imageUrl;
        animationUrl = _animationUrl;
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
    function mintEditions(address[] memory recipients)
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
    function _mintEditions(address[] memory recipients)
        internal
        returns (uint256 lastTokenId)
    {
        unchecked {
            uint256 n = recipients.length;
            uint256 startingTokenId = totalSupply + 1;
            lastTokenId = totalSupply + n;

            for (uint256 i = 0; i < n; ) {
                _safeMint(
                    recipients[i],
                    startingTokenId + i
                );

                ++i;
            }
        }

        // only update storage outside of the loop
        updateTotalSupply(lastTokenId);
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

    /// Returns the number of editions left to mint (max_uint256 when open edition)
    function maxSupply() public view override returns (uint256) {
        // Return max int if open edition
        if (editionSize == 0) {
            return type(uint256).max;
        }

        return editionSize;
    }

    /// @notice Get URIs for edition NFT
    /// @return imageUrl, animationUrl
    function getURIs()
        public
        view
        returns (
            string memory,
            string memory
        )
    {
        return (imageUrl, animationUrl);
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

    /// @notice Get URI for given token id
    /// @param tokenId token id to get uri for
    /// @return base64-encoded json metadata object
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "No token");

        return
            sharedNFTLogic.createMetadataEdition(
                name(),
                description,
                imageUrl,
                animationUrl,
                tokenId,
                editionSize
            );
    }

    function contractURI() public view returns (string memory) {
        return sharedNFTLogic.encodeContractURIJSON(
            name(),
            description,
            imageUrl,
            royaltyBPS,
            owner()
        );
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
