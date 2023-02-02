// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

contract OwnershipCertificate is
    Initializable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GOVERNER_ROLE = keccak256("GOVERNER_ROLE");

    enum TokenTypes {
        ERC1155,
        ERC721
    }

    CountersUpgradeable.Counter private _certificateIds;

    /** @dev tokenAddress => tokenId => certificateId */
    mapping(address => mapping(uint256 => uint256)) certificateByAsset;

    event OwnershipCertificateGranted(
        uint256 id,
        address indexed tokenAddress,
        uint256 tokenId,
        address indexed creator,
        address indexed buyer,
        string uri
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
                "OwnershipCertificate: !OWNER"
            );
        } else {
            IERC721 tokenContract = IERC721(tokenAddress);
            require(
                tokenContract.ownerOf(tokenId) == _msgSender(),
                "OwnershipCertificate: !OWNER"
            );
        }
        _;
    }

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(GOVERNER_ROLE, _msgSender());
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyRole(GOVERNER_ROLE) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyRole(GOVERNER_ROLE) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override onlyRole(GOVERNER_ROLE) {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function registerAsset(
        TokenTypes tokenType,
        address tokenAddress,
        uint256 tokenId,
        address creator,
        address owner,
        string memory tokenURI
    ) external onlyOwner(tokenAddress, tokenId, tokenType) returns (uint256) {
        uint256 certificateId = certificateByAsset[tokenAddress][tokenId];
        require(
            certificateId == 0,
            "OwnershipCertificate: Certificate Already Minted"
        );
        _certificateIds.increment();
        certificateId = _certificateIds.current();
        _mint(owner, certificateId);
        certificateByAsset[tokenAddress][tokenId] = certificateId;
        string memory certificateURI = string(
            abi.encodePacked(tokenAddress, tokenId, creator, owner, tokenURI)
        );
        _setTokenURI(certificateId, certificateURI);
        emit OwnershipCertificateGranted(
            certificateId,
            tokenAddress,
            tokenId,
            creator,
            owner,
            tokenURI
        );
        return certificateId;
    }

    function grantCertificate(
        address tokenAddress,
        uint256 tokenId,
        address creator,
        address seller,
        address buyer,
        string memory tokenURI
    ) external onlyRole(GOVERNER_ROLE) returns (bool) {
        uint256 certificateId = certificateByAsset[tokenAddress][tokenId];
        if (certificateId == 0) {
            _certificateIds.increment();
            certificateId = _certificateIds.current();
            _mint(buyer, certificateId);
            certificateByAsset[tokenAddress][tokenId] = certificateId;
        } else {
            _validateCertificate(
                certificateId,
                tokenAddress,
                tokenId,
                creator,
                seller,
                tokenURI
            );
            _safeTransfer(seller, buyer, certificateId, "");
        }
        string memory certificateURI = string(
            abi.encodePacked(tokenAddress, tokenId, creator, buyer, tokenURI)
        );
        _setTokenURI(certificateId, certificateURI);
        emit OwnershipCertificateGranted(
            certificateId,
            tokenAddress,
            tokenId,
            creator,
            buyer,
            tokenURI
        );
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    function _validateCertificate(
        uint256 id,
        address tokenAddress,
        uint256 tokenId,
        address creator,
        address seller,
        string memory uri
    ) internal view {
        string memory certificateURI = string(
            abi.encodePacked(tokenAddress, tokenId, creator, seller, uri)
        );
        require(
            keccak256(abi.encodePacked(certificateURI)) ==
                keccak256(abi.encodePacked(tokenURI(id))),
            "OwnershipCertificate: INVALID_CERTIFICATE"
        );
    }
}
