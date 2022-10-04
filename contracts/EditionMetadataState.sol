// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

contract EditionMetadataState {
    string public description;

    // Media Urls
    // animation_url field in the metadata
    string public animationUrl;

    // Image in the metadata
    string public imageUrl;

    // URL that will appear below the asset's image on OpenSea
    string public externalUrl;

    string[] internal namesOfStringProperties;

    mapping(string => string) internal stringProperties;
}
