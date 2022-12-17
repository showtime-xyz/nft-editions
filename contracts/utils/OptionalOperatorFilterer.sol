// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import { IOperatorFilterRegistry } from "operator-filter-registry/IOperatorFilterRegistry.sol";

import { OperatorNotAllowed } from "../interfaces/Errors.sol";

/// Less aggro than DefaultOperatorFilterer, it does not automatically register and subscribe to the default filter
/// Instead, this is off by default, opt-in, and relies only on view functions (no register call)
abstract contract OptionalOperatorFilterer {
    address public constant CANONICAL_OPENSEA_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);
    address public constant CANONICAL_OPENSEA_REGISTRY = address(0x000000000000AAeB6D7670E522A718067333cd4E);

    address public activeOperatorFilter = address(0);

    event OperatorFilterChanged(address indexed operatorFilter);

    /// Set to CANONICAL_OPENSEA_SUBSCRIPTION to use the default OpenSea operator filter
    /// Set to address(0) to disable operator filtering
    function _setOperatorFilter(address operatorFilter) internal {
        activeOperatorFilter = operatorFilter;
        emit OperatorFilterChanged(operatorFilter);
    }

    /// @dev modified from operator-filter-registry/OperatorFilterer.sol
    modifier onlyAllowedOperator(address from) virtual {
        // Allow spending tokens from addresses with balance
        // Note that this still allows listings and marketplaces with escrow to transfer tokens if transferred
        // from an EOA.
        if (from != msg.sender) {
            _checkFilterOperator(msg.sender);
        }
        _;
    }

    /// @dev modified from operator-filter-registry/OperatorFilterer.sol
    function _checkFilterOperator(address operator) internal view {
        if (activeOperatorFilter == address(0)) {
            return;
        }

        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (CANONICAL_OPENSEA_REGISTRY.code.length == 0) {
            return;
        }

        if (!IOperatorFilterRegistry(CANONICAL_OPENSEA_REGISTRY).isOperatorAllowed(activeOperatorFilter, operator)) {
            revert OperatorNotAllowed(operator);
        }
    }
}
