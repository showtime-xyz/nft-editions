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
    /// @param _name Name of the edition
    /// @param _symbol Symbol of the edition
    /// @param _description Description of the edition
    /// @param _animationUrl Link to video for each token in this edition, ideally "ipfs://..."
    /// @param _imageUrl Link to an image for each token in this edition, ideally "ipfs://..."
    /// @param _editionSize Set to a number greater than 0 for a limited edition, 0 for an open edition
    /// @param _royaltyBPS Royalty amount in basis points (1/100th of a percent) to be paid to the owner of the edition
    /// @param _mintPeriodSeconds Set to a number greater than 0 for a time-limited edition, 0 for no time limit. The mint period starts when the edition is created.
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
