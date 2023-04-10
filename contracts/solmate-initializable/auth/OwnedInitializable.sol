// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Initializable} from "SS2ERC721/common/utils/Initializable.sol";
import {IOwned} from "./IOwned.sol";

/// @notice Simple single owner authorization mixin.
/// @author karmacoma (replaced constructor with initializer)
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract OwnedInitializable is Initializable, IOwned {
    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function __Owned_init(address _owner) internal onlyInitializing {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}
