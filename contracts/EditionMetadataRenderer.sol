// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {EditionMetadataState} from "./EditionMetadataState.sol";

/// logic for rendering metadata associated with editions
contract EditionMetadataRenderer is EditionMetadataState {
    using StringsUpgradeable for uint256;

    /// Generate edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param name Name of NFT in metadata
    /// @param tokenId Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createTokenMetadata(
        string memory name,
        uint256 tokenId,
        uint256 editionSize
    ) internal view returns (string memory) {
        return
            toBase64DataUrl(
                createTokenMetadataJson(name, tokenId, editionSize)
            );
    }

    /// Function to create the metadata json string for the nft edition
    /// @param name Name of NFT in metadata
    /// @param tokenId Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createTokenMetadataJson(
        string memory name,
        uint256 tokenId,
        uint256 editionSize
    ) internal view returns (string memory) {
        string memory editionSizeText;
        if (editionSize > 0) {
            editionSizeText = string.concat("/", editionSize.toString());
        }

        string memory externalURLText = "";
        if (bytes(externalUrl).length > 0) {
            externalURLText = string.concat(
                '", "external_url": "',
                externalUrl
            );
        }

        string memory mediaData = tokenMediaData(
            imageUrl,
            animationUrl,
            tokenId
        );

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
                getPropertiesJson(),
                "}"
            );
    }

    /// Encodes contract level metadata into base64-data url format
    /// @dev see https://docs.opensea.io/docs/contract-level-metadata
    /// @dev borrowed from https://github.com/ourzora/zora-drops-contracts/blob/main/src/utils/NFTMetadataRenderer.sol
    function createContractMetadata(
        string memory name,
        uint256 royaltyBPS,
        address royaltyRecipient
    ) internal view returns (string memory) {
        string memory imageSpace = "";
        if (bytes(imageUrl).length > 0) {
            imageSpace = string.concat('", "image": "', imageUrl);
        }

        string memory externalURLSpace = "";
        if (bytes(externalUrl).length > 0) {
            externalURLSpace = string.concat(
                '", "external_link": "',
                externalUrl
            );
        }

        return
            toBase64DataUrl(
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
    function toBase64DataUrl(string memory json)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            );
    }

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
                'image": "',
                imageUrl,
                "?id=",
                tokenOfEdition.toString(),
                '",'
            );
        }

        if (hasAnimation) {
            buffer = string.concat(
                buffer,
                'animation_url": "',
                animationUrl,
                "?id=",
                tokenOfEdition.toString(),
                '",'
            );
        }

        return buffer;
    }

    /// Produces Enjin Metadata style simple properties
    /// @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md#erc-1155-metadata-uri-json-schema
    function getPropertiesJson() internal view returns (string memory) {
        uint256 length = namesOfStringProperties.length;
        if (length == 0) {
            return '"properties":{}';
        }

        string memory buffer = '"properties":{';

        unchecked {
            // `length - 1` can not underflow because of the `length == 0` check above
            uint256 lengthMinusOne = length - 1;

            for (uint256 i = 0; i < lengthMinusOne; ) {
                string storage _name = namesOfStringProperties[i];
                string storage _value = stringProperties[_name];

                buffer = string.concat(
                    buffer,
                    stringifyStringAttribute(_name, _value),
                    ","
                );

                // counter increment can not overflow
                ++i;
            }

            // add the last attribute without a trailing comma
            string storage lastName = namesOfStringProperties[lengthMinusOne];
            buffer = string.concat(
                buffer,
                stringifyStringAttribute(lastName, stringProperties[lastName])
            );
        }

        buffer = string.concat(buffer, "}");

        return buffer;
    }

    function stringifyStringAttribute(string storage name, string storage value)
        internal
        pure
        returns (string memory)
    {
        return string.concat('"', name, '":"', value, '"');
    }
}
