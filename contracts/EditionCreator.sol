// SPDX-License-Identifier: GPL-3.0

/**

█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█

 */

pragma solidity ^0.8.6;

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {IEditionCreator} from "./interfaces/IEditionCreator.sol";
import {IEdition} from "./interfaces/IEdition.sol";

contract EditionCreator is IEditionCreator {
    /// Address for implementation of Edition to clone
    address public implementation;

    /// Initializes factory with address of implementation logic
    /// @param _implementation Edition logic implementation contract to clone
    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// Creates a new edition contract as a factory with a deterministic address
    /// Important: most of these fields can not be changed after calling
    /// @param _name Name of the edition contract
    /// @param _symbol Symbol of the edition contract
    /// @param _description Metadata: Description of the edition entry
    /// @param _animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param _imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param _editionSize Total size of the edition (number of possible editions)
    /// @param _royaltyBPS BPS amount of royalty
    /// @param _mintPeriodSeconds The amount of time in seconds after which editions can no longer be minted or purchased. Use 0 to have no expiration
    /// @return newContract The address of the created edition
    function createEdition(
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        string calldata _animationUrl,
        string calldata _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _mintPeriodSeconds
    ) external override returns (IEdition newContract) {
        bytes32 salt = keccak256(
            abi.encodePacked(
                msg.sender,
                _name,
                _symbol,
                _animationUrl,
                _imageUrl
            )
        );
        newContract = IEdition(
            ClonesUpgradeable.cloneDeterministic(implementation, salt)
        );

        try
            newContract.initialize(
                msg.sender,
                _name,
                _symbol,
                _description,
                _animationUrl,
                _imageUrl,
                _editionSize,
                _royaltyBPS,
                _mintPeriodSeconds
            )
        {} catch {
            // rethrow the problematic way until we have a better way
            // seehttps://github.com/ethereum/solidity/issues/12654
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        emit CreatedEdition(
            uint256(salt),
            msg.sender,
            _editionSize,
            address(newContract)
        );
    }

    /// Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return Edition Edition NFT contract
    function getEditionAtId(uint256 editionId)
        external
        view
        override
        returns (IEdition)
    {
        return
            IEdition(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(editionId),
                    address(this)
                )
            );
    }
}
