// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMarketPlace {
    function getSeller(uint256 _saleId) external view returns (address);
    function getBuyer(uint256 _saleId) external view returns (address _buyer);
}
