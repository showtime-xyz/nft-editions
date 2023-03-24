// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";

import {IERC721ReceiverUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import {Base64} from "contracts/utils/Base64.sol";
import {Edition} from "contracts/Edition.sol";
import {EditionCreator, IEdition} from "contracts/EditionCreator.sol";

import "./fixtures/EditionFixture.sol";

contract EditionFunctionalTests is EditionFixture {
    uint256 tokenId;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        __EditionFixture_setUp();
        tokenId = edition.mint(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR / INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorEmitsInitializedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Initialized();
        new Edition();
    }

    function testNoOwnerAfterConstructor() public {
        Edition newImpl = new Edition();
        assertEq(newImpl.owner(), address(0));
    }

    function testInitializerEmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), address(this));
        editionCreator.createEdition(
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testDoesNotAllowReinitializationOfTheImplContract() public {
        Edition newImpl = new Edition();

        vm.expectRevert("ALREADY_INITIALIZED");
        newImpl.initialize(
            bob,
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testDoesNotAllowReinitializationOfProxyContracts() public {
        vm.expectRevert("ALREADY_INITIALIZED");
        edition.initialize(
            bob,
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testCreateDuplicate() public {
        createEdition(DEFAULT_PARAMS, "ERC1167: create2 failed");
    }

    function testEditionSizeOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.editionSize = tooBig;
        params.name = "Edition Size Too Big";

        createEdition(params, newIntegerOverflow(tooBig));
    }

    function testMintPeriodOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Mint Period Too Big";
        params.mintPeriod = tooBig;

        createEdition(params, newIntegerOverflow(tooBig + block.timestamp));
    }

    function testRoyaltiesOverflow() public {
        uint256 tooBig = uint256(type(uint16).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Royalties Too Big";
        params.royaltiesBps = tooBig;

        createEdition(params, newIntegerOverflow(tooBig));
    }

    /*//////////////////////////////////////////////////////////////
                             ERC2981 TESTS
    //////////////////////////////////////////////////////////////*/

    function testERC165Impl() public {
        assertEq(edition.supportsInterface(0x2a55205a), true); // ERC2981
        assertEq(edition.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(edition.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(edition.supportsInterface(0x5b5e139f), true); // ERC721Metadata
    }

    function testRoyaltyRecipientUpdatedAfterOwnershipTransferred() public {
        (address recipient,) = edition.royaltyInfo(1, 1 ether);
        assertEq(recipient, editionOwner);

        // when we transfer ownership
        vm.prank(editionOwner);
        edition.transferOwnership(bob);

        // then the royalty recipient is updated
        (recipient,) = edition.royaltyInfo(1, 1 ether);
        assertEq(recipient, bob);
    }

    function testRoyaltyAmount(uint128 salePrice) public {
        // uint128 is plenty big and avoids overflow errors
        (, uint256 fee) = edition.royaltyInfo(1, salePrice);
        assertEq(fee, uint256(salePrice) * DEFAULT_PARAMS.royaltiesBps / 100_00);
    }

    function testEditionWithNoRoyalties() public {
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "No Royalties";
        params.royaltiesBps = 0;
        Edition editionNoRoyalties = createEdition(params);

        (, uint256 royaltyAmount) = editionNoRoyalties.royaltyInfo(1, 100);
        assertEq(royaltyAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintingUpdatesTotalSupply() public {
        assertEq(edition.totalSupply(), 1);
        edition.mint(bob);
        assertEq(edition.totalSupply(), 2);
        assertEq(edition.ownerOf(2), bob);
    }

    function testAllowsUserBurn() public {
        // no burn method, burning is done by transfering to the burn address
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);

        // as a result, totalSupply is unchanged
        assertEq(edition.totalSupply(), 1);

        // and the token is owned by the burn address
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testDoesNotAllowUnapprovedBurns() public {
        // bob has no approval for that token
        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    function testAllowsBurnIfApproved() public {
        // when we approve bob
        edition.approve(bob, tokenId);

        // then bob can burn the token
        vm.prank(bob);
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testAllowsBurnIfApprovedForAll() public {
        // when we approve bob
        edition.setApprovalForAll(bob, true);

        // then bob can burn the token
        vm.prank(bob);
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testDoesNotAllowBurningTwice() public {
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);

        vm.expectRevert("WRONG_FROM");
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    function testMintBatch4() public {
        // make a batch of address with duplicates, unsorted
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        recipients[3] = alice;

        uint256 lastTokenId = edition.mintBatch(recipients);

        assertEq(lastTokenId, 5);
        assertEq(edition.totalSupply(), 5);
        assertEq(edition.ownerOf(2), alice);
        assertEq(edition.ownerOf(3), bob);
        assertEq(edition.ownerOf(4), charlie);
        assertEq(edition.ownerOf(5), alice);
        assertEq(edition.balanceOf(alice), 2);
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

    /*//////////////////////////////////////////////////////////////
                           SUPPLY LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testCanNotMintMoreThanEditionSize() public {
        while (edition.totalSupply() < DEFAULT_PARAMS.editionSize) {
            edition.mint(bob);
        }

        vm.expectRevert(SoldOut.selector);
        edition.mint(bob);
    }

    function testCanNotMintBatchBiggerThanEditionSize() public {
        address[] memory recipients = new address[](DEFAULT_PARAMS.editionSize);
        for (uint256 i = 0; i < DEFAULT_PARAMS.editionSize; i++) {
            recipients[i] = bob;
        }

        vm.expectRevert(SoldOut.selector);
        edition.mintBatch(recipients);
    }

    /*//////////////////////////////////////////////////////////////
                            TIME LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testTimeLimitedEditionDuringMintingPeriod() public {
        // setup
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Time Limited Edition";
        params.mintPeriod = 2 days;
        Edition timeLimitedEdition = createEdition(params);

        // minting is allowed
        assertEq(timeLimitedEdition.isMintingEnded(), false);
        timeLimitedEdition.mint(bob);
    }

    function testTimeLimitedEditionAfterMintingPeriod() public {
        // setup
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Time Limited Edition";
        params.mintPeriod = 2 days;
        Edition timeLimitedEdition = createEdition(params);

        vm.prank(editionOwner);
        timeLimitedEdition.setApprovedMinter(address(0), true); // allow anyone to mint

        // after the mint period
        vm.warp(block.timestamp + 3 days);

        // isMintingEnded() returns true
        assertEq(timeLimitedEdition.isMintingEnded(), true);

        // mint() fails
        vm.expectRevert(TimeLimitReached.selector);
        timeLimitedEdition.mint(bob);

        // mintBatch() fails
        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        vm.expectRevert(TimeLimitReached.selector);
        timeLimitedEdition.mintBatch(recipients);

        // mint() with salePrice fails
        vm.prank(editionOwner);
        timeLimitedEdition.setSalePrice(1 ether);
        vm.deal(bob, 1 ether);

        vm.expectRevert(TimeLimitReached.selector);
        vm.prank(bob);
        timeLimitedEdition.mint{value: 1 ether}(bob);

        // it returns the expected totalSupply
        assertEq(timeLimitedEdition.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                               AUTH TESTS
    //////////////////////////////////////////////////////////////*/

    function testOnlyOwnerCanSetApprovedMinter() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setApprovedMinter(bob, true);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.withdraw();
    }

    function testOnlyOwnerCanSetSalePrice() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setSalePrice(0 ether);
    }

    function testOnlyApprovedMinterCanMint() public {
        vm.expectRevert(Unauthorized.selector);
        vm.prank(bob);
        edition.mint(bob);
    }

    function testOnlyOwnerCanTransferOwnership() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.transferOwnership(bob);
    }

    function testOnlyOwnerCanSetOperatorFilter() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.setOperatorFilter(bob);
    }

    function testOnlyOwnerCanEnableDefaultOperatorFilter() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.enableDefaultOperatorFilter();
    }

    /*//////////////////////////////////////////////////////////////
                            SALE PRICE TESTS
    //////////////////////////////////////////////////////////////*/

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

    function testSalePriceReflectedCorrectly() public {
        assertEq(edition.salePrice(), 0 ether);

        vm.prank(editionOwner);
        edition.setSalePrice(1 ether);

        assertEq({a: edition.salePrice(), b: 1 ether});
    }

    /*//////////////////////////////////////////////////////////////
                            PAID MINT TESTS
    //////////////////////////////////////////////////////////////*/

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

    function testWithdraw(uint256 balance) public {
        // setup
        vm.deal(address(edition), balance);

        // when the owner withdraws
        vm.prank(editionOwner);
        edition.withdraw();

        // then the balance is transferred
        assertEq(address(edition).balance, 0);
        assertEq(address(editionOwner).balance, balance);
    }
}
