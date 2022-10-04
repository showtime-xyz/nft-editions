// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// logic for rendering metadata associated with editions
library NFTMetadataRenderer {
    using StringsUpgradeable for uint256;

    /// Generate edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    /// @param tokenId Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataEdition(
        string memory name,
        string storage description,
        string storage imageUrl,
        string storage animationUrl,
        string storage externalUrl,
        uint256 tokenId,
        uint256 editionSize
    ) internal view returns (string memory) {
        string memory _tokenMediaData = tokenMediaData(
            imageUrl,
            animationUrl,
            tokenId
        );
        string memory json = createMetadataJSON(
            name,
            description,
            externalUrl,
            _tokenMediaData,
            tokenId,
            editionSize
        );
        return encodeMetadataJSON(json);
    }

    /// Function to create the metadata json string for the nft edition
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param mediaData Data for media to include in json object
    /// @param tokenId Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataJSON(
        string memory name,
        string storage description,
        string storage externalURL,
        string memory mediaData,
        uint256 tokenId,
        uint256 editionSize
    ) internal view returns (string memory) {
        string memory editionSizeText;
        if (editionSize > 0) {
            editionSizeText = string.concat(
                "/",
                editionSize.toString()
            );
        }

        string memory externalURLText = "";
        if (bytes(externalURL).length > 0) {
            externalURLText = string.concat('", "external_url": "', externalURL);
        }

        string memory tokenIdString = tokenId.toString();

        return
            string.concat(
                '{"name": "',
                name,
                " ",
                tokenIdString,
                editionSizeText,
                '", "',
                'description": "',
                description,
                externalURLText,
                '", "',
                mediaData,
                'properties": {"number": ',
                tokenIdString,
                ', "name": "',
                name,
                '"}}'
            );
    }

    /// Encodes contract level metadata into base64-data uri format
    /// @dev see https://docs.opensea.io/docs/contract-level-metadata
    /// @dev borrowed from https://github.com/ourzora/zora-drops-contracts/blob/main/src/utils/NFTMetadataRenderer.sol
    function encodeContractURIJSON(
        string memory name,
        string storage description,
        string storage imageURI,
        string storage externalURL,
        uint256 royaltyBPS,
        address royaltyRecipient
    ) internal view returns (string memory) {
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
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
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
    ) internal pure returns (string memory) {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        string memory buffer = "";

        if (hasImage) {
            buffer = string.concat(
                'image": "', imageUrl,
                "?id=", tokenOfEdition.toString(),
                '", "'
            );
        }

        if (hasAnimation) {
            buffer = string.concat(
                buffer,
                'animation_url": "', animationUrl,
                "?id=", tokenOfEdition.toString(),
                '", "'
            );
        }

        return buffer;
    }
}
