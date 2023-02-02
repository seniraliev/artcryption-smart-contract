// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "hardhat/console.sol";

contract MockWETH is ERC20 {
    constructor(address user, address buyer) ERC20("WETH", "WETH") {
        _mint(_msgSender(), 100000000000000000000);
        _mint(user, 100000000000000000000);
        _mint(buyer, 100000000000000000000);
    }
}
