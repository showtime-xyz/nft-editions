// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console2} from "forge-std/console2.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

import {EditionFixture} from "./fixtures/EditionFixture.sol";

interface IOperatorFilterRegistry {
    function filteredOperators(address addr) external returns (address[] memory);
}

contract MockRegistry {
    address[] public filteredOperators;

    function setFilteredOperators(address[] memory _filteredOperators) public {
        filteredOperators = _filteredOperators;
    }

    function isOperatorAllowed(address, /* registrant */ address operator) public view returns (bool) {
        for (uint256 i = 0; i < filteredOperators.length; i++) {
            if (filteredOperators[i] == operator) {
                return false;
            }
        }

        return true;
    }
}

/// @dev modified from operator-filter-registry/test/Validation.t.sol
contract EditionOperatorFiltering is EditionFixture {
    address constant CANONICAL_OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;
    address constant CANONICAL_OPENSEA_REGISTRANT = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    // Contract to test against
    address contractAddress;

    // Token ID to test against
    uint256 tokenId;

    // Owner of the NFT
    address owner;

    address[] filteredOperators;

    function setUp() public {
        __EditionFixture_setUp();

        // try to load contract address from .env
        try vm.envAddress("CONTRACT_ADDRESS") returns (address _contractAddress) {
            contractAddress = _contractAddress;
        } catch (bytes memory) {
            // fallback to deploying new contract
            contractAddress = address(edition);
            vm.prank(editionOwner);
            edition.setOperatorFilter(CANONICAL_OPENSEA_REGISTRANT);
        }

        // try to load token ID from .env
        try vm.envUint("TOKEN_ID") returns (uint256 _tokenId) {
            tokenId = _tokenId;
        } catch (bytes memory) {
            // fallback to minting
            tokenId = edition.mint(address(this));
        }

        // try to load owner from .env
        try vm.envAddress("OWNER") returns (address _owner) {
            owner = _owner;
        } catch (bytes memory) {
            // fallback to this
            owner = address(this);
        }

        initFilteredOperators();
    }

    function initFilteredOperators() internal {
        try vm.envString("NETWORK") returns (string memory envNetwork) {
            vm.createSelectFork(getChain(envNetwork).rpcUrl);

            filteredOperators = IOperatorFilterRegistry(CANONICAL_OPERATOR_FILTER_REGISTRY).filteredOperators(
                CANONICAL_OPENSEA_REGISTRANT
            );
        } catch {
            // fallback to static list
            console2.log("No network specified, using static list (Dec 2022 snapshot)");

            filteredOperators = abi.decode(
                hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000111abe46ff893f3b2fdf1f759a8a8000000000000000000000000fed24ec7e22f573c2e08aef55aa6797ca2b3a051000000000000000000000000f42aa99f011a1fa7cda90e5e98b277e306bca83e000000000000000000000000b16c1342e617a5b6e4b631eb114483fdb289c0a4000000000000000000000000d42638863462d2f21bb7d4275d7637ee5d5541eb00000000000000000000000008ce97807a81896e85841d74fb7e7b065ab3ef0500000000000000000000000092de3a1511ef22abcf3526c302159882a4755b22000000000000000000000000cd80c916b1194beb48abf007d0b79a7238436d56",
                (address[])
            );

            MockRegistry mockRegistry = new MockRegistry();
            vm.etch(CANONICAL_OPERATOR_FILTER_REGISTRY, address(mockRegistry).code);
            MockRegistry(CANONICAL_OPERATOR_FILTER_REGISTRY).setFilteredOperators(filteredOperators);
        }
    }

    function testEnableDefaultOperator() public {
        vm.startPrank(editionOwner);

        edition.setOperatorFilter(address(0));
        assertEq(edition.activeOperatorFilter(), address(0));

        edition.enableDefaultOperatorFilter();
        assertEq(edition.activeOperatorFilter(), CANONICAL_OPENSEA_REGISTRANT);

        vm.stopPrank();
    }

    function testOperatorFiltering() public {
        IERC721 nftContract = IERC721(contractAddress);

        // Try to get the current owner of the NFT, falling back to value set during setup on revert
        try nftContract.ownerOf(tokenId) returns (address _owner) {
            owner = _owner;
        } catch (bytes memory) {
            // Do nothing
        }

        for (uint256 i = 0; i < filteredOperators.length; i++) {
            address operator = filteredOperators[i];
            console2.log("Testing operator: ", operator);

            // Try to set approval for the operator
            vm.startPrank(owner);
            try nftContract.setApprovalForAll(operator, true) {
                // blocking approvals is not required, so continue to check transfers
            } catch (bytes memory) {
                // continue to test transfer methods, since marketplace approvals can be
                // hard-coded into contracts
            }

            // also include per-token approvals as those may not be blocked
            try nftContract.approve(operator, tokenId) {
                // continue to check transfers
            } catch (bytes memory) {
                // continue to test transfer methods, since marketplace approvals can be
                // hard-coded into contracts
            }

            vm.stopPrank();
            // Ensure operator is not able to transfer the token
            vm.startPrank(operator);
            vm.expectRevert();
            nftContract.safeTransferFrom(owner, address(1), tokenId);

            vm.expectRevert();
            nftContract.safeTransferFrom(owner, address(1), tokenId, "");

            vm.expectRevert();
            nftContract.transferFrom(owner, address(1), tokenId);
            vm.stopPrank();
        }
    }
}
