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

contract UnsuspectingContract {}

contract ERC721AwareContract is IERC721ReceiverUpgradeable {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

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

    UnsuspectingContract unsuspectingContract = new UnsuspectingContract();
    ERC721AwareContract erc721AwareContract = new ERC721AwareContract();

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

    function testMintEditionCanMintToUnsuspectingContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(unsuspectingContract),
            /* whatever */
            0
        );

        edition.mint(address(unsuspectingContract));
    }

    function testSafeMintEditionCanNotMintToUnsuspectingContracts() public {
        // the "UNSAFE_RECIPIENT" error does not bubble up to the caller
        vm.expectRevert();
        edition.safeMint(address(unsuspectingContract));
    }

    function testSafeMintEditionCanMintToAwareContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(erc721AwareContract),
            /* whatever */
            0
        );

        edition.mint(address(erc721AwareContract));
    }

    function testEditionSizeOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        vm.expectRevert(newIntegerOverflow(tooBig));

        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            tooBig, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );
    }

    function testMintPeriodOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        vm.expectRevert(newIntegerOverflow(tooBig + block.timestamp));

        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            0, // royaltyBPS
            tooBig // mintPeriodSeconds
        );
    }

    function testRoyaltiesOverflow() public {
        uint256 tooBig = uint256(type(uint16).max) + 1;
        vm.expectRevert(newIntegerOverflow(tooBig));

        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            tooBig, // royaltyBPS
            0 // mintPeriodSeconds
        );
    }

    function testCreateDuplicate() public {
        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );

        vm.expectRevert("ERC1167: create2 failed");
        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );
    }

    function testBatchSellOut() public {
        IEdition tightEdition = editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            3, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );

        // can mint everything in one go
        address[] memory recipients = new address[](3);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        tightEdition.mintBatch(recipients);

        // can not mint anymore after that
        vm.expectRevert(SoldOut.selector);
        tightEdition.mint(address(0xdEaD));

        vm.expectRevert(SoldOut.selector);
        tightEdition.mintBatch(recipients);

        address[] memory soloRecipient = new address[](1);
        soloRecipient[0] = address(0xdEaD);
        vm.expectRevert(SoldOut.selector);
        tightEdition.mintBatch(soloRecipient);
    }

    function testCanNotMintBatchBiggerThanEditionSize() public {
        IEdition tightEdition = editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            3, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );

        address[] memory recipients = new address[](4);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        recipients[3] = address(0xdEaD);

        vm.expectRevert(SoldOut.selector);
        tightEdition.mintBatch(recipients);
    }

    function testSetSalePriceSmallest() public {
        uint256 smallestPriceWei = 0.001 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(smallestPriceWei);
        assertEq(edition.salePrice(), smallestPriceWei);
    }

    function testSetSalePriceLargest() public {
        uint256 largestPriceWei = 4294.967295 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(largestPriceWei);
        assertEq(edition.salePrice(), largestPriceWei);
    }

    function testSetSalePriceUnderflow() public {
        uint256 tooSmall = 1 wei;
        vm.prank(editionOwner);
        vm.expectRevert(abi.encodeWithSignature("PriceTooLow()"));
        edition.setSalePrice(tooSmall);
    }

    function testSetSalePriceOverflow() public {
        uint256 tooBig = 4294.967296 ether;
        vm.prank(editionOwner);
        vm.expectRevert(newIntegerOverflow(0x100000000));
        edition.setSalePrice(tooBig);
    }

    function testFreeMintRefusesEth() public {
        // setup
        vm.prank(editionOwner);
        edition.setSalePrice(0);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint{value: 1 ether}(bob);

        // bob can not safeMint with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint{value: 1 ether}(bob);

        // bob can not mintBatch with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        edition.mintBatch{value: 1 ether}(recipients);
    }

    function testPaidMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint(bob);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint{value: price + 1}(bob);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.mint{value: price}(bob);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testPaidSafeMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint(bob);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint{value: price + 1}(bob);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.safeMint{value: price}(bob);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testPaidBatchMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        address[] memory recipients = new address[](3);
        recipients[0] = address(bob);
        recipients[1] = address(bob);
        recipients[2] = address(bob);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mintBatch(recipients);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mintBatch{value: price}(recipients);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.mintBatch{value: 3 * price}(recipients);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testTransferOwnershipFailsForBob() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.transferOwnership(bob);
    }

    function testTransferOwnershipWorksForOwner() public {
        vm.prank(editionOwner);
        edition.transferOwnership(bob);
        assertEq(edition.owner(), bob);
    }
}
