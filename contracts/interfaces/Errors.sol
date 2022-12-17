// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

error BadAttribute(string name, string value);
error IntegerOverflow(uint256 value);
error InvalidArgument();
error LengthMismatch();
error NotForSale();
error OperatorNotAllowed(address operator);
error PriceTooLow();
error SoldOut();
error TimeLimitReached();
error Unauthorized();
error WrongPrice();
