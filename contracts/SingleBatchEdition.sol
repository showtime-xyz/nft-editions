// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin-contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";

import {OwnedInitializable} from "./solmate-initializable/auth/OwnedInitializable.sol";
import {SS2ERC721I} from "SS2ERC721/SS2ERC721I.sol";
import {ERC721} from "SS2ERC721/SS2ERC721.sol";

import {EditionMetadataRenderer} from "./EditionMetadataRenderer.sol";
import {ISingleBatchEdition} from "./interfaces/ISingleBatchEdition.sol";

import "./interfaces/Errors.sol";

/// @notice This is a smart contract optimized for minting editions in one single batch
/// @dev This allows creators to mint a unique serial edition of the same media within a custom contract
contract SingleBatchEdition is
    EditionMetadataRenderer,
    SS2ERC721I,
    ISingleBatchEdition,
    IERC2981Upgradeable,
    OwnedInitializable
{
    struct State {
        // Immutable address that is allowed to mint
        address minter;
        // Immutable royalty amount in bps (uint16 is large enough to store 10000 bps)
        uint16 royaltyBPS;
    }

    State private state;

    /// @notice Function to create a new edition. Can only be called by the allowed creator
    ///         Sets the only allowed minter to the address that creates/owns the edition.
    ///         This can be re-assigned or updated later
    /// @param _owner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    /// @param _name Name of edition, used in the title as "$NAME NUMBER/TOTAL"
    /// @param _symbol Symbol of the new token contract
    /// @param _description Description of edition, used in the description field of the NFT
    /// @param _imageUrl Image URL of the edition. Strongly encouraged to be used, but if necessary, only animation URL can be used. One of animation and image url need to exist in a edition to render the NFT.
    /// @param _animationUrl Animation URL of the edition. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
    /// @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _royaltyBPS,
        address _minter
    ) public override initializer {
        __SS2ERC721_init(_name, _symbol);

        // Set ownership to original sender of contract call
        __Owned_init(_owner);

        description = _description;
        animationUrl = _animationUrl;
        imageUrl = _imageUrl;

        state = State({
            minter: _minter,
            royaltyBPS: requireUint16(_royaltyBPS)
        });
    }

    /*//////////////////////////////////////////////////////////////
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev This withdraws ETH from the contract to the contract owner.
    function withdraw() external override onlyOwner {
        // No need for gas limit to trusted address.
        AddressUpgradeable.sendValue(payable(owner), address(this).balance);
    }

    /// @notice Updates the external_url field in the metadata
    function setExternalUrl(string calldata _externalUrl)
        public
        override
        onlyOwner
    {
        emit ExternalUrlUpdated(externalUrl, _externalUrl);

        externalUrl = _externalUrl;
    }

    function setStringProperties(
        string[] calldata names,
        string[] calldata values
    ) public override onlyOwner {
        uint256 length = names.length;
        if (values.length != length) {
            revert LengthMismatch();
        }

        namesOfStringProperties = names;
        for (uint256 i = 0; i < length; ) {
            string calldata name = names[i];
            string calldata value = values[i];
            if (bytes(name).length == 0 || bytes(value).length == 0) {
                revert BadAttribute(name, value);
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

    function revertIfNotAuthorizedMinter() internal view {
        State memory _state = state;
        if (msg.sender != _state.minter) {
            revert Unauthorized();
        }
    }

    function mintBatch(bytes calldata addresses)
        external
        override
        returns (uint256 lastTokenId)
    {
        revertIfNotAuthorizedMinter();
        lastTokenId = _mint(addresses);
    }

    /// @param pointer An SSTORE2 pointer to a list of addresses to send the newly minted editions to, packed tightly
    /// @dev This mints multiple editions to the given list of addresses.
    function mintBatch(address pointer)
        public
        override
        returns (uint256 lastTokenId)
    {
        revertIfNotAuthorizedMinter();
        lastTokenId = _mint(pointer);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function requireUint16(uint256 value) internal pure returns (uint16) {
        if (value > uint256(type(uint16).max)) {
            revert IntegerOverflow(value);
        }
        return uint16(value);
    }

    /*//////////////////////////////////////////////////////////////
                           SS2ERC721 GOODIES
    //////////////////////////////////////////////////////////////*/

    /// Returns the SSTORE2 pointer for this edition if minted, or 0 if not minted
    function getPrimaryOwnersPointer() public view override returns(address) {
        return _ownersPrimaryPointer;
    }

    /// Returns true if the given address is one of the primary owners of this edition
    /// A primary owner is defined as an address in the SSTORE2 array of primary owners
    /// used during the initial mint of the edition.
    /// Note that this does not look up if the address is still a current owner (they
    /// may have transferred or burned their token)
    function isPrimaryOwner(address tokenOwner) public view override returns(bool) {
        return _balanceOfPrimary(tokenOwner) != 0;
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalSupply() public view override returns (uint256) {
        return _ownersPrimaryLength();
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
        uint256 _totalSupply = totalSupply();
        if (tokenId == 0 || tokenId > _totalSupply) {
            revert InvalidArgument();
        }

        return createTokenMetadata(name, tokenId, _totalSupply);
    }

    /// @notice Get the base64-encoded json metadata object for the edition
    function contractURI() public view override returns (string memory) {
        return createContractMetadata(name, state.royaltyBPS, owner);
    }

    /// @notice Get royalty information for token
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (owner == address(0x0)) {
            return (address(0x0), 0);
        }
        return (owner, (_salePrice * state.royaltyBPS) / 10000);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165Upgradeable)
        returns (bool)
    {
        return
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            ERC721.supportsInterface(interfaceId);
    }
}
