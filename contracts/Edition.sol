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
    struct EditionState {
        // Total size of edition that can be minted
        // uint64 is still billions of billions, should be enough for everyone
        uint56 editionSize;
        // the edition can be minted up to this timestamp in seconds -- 0 means no end date
        // uint56 is enough for billions of years
        uint56 endOfMintPeriod;
        // Royalty amount in bps (uint16 is large enough to store 10000 bps)
        uint16 royaltyBPS;
        // how many tokens have been minted (can not be more than editionSize)
        uint56 numberMinted;
        // how many tokens have been burned (can not be more than numberMinted)
        uint56 numberBurned;
    }

    EditionState private state;

    // Addresses allowed to mint edition
    mapping(address => bool) allowedMinters;

    // Price for sale
    uint256 public salePrice;

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
    /// @param _imageUrl Image URL of the edition. Strongly encouraged to be used, but if necessary, only animation URL can be used. One of animation and image url need to exist in a edition to render the NFT.
    /// @param _animationUrl Animation URL of the edition. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
    /// @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
    /// @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    /// @param _mintPeriodSeconds The amount of time in seconds after which editions can no longer be minted or purchased. Use 0 to have no expiration
    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _mintPeriodSeconds
    ) public override initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();

        // Set ownership to original sender of contract call
        transferOwnership(_owner);

        description = _description;
        animationUrl = _animationUrl;
        imageUrl = _imageUrl;

        uint56 endOfMintPeriod;
        if (_mintPeriodSeconds > 0) {
            // overflows are not expected to happen for timestamps, and have no security implications
            unchecked {
                endOfMintPeriod = uint56(block.timestamp + _mintPeriodSeconds);
            }
        }

        state = EditionState({
            editionSize: uint56(_editionSize),
            endOfMintPeriod: endOfMintPeriod,
            royaltyBPS: uint16(_royaltyBPS),
            numberMinted: 0,
            numberBurned: 0
        });
    }

    /*//////////////////////////////////////////////////////////////
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier notEnded() {
        require(!isMintingEnded(), "minting has ended");
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
    function purchase() external payable notEnded returns (uint256) {
        require(salePrice > 0, "Not for sale");
        require(msg.value == salePrice, "Wrong price");

        emit EditionSold(salePrice, msg.sender);
        return _mintEdition(msg.sender);
    }

    /// @param to address to send the newly minted edition to
    /// @dev This mints one edition to the given address by an allowed minter on the edition instance.
    function mintEdition(address to)
        external
        override
        notEnded
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");

        return _mintEdition(to);
    }

    /// @param recipients list of addresses to send the newly minted editions to
    /// @dev This mints multiple editions to the given list of addresses.
    function mintEditions(address[] calldata recipients)
        external
        override
        notEnded
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        return _mintEditions(recipients);
    }

    /// @notice User burn function for token id
    /// @param tokenId Token ID to burn
    function burn(uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        unchecked {
            ++state.numberBurned;
        }
        _burn(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev guarantees that numberMinted can not exceed maxSupply
    function increaseNumberMinted(uint56 delta)
        private
        returns (uint56 newNumberMinted)
    {
        // up to the caller to ensure that delta is a reasonable value that can not cause overflows
        unchecked {
            newNumberMinted = state.numberMinted + delta;
        }

        require(newNumberMinted <= maxSupply(), "Sold out");
        state.numberMinted = newNumberMinted;
    }

    /// @dev Private function to mint without any access checks or supply checks
    /// @return tokenId the id of the newly minted token
    function _mintEdition(address recipient)
        internal
        returns (uint256 tokenId)
    {
        // can not realistically overflow
        unchecked {
            tokenId = increaseNumberMinted(1);
        }

        _safeMint(recipient, tokenId);
    }

    /// @dev Private function to batch mint without any access checks
    function _mintEditions(address[] calldata recipients)
        internal
        returns (uint256)
    {
        uint56 n = uint56(recipients.length);
        require(n > 0, "No recipients");

        unchecked {
            uint256 startingTokenId = state.numberMinted + 1;
            for (uint256 i = 0; i < n; ) {
                _safeMint(recipients[i], startingTokenId + i);
                ++i;
            }
        }

        // only update storage outside of the loop
        return increaseNumberMinted(n);
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

    function editionSize() external view override returns (uint256) {
        return state.editionSize;
    }

    /// Returns whether the edition can still be minted/purchased
    function isMintingEnded() public view returns (bool) {
        return
            state.endOfMintPeriod > 0 &&
            uint56(block.timestamp) > state.endOfMintPeriod;
    }

    function totalSupply() public view returns (uint256) {
        return state.numberMinted - state.numberBurned;
    }

    function numberCanMint() public view override returns (uint256) {
        if (isMintingEnded()) {
            return 0;
        }

        return maxSupply() - state.numberMinted;
    }

    function numberMinted() external view override returns (uint256) {
        return state.numberMinted;
    }

    function numberBurned() external view override returns (uint256) {
        return state.numberBurned;
    }

    /// Returns the number of editions left to mint (max_uint256 when open edition)
    function maxSupply() public view override returns (uint256) {
        // if the mint period is over, return the current total supply (which can not be increased anymore)
        if (isMintingEnded()) {
            return totalSupply();
        }

        // limited edition: return the fixed size
        if (state.editionSize != 0) {
            return state.editionSize;
        }

        // open edition
        return type(uint256).max;
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

        return createTokenMetadata(name(), tokenId, state.editionSize);
    }

    /// @notice Get the base64-encoded json metadata object for the edition
    function contractURI() public view returns (string memory) {
        return createContractMetadata(name(), state.royaltyBPS, owner());
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
        return (owner(), (_salePrice * state.royaltyBPS) / 10_000);
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
