// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {EditionMetadataState} from "./EditionMetadataState.sol";

/// logic for rendering metadata associated with editions
contract EditionMetadataRenderer is EditionMetadataState {
    using StringsUpgradeable for uint256;

    bytes1 constant BACKSLASH = bytes1(uint8(92));
    bytes1 constant BACKSPACE = bytes1(uint8(8));
    bytes1 constant CARRIAGE_RETURN = bytes1(uint8(13));
    bytes1 constant DOUBLE_QUOTE = bytes1(uint8(34));
    bytes1 constant FORM_FEED = bytes1(uint8(12));
    bytes1 constant FRONTSLASH = bytes1(uint8(47));
    bytes1 constant HORIZONTAL_TAB = bytes1(uint8(9));
    bytes1 constant NEWLINE = bytes1(uint8(10));

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
                '{"name":"',
                escapeJsonString(name),
                " ",
                tokenIdString,
                editionSizeText,
                '","',
                'description":"',
                escapeJsonString(description),
                externalURLText,
                '"',
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
                    '{"name":"',
                    escapeJsonString(name),
                    '","description":"',
                    escapeJsonString(description),
                    // this is for opensea since they don't respect ERC2981 right now
                    '","seller_fee_basis_points":',
                    StringsUpgradeable.toString(royaltyBPS),
                    ',"fee_recipient":"',
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
                ',"image":"',
                imageUrl,
                "?id=",
                tokenOfEdition.toString(),
                '"'
            );
        }

        if (hasAnimation) {
            buffer = string.concat(
                buffer,
                ',"animation_url":"',
                animationUrl,
                "?id=",
                tokenOfEdition.toString(),
                '"'
            );
        }

        return buffer;
    }

    /// Produces Enjin Metadata style simple properties
    /// @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md#erc-1155-metadata-uri-json-schema
    function getPropertiesJson() internal view returns (string memory) {
        uint256 length = namesOfStringProperties.length;
        if (length == 0) {
            return ',"properties":{}';
        }

        string memory buffer = ',"properties":{';

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

    /**
     * @dev Escapes any characters that required by JSON to be escaped.
     */
    function escapeJsonString(string memory value)
        private
        pure
        returns (string memory str)
    {
        bytes memory b = bytes(value);
        bool foundEscapeChars;

        unchecked {
            uint256 length = b.length;
            for (uint256 i; i < length; i++) {
                if (b[i] == BACKSLASH) {
                    foundEscapeChars = true;
                    break;
                } else if (b[i] == DOUBLE_QUOTE) {
                    foundEscapeChars = true;
                    break;
                    // } else if (b[i] == FRONTSLASH) {
                    //     foundEscapeChars = true;
                    //     break;
                } else if (b[i] == HORIZONTAL_TAB) {
                    foundEscapeChars = true;
                    break;
                } else if (b[i] == FORM_FEED) {
                    foundEscapeChars = true;
                    break;
                } else if (b[i] == NEWLINE) {
                    foundEscapeChars = true;
                    break;
                } else if (b[i] == CARRIAGE_RETURN) {
                    foundEscapeChars = true;
                    break;
                } else if (b[i] == BACKSPACE) {
                    foundEscapeChars = true;
                    break;
                }
            }

            if (!foundEscapeChars) {
                return value;
            }

            for (uint256 i; i < length; i++) {
                if (b[i] == BACKSLASH) {
                    str = string(abi.encodePacked(str, "\\\\"));
                } else if (b[i] == DOUBLE_QUOTE) {
                    str = string(abi.encodePacked(str, '\\"'));
                    // } else if (b[i] == FRONTSLASH) {
                    //     str = string(abi.encodePacked(str, "\\/"));
                } else if (b[i] == HORIZONTAL_TAB) {
                    str = string(abi.encodePacked(str, "\\t"));
                } else if (b[i] == FORM_FEED) {
                    str = string(abi.encodePacked(str, "\\f"));
                } else if (b[i] == NEWLINE) {
                    str = string(abi.encodePacked(str, "\\n"));
                } else if (b[i] == CARRIAGE_RETURN) {
                    str = string(abi.encodePacked(str, "\\r"));
                } else if (b[i] == BACKSPACE) {
                    str = string(abi.encodePacked(str, "\\b"));
                } else {
                    str = string(abi.encodePacked(str, b[i]));
                }
            }
        }

        return str;
    }
}
