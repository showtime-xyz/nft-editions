// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Base64} from "base64-sol/base64.sol";
import {IPublicSharedMetadata} from "./interfaces/IPublicSharedMetadata.sol";

/// Shared NFT logic for rendering metadata associated with editions
/// @dev Can safely be used for generic base64Encode and numberToString functions
contract SharedNFTLogic is IPublicSharedMetadata {
    /// @param unencoded bytes to base64-encode
    function base64Encode(bytes memory unencoded)
        public
        pure
        override
        returns (string memory)
    {
        return Base64.encode(unencoded);
    }

    /// Proxy to openzeppelin's toString function
    /// @param value number to return as a string
    function numberToString(uint256 value)
        public
        pure
        override
        returns (string memory)
    {
        return StringsUpgradeable.toString(value);
    }

    /// Generate edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    /// @param tokenOfEdition Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataEdition(
        string calldata name,
        string calldata description,
        string calldata imageUrl,
        string calldata animationUrl,
        string calldata externalUrl,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) external pure returns (string memory) {
        string memory _tokenMediaData = tokenMediaData(
            imageUrl,
            animationUrl,
            tokenOfEdition
        );
        string memory json = createMetadataJSON(
            name,
            description,
            externalUrl,
            _tokenMediaData,
            tokenOfEdition,
            editionSize
        );
        return encodeMetadataJSON(json);
    }

    /// Function to create the metadata json string for the nft edition
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param mediaData Data for media to include in json object
    /// @param tokenOfEdition Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataJSON(
        string calldata name,
        string calldata description,
        string calldata externalURL,
        string memory mediaData,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) public pure returns (string memory) {
        string memory editionSizeText;
        if (editionSize > 0) {
            editionSizeText = string.concat(
                "/",
                numberToString(editionSize)
            );
        }

        string memory externalURLText = "";
        if (bytes(externalURL).length > 0) {
            externalURLText = string.concat('", "external_url": "', externalURL);
        }

        return
            string.concat(
                '{"name": "',
                name,
                " ",
                numberToString(tokenOfEdition),
                editionSizeText,
                '", "',
                'description": "',
                description,
                externalURLText,
                '", "',
                mediaData,
                'properties": {"number": ',
                numberToString(tokenOfEdition),
                ', "name": "',
                name,
                '"}}'
            );
    }

    /// Encodes contract level metadata into base64-data uri format
    /// @dev see https://docs.opensea.io/docs/contract-level-metadata
    /// @dev borrowed from https://github.com/ourzora/zora-drops-contracts/blob/main/src/utils/NFTMetadataRenderer.sol
    function encodeContractURIJSON(
        string calldata name,
        string calldata description,
        string calldata imageURI,
        string calldata externalURL,
        uint256 royaltyBPS,
        address royaltyRecipient
    ) public pure returns (string memory) {
        string memory imageSpace = "";
        if (bytes(imageURI).length > 0) {
            imageSpace = string.concat('", "image": "', imageURI);
        }

        string memory externalURLSpace = "";
        if (bytes(externalURL).length > 0) {
            externalURLSpace = string.concat('", "external_link": "', externalURL);
        }

        return
            encodeMetadataJSON(
                string.concat(
                    '{"name": "',
                    name,
                    '", "description": "',
                    description,
                    // this is for opensea since they don't respect ERC2981 right now
                    '", "seller_fee_basis_points": ',
                    StringsUpgradeable.toString(royaltyBPS),
                    ', "fee_recipient": "',
                    StringsUpgradeable.toHexString(royaltyRecipient),
                    imageSpace,
                    externalURLSpace,
                    '"}'
                )
            );
    }

    /// Encodes the argument json bytes into base64-data uri format
    /// @param json Raw json to base64 and turn into a data-uri
    function encodeMetadataJSON(string memory json)
        public
        pure
        override
        returns (string memory)
    {
        return string.concat(
            "data:application/json;base64,",
            base64Encode(bytes(json))
        );
    }

    /// Generates edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    function tokenMediaData(
        string memory imageUrl,
        string memory animationUrl,
        uint256 tokenOfEdition
    ) public pure returns (string memory) {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        string memory buffer = "";

        if (hasImage) {
            buffer = string.concat(
                'image": "', imageUrl,
                "?id=", numberToString(tokenOfEdition),
                '", "'
            );
        }

        if (hasAnimation) {
            buffer = string.concat(
                buffer,
                'animation_url": "', animationUrl,
                "?id=", numberToString(tokenOfEdition),
                '", "'
            );
        }

        return buffer;
    }
}
