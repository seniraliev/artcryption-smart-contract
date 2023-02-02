//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "hardhat/console.sol";

contract SingleNFT is
    Initializable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    CountersUpgradeable.Counter private _tokenIds;
    mapping(uint256 => address) public creators;

    modifier creatorOnly(uint256 _id) {
        require(
            creators[_id] == _msgSender(),
            "ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    modifier ownersOnly(uint256 _id) {
        require(
            ownerOf(_id) == _msgSender(),
            "ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC721_init_unchained(_name, _symbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function create(address user, string memory uri)
        external
        returns (uint256)
    {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "SingleNFT: !AUTHORIZED"
        );
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        creators[tokenId] = _msgSender();
        _safeMint(user, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    function burn(uint256 _id) external ownersOnly(_id) returns (bool) {
        _burn(_id);
        return true;
    }

    function setTokenURI(uint256 _tokenId, string memory _newURI)
        external
        creatorOnly(_tokenId)
        returns (bool)
    {
        _setTokenURI(_tokenId, _newURI);
        return true;
    }

    function creatorOf(uint256 _id) public view returns (address) {
        return creators[_id];
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
}
