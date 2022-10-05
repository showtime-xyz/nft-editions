// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";

import {Edition} from "../contracts/Edition.sol";
import {EditionCreator} from "../contracts/EditionCreator.sol";

contract EditionMetadataTest is Test {
    EditionCreator editionCreator;
    Edition edition;
    uint256 constant tokenId = 1;

    function setUp() public {
        editionCreator = new EditionCreator(address(new Edition()));

        edition = Edition(
            address(
                editionCreator.createEdition(
                    "This is the name of my edition",
                    "TEST",
                    "This is a short description.",
                    "https://example.com/animation.mp4",
                    "https://example.com/image.png",
                    10, // editionSize
                    10_00, // royaltyBPS
                    0 // metadataGracePeriodSeconds
                )
            )
        );

        edition.mintEdition(address(0xdEaD));
    }

    // for gas usage only
    function testTokenURI() public {
        edition.tokenURI(tokenId);
    }

    // for gas usage only
    function testContractURI() public {
        edition.contractURI();
    }
}
