// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISingleNFT {
    function create(address user, string memory uri) external returns (uint256);
    function burn(uint256 _id) external returns (bool);
    function setTokenURI(uint256 _tokenId, string memory _newURI) external returns (bool);
}
