// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMultiNFT {
    function create(address _user, uint256 _quantity, string calldata _uri, bytes calldata _data) external returns (uint256);
    function burn(uint256 _id, uint256 _quantity) external returns (bool);
    function setTokenURI(uint256 _tokenId, string memory _newURI) external returns (bool);
}
