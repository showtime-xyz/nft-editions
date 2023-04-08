// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {ERC721, ERC721I} from "SS2ERC721/ERC721I.sol";

import {EditionBase} from "./common/EditionBase.sol";
import {IEdition} from "./interfaces/IEdition.sol";

import "./interfaces/Errors.sol";

/// @notice This is a smart contract for handling dynamic contract minting.
/// @dev This allows creators to mint a unique serial edition of the same media within a custom contract
/// @dev This is a fork of ZORA Editions for Showtime Drops
/// @author karmacoma [Showtime Drops](https://github.com/showtime-xyz/nft-editions)
/// @author iain nash [ZORA Editions](https://github.com/ourzora/nft-editions)
contract Edition is EditionBase, ERC721I, IEdition {
    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

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

        __EditionBase_init(
            _owner, _description, _animationUrl, _imageUrl, _editionSize, _royaltyBPS, _mintPeriodSeconds
        );
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
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice This sets a simple ETH sales price
    /// Setting a sales price allows users to mint the edition until it sells out.
    /// The supported price range is 0.000001 to 4294.967295 ETH (or relevant chain gas token)
    /// For more granular sales, use an external sales contract.
    /// @param _salePriceWei sale price in wei, 0 to disable sales
    function setSalePrice(uint256 _salePriceWei) external override onlyOwner {
        // convert to milli-eth internally
        uint32 salePriceTwei = requireUint32(_salePriceWei / 1e12);
        if (salePriceTwei == 0 && _salePriceWei > 0) {
            revert PriceTooLow();
        }

        state.salePriceTwei = salePriceTwei;
        emit PriceChanged(_salePriceWei);
    }

    /*//////////////////////////////////////////////////////////////
                   COLLECTOR / TOKEN OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @param to address to send the newly minted edition to
    /// @dev This mints one edition to the given address by an allowed minter
    function mint(address to) external payable override returns (uint256 tokenId) {
        tokenId = _mintPreFlightChecks(1);
        _mint(to, tokenId);
    }

    function safeMint(address to) external payable override returns (uint256 tokenId) {
        tokenId = _mintPreFlightChecks(1);
        _safeMint(to, tokenId);
    }

    /// @param recipients list of addresses to send the newly minted editions to
    /// @dev This mints multiple editions to the given list of addresses.
    function mintBatch(address[] calldata recipients) external payable override returns (uint256 lastTokenId) {
        uint64 n = uint64(recipients.length);
        if (n == 0) {
            revert InvalidArgument();
        }

        lastTokenId = _mintPreFlightChecks(n);

        unchecked {
            uint256 firstTokenId = lastTokenId + 1 - n;
            for (uint256 i = 0; i < n;) {
                _safeMint(recipients[i], firstTokenId + i);
                ++i;
            }
        }
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

    function enforceSalePrice(uint256 _salePriceTwei, uint256 quantity) internal view {
        unchecked {
            if (msg.value != quantity * _salePriceTwei * 1e12) {
                revert WrongPrice();
            }
        }
    }

    /// @dev Validates the supply and time limits for minting with a single SLOAD and SSTORE
    function _mintPreFlightChecks(uint256 quantity) internal returns (uint64 _tokenId) {
        if (!isApprovedMinter(msg.sender)) {
            revert Unauthorized();
        }

        uint256 _state;
        uint256 _postState;
        uint64 _editionSize;
        uint64 _endOfMintPeriod;
        uint32 _salePriceTwei;

        assembly ("memory-safe") {
            _state := sload(state.slot)
            _editionSize := shr(192, _state)
            _endOfMintPeriod := shr(128, _state)
            _salePriceTwei := shr(80, _state)

            // can not realistically overflow
            // the fields in EditionState are ordered so that incrementing state increments numberMinted
            _postState := add(_state, quantity)

            // perform the addition only once and extract numberMinted + 1 from _postState
            _tokenId := and(_postState, 0xffffffffffffffff)
        }

        enforceSupplyLimit(_editionSize, _tokenId);
        enforceTimeLimit(_endOfMintPeriod);
        enforceSalePrice(_salePriceTwei, quantity);

        // update storage
        assembly ("memory-safe") {
            sstore(state.slot, _postState)
        }

        return _tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the sale price in wei
    function salePrice() public view override returns (uint256) {
        unchecked {
            // can not overflow
            return uint256(state.salePriceTwei) * 1e12;
        }
    }

    /// @notice Get the base64-encoded json metadata for a token
    /// @param tokenId the token id to get the metadata for
    /// @return base64-encoded json metadata object
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // reverts if token does not exist
        ownerOf(tokenId);

        return createTokenMetadata(name, tokenId, state.editionSize);
    }

    /// @notice Get the base64-encoded json metadata object for the edition
    function contractURI() public view override returns (string memory) {
        return createContractMetadata(name, state.royaltyBPS, owner);
    }

    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, EditionBase) returns (bool) {
        return EditionBase.supportsInterface(interfaceId);
    }
}
