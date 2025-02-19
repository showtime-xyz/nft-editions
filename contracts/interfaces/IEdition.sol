// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import {IEditionBase} from "./IEditionBase.sol";
import {IRealTimeMintable} from "./IRealTimeMintable.sol";

interface IEdition is IRealTimeMintable, IEditionBase {
    // just a convenience wrapper for the parent editions
}
