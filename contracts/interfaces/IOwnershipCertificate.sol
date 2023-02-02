// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IOwnershipCertificate {
    function grantCertificate(
        address tokenAddress,
        uint256 tokenId,
        address creator,
        address seller,
        address owner,
        string memory tokenURI
    ) external returns (bool);
}
