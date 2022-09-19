// SPDX-License-Identifier: GPL-3.0

/**

█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█

 */

pragma solidity ^0.8.6;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./SingleEditionMintable.sol";

contract SingleEditionMintableCreator {
    event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );

    /// Address for implementation of SingleEditionMintable to clone
    address public implementation;

    /// Initializes factory with address of implementation logic
    /// @param _implementation SingleEditionMintable logic implementation contract to clone
    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// Creates a new edition contract as a factory with a deterministic address
    /// Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param _name Name of the edition contract
    /// @param _symbol Symbol of the edition contract
    /// @param _description Metadata: Description of the edition entry
    /// @param _animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param _imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param _editionSize Total size of the edition (number of possible editions)
    /// @param _royaltyBPS BPS amount of royalty
    function createEdition(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) external returns (address newContract) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, _name, _symbol, _animationUrl, _imageUrl));
        newContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            salt
        );
        SingleEditionMintable(newContract).initialize(
            msg.sender,
            _name,
            _symbol,
            _description,
            _animationUrl,
            _imageUrl,
            _editionSize,
            _royaltyBPS
        );
        emit CreatedEdition(uint256(salt), msg.sender, _editionSize, newContract);
    }

    /// Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getEditionAtId(uint256 editionId)
        external
        view
        returns (SingleEditionMintable)
    {
        return
            SingleEditionMintable(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(editionId),
                    address(this)
                )
            );
    }
}
