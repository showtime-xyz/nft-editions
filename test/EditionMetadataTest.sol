// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";

import {Edition} from "../contracts/Edition.sol";
import {EditionCreator} from "../contracts/EditionCreator.sol";
import {Base64} from "../contracts/utils/Base64.sol";
import {LibString} from "../contracts/utils/LibString.sol";

contract EditionMetadataTest is Test {
    uint256 constant INTENSE_LENGTH = 100_000;

    EditionCreator editionCreator;
    Edition edition;
    Edition editionToEscape;
    Edition editionIntense;

    uint256 tokenId;

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
                        0 // mintPeriodSeconds
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

        string memory intenseDescription = LibString.repeat(
            "\\",
            INTENSE_LENGTH
        );
        editionIntense = createEdition(
            "This edition goes to 11",
            intenseDescription
        );

        tokenId = edition.mintEdition(address(0xdEaD));
        editionToEscape.mintEdition(address(0xdEaD));
    }

    // for gas usage only
    function testTokenURI() public view {
        edition.tokenURI(tokenId);
    }

    // for gas usage only
    function testContractURI() public view {
        edition.contractURI();
    }

    function testTokenURIEscaped() public view {
        editionToEscape.tokenURI(tokenId);
    }

    function testContractURIEscaped() public view {
        editionToEscape.contractURI();
    }

    function testLongEscapeDoubleQuotes() public {
        string memory input = LibString.repeat('"', INTENSE_LENGTH);
        string memory expected = LibString.repeat('\\"', INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function testLongEscapeControlChar() public {
        string memory input = LibString.repeat(
            string(abi.encodePacked(bytes1(0))),
            INTENSE_LENGTH
        );
        string memory expected = LibString.repeat("\\u0000", INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function testEncodeContractURIIntenseDescription() public {
        string memory contractURI = editionIntense.contractURI();
        string memory base64Slice = LibString.slice(
            contractURI,
            29, // length of 'data:application/json;base64,'
            bytes(contractURI).length
        );

        // console2.log("base64Slice:", base64Slice);
        string memory base64Decoded = string(Base64.decode(base64Slice));
        // console2.log("base64Decoded:", base64Decoded);
        string memory description = abi.decode(
            stdJson.parseRaw(base64Decoded, ".description"),
            (string)
        );
        // console2.log("description:", description);

        assertEq(description, LibString.repeat("\\", INTENSE_LENGTH));
    }

    function testBurnDecreasesTotalSupply() public {
        address bob = makeAddr("bob");
        edition.setApprovedMinter(bob, true);
        vm.startPrank(bob);
        uint256 bobsTokenId = edition.mintEdition(bob);

        uint256 totalSupplyBefore = edition.totalSupply();

        edition.burn(bobsTokenId);
        assertEq(edition.totalSupply(), totalSupplyBefore - 1);
        vm.stopPrank();
    }

    function testCreateEditionWithEmptyDescription() public {
        Edition editionEmptyDescription = createEdition("name", "");
        assertEq(editionEmptyDescription.description(), "");
    }

    function testCreateEditionWithNoRoyalties() public {
        Edition editionNoRoyalties = Edition(
            address(
                editionCreator.createEdition(
                    "name",
                    "TEST",
                    "description",
                    "https://example.com/animation.mp4",
                    "https://example.com/image.png",
                    10, // editionSize
                    0, // royaltyBPS
                    0 // mintPeriodSeconds
                )
            )
        );

        (, uint256 royaltyAmount) = editionNoRoyalties.royaltyInfo(1, 100);
        assertEq(royaltyAmount, 0);
    }
}
