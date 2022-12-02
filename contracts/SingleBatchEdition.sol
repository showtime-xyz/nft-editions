// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {OwnedInitializable} from "./solmate-initializable/auth/OwnedInitializable.sol";
import {SS2ERC721I} from "./solmate-initializable/tokens/SS2ERC721I.sol";

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
        // How many have been minted -- 0 before mint, final value after calling mintBatch()
        uint64 totalSupply;
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
            royaltyBPS: requireUint16(_royaltyBPS),
            totalSupply: 0
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

    function mintBatch(bytes calldata addresses)
        external
        override
        returns (uint256 lastTokenId)
    {
        lastTokenId = mintBatch(SSTORE2.write(addresses));
    }

    /// @param pointer An SSTORE2 pointer to a list of addresses to send the newly minted editions to, packed tightly
    /// @dev This mints multiple editions to the given list of addresses.
    function mintBatch(address pointer)
        public
        override
        returns (uint256 lastTokenId)
    {
        State memory _state = state;
        if (msg.sender != _state.minter) {
            revert Unauthorized();
        }

        if (_state.totalSupply > 0) {
            revert SoldOut();
        }

        lastTokenId = _mint(pointer);

        // can not realistically be bigger than 2^64
        _state.totalSupply = uint64(lastTokenId);
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
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalSupply() public view override returns (uint256) {
        return state.totalSupply;
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
        if (tokenId == 0 || tokenId > state.totalSupply) {
            revert InvalidArgument();
        }

        return createTokenMetadata(name, tokenId, state.totalSupply);
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
