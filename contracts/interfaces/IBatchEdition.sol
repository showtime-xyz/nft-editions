// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {IEditionBase} from "./IEditionBase.sol";
import {IBatchMintable} from "./IBatchMintable.sol";

interface IBatchEdition is IEditionBase, IBatchMintable {
    // just a convenience wrapper for the parent editions
}
