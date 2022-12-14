// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC721ReceiverUpgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import {Base64} from "contracts/utils/Base64.sol";
import {Edition} from "contracts/Edition.sol";
import {EditionCreator, IEdition} from "contracts/EditionCreator.sol";
import {LibString} from "contracts/utils/LibString.sol";

import "contracts/interfaces/Errors.sol";

function newIntegerOverflow(uint256 value) pure returns (bytes memory) {
    return abi.encodeWithSelector(IntegerOverflow.selector, value);
}

function newBadAttribute(string memory name, string memory value) pure returns (bytes memory) {
    return abi.encodeWithSelector(BadAttribute.selector, name, value);
}

/// @dev expects dataUri to be "data:application/json;base64,..."
function parseDataUri(string memory dataUri) pure returns (string memory json) {
    string memory base64Slice = LibString.slice(
        dataUri,
        29, // length of 'data:application/json;base64,'
        bytes(dataUri).length
    );

    json = string(Base64.decode(base64Slice));
}

function jsonString(string memory json, string memory key) pure returns (string memory) {
    return abi.decode(
        stdJson.parseRaw(json, key),
        (string)
    );
}

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

    struct EditionParams {
        string name;
        string symbol;
        string description;
        string animationUrl;
        string imageUrl;
        uint256 editionSize;
        uint256 royaltiesBps;
        uint256 mintPeriod;
    }

    EditionParams internal DEFAULT_PARAMS = EditionParams(
        "Testing Token",
        "TEST",
        "This is a testing token for all",
        "",
        "ipfs://someImageHash",
        10,
        1000,
        0
    );

    address internal editionOwner = makeAddr("editionOwner");

    /// @dev initialized in __EditionFixture_setUp()
    EditionCreator editionCreator;
    Edition editionImpl;
    Edition edition;

        ERC721AwareContract erc721AwareContract = new ERC721AwareContract();
    UnsuspectingContract unsuspectingContract = new UnsuspectingContract();

    function createEdition(EditionParams memory params, bytes memory expectedError)
        internal
        returns (Edition _edition)
    {
        vm.startPrank(editionOwner);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        _edition = Edition(
            address(
                editionCreator.createEdition(
                    params.name,
                    params.symbol,
                    params.description,
                    params.animationUrl,
                    params.imageUrl,
                    params.editionSize,
                    params.royaltiesBps,
                    params.mintPeriod
                )
            )
        );

        // so that we can mint from this without having to call prank all the time
        // only perform this if we expect no error
        if (expectedError.length == 0) {
            _edition.setApprovedMinter(address(this), true);
        }

        vm.stopPrank();
        return _edition;
    }

    function createEdition(EditionParams memory params) internal returns (Edition) {
        return createEdition(params, "");
    }

    function createEdition() internal returns (Edition) {
        return createEdition(DEFAULT_PARAMS, "");
    }

    function __EditionFixture_setUp() internal  {
        editionImpl = new Edition();
        editionCreator = new EditionCreator(address(editionImpl));
        edition = createEdition();
    }
}
