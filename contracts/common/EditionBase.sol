// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;


import {
    IERC2981Upgradeable,
    IERC165Upgradeable
} from "@openzeppelin-contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";

import {Initializable} from "SS2ERC721/common/utils/Initializable.sol";
import {OwnedInitializable} from "contracts/solmate-initializable/auth/OwnedInitializable.sol";

import {EditionMetadataRenderer} from "contracts/common/EditionMetadataRenderer.sol";
import {IEditionBase, EditionState} from "contracts/interfaces/IEditionBase.sol";
import "contracts/interfaces/Errors.sol";
import {OptionalOperatorFilterer} from "contracts/utils/OptionalOperatorFilterer.sol";

abstract contract EditionBase is
    IEditionBase,
    Initializable,
    EditionMetadataRenderer,
    OptionalOperatorFilterer,
    OwnedInitializable,
    IERC2981Upgradeable
{
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    EditionState internal state;

    // Addresses allowed to mint edition
    mapping(address => bool) allowedMinters;

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function __EditionBase_init(
        address _owner,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _mintPeriodSeconds
    ) internal onlyInitializing {
        // Set ownership to original sender of contract call
        __Owned_init(_owner);

        description = _description;
        animationUrl = _animationUrl;
        imageUrl = _imageUrl;

        uint64 _endOfMintPeriod;
        if (_mintPeriodSeconds > 0) {
            // overflows are not expected to happen for timestamps, and have no security implications
            unchecked {
                uint256 endOfMintPeriodUint256 = block.timestamp + _mintPeriodSeconds;
                _endOfMintPeriod = requireUint64(endOfMintPeriodUint256);
            }
        }

        state = EditionState({
            editionSize: requireUint64(_editionSize),
            endOfMintPeriod: _endOfMintPeriod,
            royaltyBPS: requireUint16(_royaltyBPS),
            salePriceTwei: 0,
            numberMinted: 0,
            __reserved: 0
        });
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function editionSize() public view returns (uint256) {
        return state.editionSize;
    }

    /// Returns the timestamp when the minting period ends, or 0 if there is no time limit
    function endOfMintPeriod() public view override returns (uint256) {
        return state.endOfMintPeriod;
    }

    /// Returns whether the edition can still be minted/purchased
    function isMintingEnded() public view override returns (bool) {
        uint256 _endOfMintPeriod = state.endOfMintPeriod;
        return _endOfMintPeriod > 0 && uint64(block.timestamp) > _endOfMintPeriod;
    }

    function isApprovedMinter(address minter) public view override returns (bool) {
        return allowedMinters[minter] || allowedMinters[address(0x0)] || owner == minter;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return state.numberMinted;
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
        return (owner, (_salePrice * state.royaltyBPS) / 10_000);
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual override(IERC165Upgradeable) returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x2a55205a || // ERC165 Interface ID for ERC2981
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                  CREATOR / COLLECTION OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev This withdraws ETH from the contract to the contract owner.
    function withdraw() external override onlyOwner {
        // No need for gas limit to trusted address.
        AddressUpgradeable.sendValue(payable(owner), address(this).balance);
    }

    /// @notice Sets the approved minting status of the given address.
    /// @param minter address to set approved minting status for
    /// @param allowed boolean if that address is allowed to mint
    /// @dev This requires that msg.sender is the owner of the given edition id.
    /// @dev If the ZeroAddress (address(0x0)) is set as a minter, anyone will be allowed to mint.
    /// @dev This setup is similar to setApprovalForAll in the ERC721 spec.
    function setApprovedMinter(address minter, bool allowed) public override onlyOwner {
        allowedMinters[minter] = allowed;
    }

    /// @notice Updates the external_url field in the metadata
    function setExternalUrl(string calldata _externalUrl) public override onlyOwner {
        emit ExternalUrlUpdated(externalUrl, _externalUrl);

        externalUrl = _externalUrl;
    }

    function setStringProperties(string[] calldata names, string[] calldata values) public override onlyOwner {
        uint256 length = names.length;
        if (values.length != length) {
            revert LengthMismatch();
        }

        namesOfStringProperties = names;
        for (uint256 i = 0; i < length;) {
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

    function setOperatorFilter(address operatorFilter) public override onlyOwner {
        _setOperatorFilter(operatorFilter);
    }

    function enableDefaultOperatorFilter() public override onlyOwner {
        _setOperatorFilter(CANONICAL_OPENSEA_SUBSCRIPTION);
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

    function requireUint16(uint256 value) internal pure returns (uint16) {
        if (value > uint256(type(uint16).max)) {
            revert IntegerOverflow(value);
        }
        return uint16(value);
    }

    function requireUint32(uint256 value) internal pure returns (uint32) {
        if (value > uint256(type(uint32).max)) {
            revert IntegerOverflow(value);
        }
        return uint32(value);
    }

    function requireUint64(uint256 value) internal pure returns (uint64) {
        if (value > uint256(type(uint64).max)) {
            revert IntegerOverflow(value);
        }
        return uint64(value);
    }
}
