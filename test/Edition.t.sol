// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";

import {IERC721ReceiverUpgradeable} from
    "@openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import {Base64} from "contracts/utils/Base64.sol";
import {Edition} from "contracts/Edition.sol";
import {EditionCreator, IEdition} from "contracts/EditionCreator.sol";

import "test/common/EditionBaseSpec.t.sol";

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

contract EditionTest is EditionBaseSpec {
    Edition internal edition;

    ERC721AwareContract erc721AwareContract = new ERC721AwareContract();
    UnsuspectingContract unsuspectingContract = new UnsuspectingContract();

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    /*//////////////////////////////////////////////////////////////
                          BASE SPEC OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        edition = Edition(_edition);
    }

    function createImpl() internal override returns (address) {
        return address(new Edition());
    }

    function mint(address _edition, address to, address msgSender, bytes memory expectedError)
        internal
        override
        returns (uint256 tokenId)
    {
        vm.prank(msgSender);
        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        return IEdition(_edition).mint(to);
    }

    function mint(address _edition, uint256 num, address msgSender, bytes memory expectedError) internal override {
        address[] memory recipients = new address[](num);
        for (uint256 i = 0; i < num; i++) {
            recipients[i] = address(erc721AwareContract);
        }

        vm.prank(msgSender);
        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }
        IEdition(_edition).mintBatch(recipients);
    }

    /*//////////////////////////////////////////////////////////////
                          MINT/SAFEMINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mintBatch_four() public {
        // setup edition with a regular mint beforehand
        vm.prank(approvedMinter);
        edition.mint(address(this));

        // make a batch of address with duplicates, unsorted
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        recipients[3] = alice;

        vm.prank(approvedMinter);
        uint256 lastTokenId = edition.mintBatch(recipients);

        assertEq(lastTokenId, 5);
        assertEq(edition.totalSupply(), 5);
        assertEq(edition.ownerOf(2), alice);
        assertEq(edition.ownerOf(3), bob);
        assertEq(edition.ownerOf(4), charlie);
        assertEq(edition.ownerOf(5), alice);
        assertEq(edition.balanceOf(alice), 2);
    }

    function test_mint_canMintToUnsuspectingContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(unsuspectingContract),
            /* whatever */
            0
        );

        vm.prank(approvedMinter);
        edition.mint(address(unsuspectingContract));
    }

    function test_safeMint_canNotMintToUnsuspectingContracts() public {
        // the "UNSAFE_RECIPIENT" error does not bubble up to the caller
        vm.expectRevert();
        edition.safeMint(address(unsuspectingContract));
    }

    function test_safeMint_canMintToAwareContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(erc721AwareContract),
            /* whatever */
            0
        );

        vm.prank(approvedMinter);
        edition.mint(address(erc721AwareContract));
    }

    function test_mint_singleRespectsSupplyLimit() public {
        vm.startPrank(approvedMinter);
        while (edition.totalSupply() < DEFAULT_CONFIG.editionSize) {
            edition.mint(bob);
        }

        vm.expectRevert(SoldOut.selector);
        edition.mint(bob);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            SALE PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setSalePrice_onlyOwnerFail() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setSalePrice(0 ether);
    }

    function test_setSalePrice_smallest() public {
        uint256 smallestPriceWei = 0.001 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(smallestPriceWei);
        assertEq(edition.salePrice(), smallestPriceWei);
    }

    function test_setSalePrice_largest() public {
        uint256 largestPriceWei = 4294.967295 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(largestPriceWei);
        assertEq(edition.salePrice(), largestPriceWei);
    }

    function test_setSalePrice_underflow() public {
        uint256 tooSmall = 1 wei;
        vm.prank(editionOwner);
        vm.expectRevert(abi.encodeWithSignature("PriceTooLow()"));
        edition.setSalePrice(tooSmall);
    }

    function test_setSalePrice_overflow() public {
        uint256 tooBig = 4294.967296 ether;
        vm.prank(editionOwner);
        vm.expectRevert(newIntegerOverflow(0x100000000));
        edition.setSalePrice(tooBig);
    }

    function test_setSalePrice_reflected() public {
        assertEq(edition.salePrice(), 0 ether);

        vm.prank(editionOwner);
        edition.setSalePrice(1 ether);

        assertEq({a: edition.salePrice(), b: 1 ether});
    }

    /*//////////////////////////////////////////////////////////////
                            PAID MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_e2e_freeMintRejectsEth() public {
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

    function test_e2e_paidMint() public {
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

    function test_e2e_paidSafeMint() public {
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

    function test_e2e_paidBatchMint() public {
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
}
