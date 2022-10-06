// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";

import {Edition} from "../contracts/Edition.sol";
import {EditionCreator} from "../contracts/EditionCreator.sol";

contract EditionMetadataTest is Test {
    EditionCreator editionCreator;
    Edition edition;
    Edition editionToEscape;
    uint256 constant tokenId = 1;

    function createEdition(string memory name, string memory description)
        internal
        returns (Edition)
    {
        return
            Edition(
                address(
                    editionCreator.createEdition(
                        name,
                        "TEST",
                        description,
                        "https://example.com/animation.mp4",
                        "https://example.com/image.png",
                        10, // editionSize
                        10_00, // royaltyBPS
                        0 // metadataGracePeriodSeconds
                    )
                )
            );
    }

    function setUp() public {
        editionCreator = new EditionCreator(address(new Edition()));

        edition = createEdition(
            "This is the name of my edition",
            "This is a short description."
        );

        editionToEscape = createEdition(
            'My "edition" is \t very special!\n',
            'My "description" is also \t \\very\\ special!\r\n'
        );

        edition.mintEdition(address(0xdEaD));
        editionToEscape.mintEdition(address(0xdEaD));
    }

    // for gas usage only
    function testTokenURI() public {
        edition.tokenURI(tokenId);
    }

    // for gas usage only
    function testContractURI() public {
        edition.contractURI();
    }

    function testTokenURIEscaped() public {
        editionToEscape.tokenURI(tokenId);
    }

    function testContractURIEscaped() public {
        editionToEscape.contractURI();
    }
}
