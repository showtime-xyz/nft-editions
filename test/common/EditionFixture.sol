// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {IERC721, IERC721Metadata} from "forge-std/interfaces/IERC721.sol";
import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {EditionBase, IEditionBase} from "contracts/common/EditionBase.sol";

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


abstract contract EditionFixture is Test {
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
    address internal _editionImpl;
    address internal _edition;
    address internal _openEdition;
    address internal _timeLimitedEdition;

    /*//////////////////////////////////////////////////////////////
             CONCRETE TESTS MUST IMPLEMENT THESE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createImpl() internal virtual returns (address);

    function mint(address edition, address to, address msgSender, bytes memory expectedError)
        internal
        virtual
        returns (uint256 tokenId);

    function mint(address edition, uint256 num, address msgSender, bytes memory expectedError) internal virtual;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function create() internal returns (address) {
        return create(DEFAULT_CONFIG);
    }

    function create(EditionConfig memory config) internal returns (address) {
        return create(config, "");
    }

    /// @dev create a clone of editionImpl with the given config
    /// @dev make sure to transferOwnership to editionOwner
    /// @dev make sure to approve minting for approvedMinter
    function create(EditionConfig memory config, bytes memory expectedError) internal virtual returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(config.name));

        require(_editionImpl != address(0), "_editionImpl not set");

        // anybody can clone
        address newEdition = ClonesUpgradeable.cloneDeterministic(_editionImpl, salt);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        // anybody can initialize
        IEditionBase(newEdition).initialize(
            editionOwner,
            config.name,
            config.symbol,
            config.description,
            config.animationUrl,
            config.imageUrl,
            config.editionSize,
            config.royaltiesBps,
            config.mintPeriod
        );

        // only continue if we were not expecting an error
        if (expectedError.length == 0) {
            // only the owner can configure the approved minter
            vm.prank(editionOwner);
            IEditionBase(newEdition).setApprovedMinter(address(approvedMinter), true);
        }

        return newEdition;
    }

    function mint(address edition, address to) internal returns (uint256 tokenId) {
        return mint(edition, to, approvedMinter, "");
    }

    function mint(address edition, address to, address msgSender) internal returns (uint256 tokenId) {
        return mint(edition, to, msgSender, "");
    }

    function mint(address edition, uint256 num) internal {
        mint(edition, num, approvedMinter, "");
    }

    function mint(address edition, uint256 num, address msgSender) internal {
        mint(edition, num, msgSender, "");
    }

}
