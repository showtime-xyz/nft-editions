// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { IEdition } from "./IEdition.sol";

interface IEditionCreator {
    event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );

    /// @return The address of the created edition
    function createEdition(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        string memory _imageUrl,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        uint256 _metadataGracePeriodSeconds
    ) external returns (IEdition);

    /// Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getEditionAtId(uint256 editionId) external view returns (IEdition);
}
