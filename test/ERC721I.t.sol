// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {ERC721, ERC721I} from "SS2ERC721/ERC721I.sol";

contract GenericTokenUri is ERC721I {
    function tokenURI(uint256) public view virtual override returns (string memory) {
        return "basic";
    }
}

contract BasicERC721I is GenericTokenUri {
    // recommended: no need for an explicit constructor

    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        __ERC721_init(name, symbol);
    }
}

contract BadConstructorERC721I is GenericTokenUri {
    /// @dev this kind of constructor is weird, should be an initializer instead
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;

        // initializers should be locked after invocation of the parent constructor
    }

    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC721_init(_name, _symbol);
    }
}

contract OkConstructorERC721I is GenericTokenUri {
    constructor() {
        name = "defaultImpl";
        symbol = "IMPL";
    }

    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC721_init(_name, _symbol);
    }
}

contract ConfusedConstructor is GenericTokenUri {
    constructor(string memory _name, string memory _symbol) {
        // can only call __ERC721_init from an `initializer` function
        __ERC721_init(_name, _symbol);
    }
}


contract WeirdInitializerConstructor is GenericTokenUri {
    /// @dev seems technically legal, but doesn't work because the parent locks initializers
    constructor(string memory _name, string memory _symbol) initializer {
        __ERC721_init(_name, _symbol);
    }
}


contract ERC721ITest is Test {
    function testConstructor() public {
        new BasicERC721I();
    }

    function testCanNotInitializeImpl() public {
        BasicERC721I erc721 = new BasicERC721I();

        vm.expectRevert("ALREADY_INITIALIZED");
        erc721.initialize("name", "symbol");
    }

    function testCanInitializeClone() public {
        BasicERC721I clone = BasicERC721I(ClonesUpgradeable.clone(address(new BasicERC721I())));
        clone.initialize("clone", "CLONE");

        assertEq(clone.name(), "clone");
    }

    function testBadConstructor() public {
        BadConstructorERC721I erc721 = new BadConstructorERC721I("constructorName", "symbol");

        assertEq(erc721.name(), "constructorName");

        vm.expectRevert("ALREADY_INITIALIZED");
        erc721.initialize("initializerName", "symbol");
    }

    function testOkConstructor() public {
        OkConstructorERC721I erc721 = new OkConstructorERC721I();

        assertEq(erc721.name(), "defaultImpl");

        vm.expectRevert("ALREADY_INITIALIZED");
        erc721.initialize("initializerName", "symbol");

        BasicERC721I clone = BasicERC721I(ClonesUpgradeable.clone(address(erc721)));
        clone.initialize("clone", "CLONE");

        assertEq(clone.name(), "clone");
    }

    function testConfusedConstructor() public {
        vm.expectRevert("NOT_INITIALIZING");
        new ConfusedConstructor("constructorName", "symbol");
    }

    function testWeirdInitializerConstructor() public {
        vm.expectRevert("ALREADY_INITIALIZED");
        new WeirdInitializerConstructor("constructorName", "symbol");
    }
}
