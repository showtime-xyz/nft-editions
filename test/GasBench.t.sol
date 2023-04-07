// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {ERC721I} from "SS2ERC721/ERC721I.sol";
import {SS2ERC721} from "SS2ERC721/SS2ERC721.sol";

import {Addresses} from "contracts/utils/Addresses.sol";
import {Edition} from "contracts/Edition.sol";
import {SingleBatchEdition} from "contracts/SingleBatchEdition.sol";

contract SolmateERC721 is ERC721I {
    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        __ERC721_init(name, symbol);
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return name;
    }
}

contract Sstore2ERC721 is SS2ERC721 {
    constructor (string memory _name, string memory _symbol) SS2ERC721(_name, _symbol) {}

    function mint(bytes calldata recipients) public {
        _mint(recipients);
    }

    function mint(address pointer) public {
        _mint(pointer);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return name;
    }
}

contract GasBench is Test {
    Edition editionImpl;
    Edition edition;

    SolmateERC721 solmateErc721;

    SingleBatchEdition singleBatchImpl;
    SingleBatchEdition singleBatchForMinting;
    SingleBatchEdition singleBatchForTransfers;

    Sstore2ERC721 sstore2Erc721ForMinting;
    Sstore2ERC721 sstore2Erc721ForTransfers;

    address bob = makeAddr("bob");

    function setUp() public {
        editionImpl = new Edition();
        edition = Edition(ClonesUpgradeable.clone(address(editionImpl)));
        edition.initialize(
            address(this),
            "Edition",
            "EDITION",
            "description",
            "https://animation.url",
            "https://image.url",
            10000, // editionSize
            10_00, // royaltyBps
            2 days // mintPeriodSeconds
        );

        edition.mint(address(this));

        singleBatchImpl = new SingleBatchEdition();
        singleBatchForMinting = SingleBatchEdition(
            ClonesUpgradeable.clone(address(singleBatchImpl))
        );

        singleBatchForMinting.initialize(
            address(this),
            "SingleBatchEdition for Minting",
            "BATCH",
            "description",
            "https://animation.url",
            "https://image.url",
            0, // editionSize
            2_50, // royaltyBps
            0 // mintPeriodSeconds
        );

        singleBatchForTransfers = SingleBatchEdition(
            ClonesUpgradeable.clone(address(singleBatchImpl))
        );

        singleBatchForTransfers.initialize(
            address(this),
            "SingleBatchEdition for Transfers",
            "BATCH",
            "description",
            "https://animation.url",
            "https://image.url",
            0, // editionSize
            2_50, // royaltyBps
            0 // mintPeriodSeconds
        );

        singleBatchForTransfers.mintBatch(
            abi.encodePacked(address(this), Addresses.incr(address(this)))
        );

        solmateErc721 = SolmateERC721(ClonesUpgradeable.clone(address(new SolmateERC721())));
        solmateErc721.initialize("Solmate Baseline", "SOLMATE");
        solmateErc721.mint(address(this), 1);

        sstore2Erc721ForMinting = new Sstore2ERC721("Sstore2ERC721 for Minting", "SSTORE2");
        sstore2Erc721ForTransfers = new Sstore2ERC721("Sstore2ERC721 for Transfers", "SSTORE2");
        sstore2Erc721ForTransfers.mint(abi.encodePacked(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                          SOLMATE ERC721 TESTS
    //////////////////////////////////////////////////////////////*/

    function test__solmateErc721__mint0001() public {
        solmateErc721.mint(address(this), 2);
    }

    function test__solmateErc721__mint0010() public {
        for (uint256 i = 0; i < 10; ) {
            solmateErc721.mint(address(this), i + 2);

            unchecked {
                ++i;
            }
        }
    }

    function test__solmateErc721__mint0100() public {
        for (uint256 i = 0; i < 100; ) {
            solmateErc721.mint(address(this), i + 2);

            unchecked {
                ++i;
            }
        }
    }

    function test__solmateErc721__mint1000() public {
        for (uint256 i = 0; i < 1000; ) {
            solmateErc721.mint(address(this), i + 2);

            unchecked {
                ++i;
            }
        }
    }

    function test__solmateErc721__transfer() public {
        solmateErc721.transferFrom(address(this), bob, 1);
    }

    function test__solmateErc721__burn() public {
        solmateErc721.burn(1);
    }

    function test__solmateErc721__ownerOf() public view {
        solmateErc721.ownerOf(1);
    }

    function test__solmateErc721__balanceOf() public view {
        solmateErc721.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                             EDITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test__edition__mint0001() public {
        edition.mint(address(this));
    }

    function test__edition__mint0010() public {
        for (uint256 i = 0; i < 10; ) {
            edition.mint(address(this));

            unchecked {
                ++i;
            }
        }
    }

    function test__edition__mint0100() public {
        for (uint256 i = 0; i < 100; ) {
            edition.mint(address(this));

            unchecked {
                ++i;
            }
        }
    }

    function test__edition__mint1000() public {
        for (uint256 i = 0; i < 1000; ) {
            edition.mint(address(this));

            unchecked {
                ++i;
            }
        }
    }

    function test__edition__transfer() public {
        edition.transferFrom(address(this), bob, 1);
    }

    function test__edition__burn() public {
        edition.transferFrom(address(this), address(0xdEaD), 1);
    }

    function test__edition__ownerOf() public view {
        edition.ownerOf(1);
    }

    function test__edition__balanceOf() public view {
        edition.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        SINGLE BATCH EDITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test__singleBatchEdition__mint0001() public {
        singleBatchForMinting.mintBatch(Addresses.make(1));
    }

    function test__singleBatchEdition__mint0010() public {
        singleBatchForMinting.mintBatch(Addresses.make(10));
    }

    function test__singleBatchEdition__mint0100() public {
        singleBatchForMinting.mintBatch(Addresses.make(100));
    }

    function test__singleBatchEdition__mint1000() public {
        singleBatchForMinting.mintBatch(Addresses.make(1000));
    }

    function test__singleBatchEdition__transfer() public {
        singleBatchForTransfers.transferFrom(address(this), bob, 1);
    }

    function test__singleBatchEdition__burn() public {
        singleBatchForTransfers.transferFrom(address(this), address(0xdEaD), 1);
    }

    function test__singleBatchEdition__ownerOf() public view {
        singleBatchForTransfers.ownerOf(1);
    }

    function test__singleBatchEdition__balanceOf() public view {
        singleBatchForTransfers.balanceOf(address(this));
    }


    /*//////////////////////////////////////////////////////////////
                          SSTORE2 ERC721 TESTS
    //////////////////////////////////////////////////////////////*/

    function test__sstore2Erc721__mint0001() public {
        sstore2Erc721ForMinting.mint(Addresses.make(1));
    }

    function test__sstore2Erc721__mint0010() public {
        sstore2Erc721ForMinting.mint(Addresses.make(10));
    }

    function test__sstore2Erc721__mint0100() public {
        sstore2Erc721ForMinting.mint(Addresses.make(100));
    }

    function test__sstore2Erc721__mint1000() public {
        sstore2Erc721ForMinting.mint(Addresses.make(1000));
    }

    function test__sstore2Erc721__transfer() public {
        sstore2Erc721ForTransfers.transferFrom(address(this), bob, 1);
    }

    function test__sstore2Erc721__burn() public {
        sstore2Erc721ForTransfers.burn(1);
    }

    function test__sstore2Erc721__ownerOf() public view {
        sstore2Erc721ForTransfers.ownerOf(1);
    }

    function test__sstore2Erc721__balanceOf() public view {
        sstore2Erc721ForTransfers.balanceOf(address(this));
    }
}
