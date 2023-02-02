// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

contract License is Initializable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum TokenTypes {
        ERC1155,
        ERC721
    }

    /** @dev mapping token Address => token Id => Licenced Addresses */
    mapping(address => mapping(uint256 => EnumerableSetUpgradeable.AddressSet))
        internal licencees;

    event LicenseGranted(
        address _tokenAddress,
        uint256 _tokenId,
        address _licensee
    );

    event LicenseRevoked(
        address _tokenAddress,
        uint256 _tokenId,
        address _licensee
    );

    /**
    @dev Modifier to check whether msgSender is Owner
     */
    modifier onlyOwner(
        address tokenAddress,
        uint256 tokenId,
        TokenTypes tokenType
    ) {
        if (tokenType == TokenTypes.ERC1155) {
            IERC1155 tokenContract = IERC1155(tokenAddress);
            require(
                tokenContract.balanceOf(_msgSender(), tokenId) == 1,
                "Marketplace: !OWNER"
            );
        } else {
            IERC721 tokenContract = IERC721(tokenAddress);
            require(
                tokenContract.ownerOf(tokenId) == _msgSender(),
                "Marketplace: !OWNER"
            );
        }
        _;
    }

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    function grantLicense(
        address tokenAddress,
        uint256 tokenId,
        TokenTypes tokenType,
        address licensee
    ) external onlyOwner(tokenAddress, tokenId, tokenType) returns (bool) {
        licencees[tokenAddress][tokenId].add(licensee);
        emit LicenseGranted(tokenAddress, tokenId, licensee);
        return true;
    }

    function revokeLicense(
        address tokenAddress,
        uint256 tokenId,
        TokenTypes tokenType,
        address licensee
    ) external onlyOwner(tokenAddress, tokenId, tokenType) returns (bool) {
        licencees[tokenAddress][tokenId].remove(licensee);
        emit LicenseRevoked(tokenAddress, tokenId, licensee);
        return true;
    }

    function isLicensed(
        address tokenAddress,
        uint256 tokenId,
        address licensee
    ) external view returns (bool) {
        return licencees[tokenAddress][tokenId].contains(licensee);
    }
}
