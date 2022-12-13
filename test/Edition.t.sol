// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";

import {IERC721ReceiverUpgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import {Base64} from "contracts/utils/Base64.sol";
import {Edition} from "contracts/Edition.sol";
import {EditionCreator, IEdition} from "contracts/EditionCreator.sol";
import {LibString} from "contracts/utils/LibString.sol";

import "contracts/interfaces/Errors.sol";



function newIntegerOverflow(uint256 value) pure returns (bytes memory) {
    return abi.encodeWithSelector(IntegerOverflow.selector, value);
}

contract EditionTest is Test {
    event Initialized();
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    uint256 constant INTENSE_LENGTH = 100_000;

    EditionCreator editionCreator;
    Edition editionImpl;
    Edition edition;
    Edition editionToEscape;
    Edition editionIntense;

    uint256 tokenId;

    address editionOwner;
    address bob = makeAddr("bob");

    function createEdition(string memory name, string memory description)
        internal
        returns (Edition _edition)
    {
        vm.startPrank(editionOwner);
        _edition = Edition(
            address(
                editionCreator.createEdition(
                    name,
                    "TEST",
                    description,
                    "https://example.com/animation.mp4",
                    "https://example.com/image.png",
                    0xcccccccccccccc, // editionSize
                    0xaaaa, // royaltyBPS
                    0xbbbbbbbbbbbbbb // mintPeriodSeconds
                )
            )
        );

        // so that we can mint from this without having to call prank all the time
        _edition.setApprovedMinter(address(this), true);
        vm.stopPrank();

        return _edition;
    }

    function setUp() public {
        editionOwner = makeAddr("editionOwner");
        editionImpl = new Edition();
        editionCreator = new EditionCreator(address(editionImpl));

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

        tokenId = edition.mint(address(0xdEaD));
        editionToEscape.mint(address(0xdEaD));
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

    function testCreateEditionWithEmptyDescription() public {
        Edition editionEmptyDescription = createEdition("name", "");
        assertEq(editionEmptyDescription.description(), "");
    }

    /// @dev for gas snapshot
    function testMintSingle() public {
        edition.mint(address(0xdEaD));
    }

    /// @dev for gas snapshot
    function testFailMintSingle() public {
        edition.mint(address(0));
    }

    /// @dev for gas snapshot
    function testMintBatch1() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0xdEaD);
        edition.mintBatch(recipients);
    }

    /// @dev for gas snapshot
    function testMintBatch3() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        edition.mintBatch(recipients);
    }

    /// @dev for gas snapshot
    function testMintBatch10() public {
        address[] memory recipients = new address[](10);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        recipients[3] = address(0xdEaD);
        recipients[4] = address(0xdEaD);
        recipients[5] = address(0xdEaD);
        recipients[6] = address(0xdEaD);
        recipients[7] = address(0xdEaD);
        recipients[8] = address(0xdEaD);
        recipients[9] = address(0xdEaD);
        edition.mintBatch(recipients);
    }
}
