// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";

import {IERC721, IERC721Metadata} from "forge-std/interfaces/IERC721.sol";

import {EditionBase} from "contracts/common/EditionBase.sol";

import "contracts/interfaces/Errors.sol";

function newBadAttribute(string memory name, string memory value) pure returns (bytes memory) {
    return abi.encodeWithSelector(BadAttribute.selector, name, value);
}

struct EditionConfig {
    string name;
    string symbol;
    string description;
    string animationUrl;
    string imageUrl;
    uint256 editionSize;
    uint256 royaltiesBps;
    uint256 mintPeriod;
}

library EditionConfigWither {
    function withName(EditionConfig memory c, string memory n) internal pure returns (EditionConfig memory) {
        c.name = n;
        return c;
    }

    function withSymbol(EditionConfig memory c, string memory s) internal pure returns (EditionConfig memory) {
        c.symbol = s;
        return c;
    }

    function withDescription(EditionConfig memory c, string memory d) internal pure returns (EditionConfig memory) {
        c.description = d;
        return c;
    }

    function withAnimationUrl(EditionConfig memory c, string memory a) internal pure returns (EditionConfig memory) {
        c.animationUrl = a;
        return c;
    }

    function withImageUrl(EditionConfig memory c, string memory i) internal pure returns (EditionConfig memory) {
        c.imageUrl = i;
        return c;
    }

    function withEditionSize(EditionConfig memory c, uint256 e) internal pure returns (EditionConfig memory) {
        c.editionSize = e;
        return c;
    }

    function withMintPeriod(EditionConfig memory c, uint256 m) internal pure returns (EditionConfig memory) {
        c.mintPeriod = m;
        return c;
    }

    function withRoyaltiesBps(EditionConfig memory c, uint256 r) internal pure returns (EditionConfig memory) {
        c.royaltiesBps = r;
        return c;
    }
}


contract EditionFixture is Test {
    event PriceChanged(uint256 amount);
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);
    event Initialized();
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    EditionConfig public DEFAULT_CONFIG = EditionConfig(
        "Testing Token",
        "TEST",
        "This is a testing token for all",
        "",
        "ipfs://someImageHash",
        10, // editionSize
        2_50, // royaltiesBps
        0 // mintPeriod
    );

    address internal editionOwner = makeAddr("editionOwner");
    address internal approvedMinter = makeAddr("approvedMinter");
}
