// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILicense {
    enum TokenTypes {ERC1155, ERC721}
    function grantLicense(address tokenAddress, uint256 tokenId, TokenTypes tokenType, address licensee) external returns (bool);
    function revokeLicense(address tokenAddress, uint256 tokenId, TokenTypes tokenType, address licensee) external returns (bool);
    function isLicensed(address tokenAddress, uint256 tokenId, address licensee) external returns (bool);
}
