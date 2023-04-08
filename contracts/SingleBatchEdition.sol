// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {SS2ERC721I} from "SS2ERC721/SS2ERC721I.sol";
import {ERC721} from "SS2ERC721/SS2ERC721.sol";

import {EditionBase} from "contracts/common/EditionBase.sol";
import {IBatchEdition} from "contracts/interfaces/IBatchEdition.sol";

import "./interfaces/Errors.sol";

/// @notice This is a smart contract optimized for minting editions in one single batch
/// @dev This allows creators to mint a unique serial edition of the same media within a custom contract
contract SingleBatchEdition is
    EditionBase,
    SS2ERC721I,
    IBatchEdition
{
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
        __SS2ERC721_init(_name, _symbol);
        __EditionBase_init(_owner, _description, _animationUrl, _imageUrl, _editionSize, _royaltyBPS, _mintPeriodSeconds);
    }


    /*//////////////////////////////////////////////////////////////
                   COLLECTOR / TOKEN OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @param addresses A tightly packed and sorted list of at most 1228 addresses to mint to
    function mintBatch(bytes calldata addresses) external override returns (uint256 lastTokenId) {
        lastTokenId = _mint(addresses);

        // run the validations at the end, once we know the number minted
        // this makes reverts more expensive, but the happy path cheaper
        _mintChecks(lastTokenId);
    }

    /// @param pointer An SSTORE2 pointer to a list of addresses to send the newly minted editions to, packed tightly
    function mintBatch(address pointer) public override returns (uint256 lastTokenId) {
        if (!isApprovedMinter(msg.sender)) {
            revert Unauthorized();
        }

        lastTokenId = _mint(pointer);

        // run the validations at the end, once we know the number minted
        // this makes reverts more expensive, but the happy path cheaper
        _mintChecks(lastTokenId);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR FILTERER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }


    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev stateless version of isMintingEnded
    function enforceTimeLimit(uint64 _endOfMintPeriod) internal view {
        if (_endOfMintPeriod > 0 && uint64(block.timestamp) > _endOfMintPeriod) {
            revert TimeLimitReached();
        }
    }

    function enforceSupplyLimit(uint64 _editionSize, uint64 _numberMinted) internal pure {
        if (_editionSize > 0 && _numberMinted > _editionSize) {
            revert SoldOut();
        }
    }

    /// @dev Validates the supply and time limits for minting with a single SLOAD and SSTORE
    /// @dev this is based on _mintPreFlightChecks in Edition
    /// @dev does not enforce the sale price, as the mint functions are not payable
    function _mintChecks(uint256 quantity) internal returns (uint64 _tokenId) {
        if (!isApprovedMinter(msg.sender)) {
            revert Unauthorized();
        }

        uint256 _state;
        uint256 _postState;
        uint64 _editionSize;
        uint64 _endOfMintPeriod;

        assembly ("memory-safe") {
            _state := sload(state.slot)
            _editionSize := shr(192, _state)
            _endOfMintPeriod := shr(128, _state)

            // can not realistically overflow
            // the fields in EditionState are ordered so that incrementing state increments numberMinted
            _postState := add(_state, quantity)

            // perform the addition only once and extract numberMinted + 1 from _postState
            _tokenId := and(_postState, 0xffffffffffffffff)
        }

        enforceSupplyLimit(_editionSize, _tokenId);
        enforceTimeLimit(_endOfMintPeriod);

        // update storage
        assembly ("memory-safe") {
            sstore(state.slot, _postState)
        }

        return _tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                           SS2ERC721 GOODIES
    //////////////////////////////////////////////////////////////*/

    /// Returns the SSTORE2 pointer for this edition if minted, or 0 if not minted
    function getPrimaryOwnersPointer(uint256) public view override returns (address) {
        return _ownersPrimaryPointer;
    }

    /// Returns true if the given address is one of the primary owners of this edition
    /// A primary owner is defined as an address in the SSTORE2 array of primary owners
    /// used during the initial mint of the edition.
    /// Note that this does not look up if the address is still a current owner (they
    /// may have transferred or burned their token)
    function isPrimaryOwner(address tokenOwner) public view override returns (bool) {
        return _balanceOfPrimary(tokenOwner) != 0;
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the base64-encoded json metadata for a token
    /// @param tokenId the token id to get the metadata for
    /// @return base64-encoded json metadata object
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // reverts if token does not exist
        ownerOf(tokenId);

        return createTokenMetadata(name, tokenId, editionSize());
    }

    /// @notice Get the base64-encoded json metadata object for the edition
    function contractURI() public view override returns (string memory) {
        return createContractMetadata(name, state.royaltyBPS, owner);
    }

    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, EditionBase) returns (bool) {
        return EditionBase.supportsInterface(interfaceId);
    }
}
