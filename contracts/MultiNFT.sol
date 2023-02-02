//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";

contract MultiNFT is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable
{
    using Strings for string;
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIds;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;

    // mapping for token URIs
    mapping(uint256 => string) private tokenURIs;

    string public name;
    string public symbol;

    modifier creatorOnly(uint256 _id) {
        require(
            creators[_id] == _msgSender(),
            "ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    modifier ownersOnly(uint256 _id) {
        require(
            balanceOf(_msgSender(), _id) > 0,
            "ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public initializer {
        __ERC1155_init(_uri);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        name = _name;
        symbol = _symbol;
        _tokenIds = 0;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(
            _exists(_id),
            "Metadata: URI query for nonexistent token"
        );
        bytes memory tokenURIsBytes = bytes(tokenURIs[_id]);
        if (tokenURIsBytes.length > 0) {
            return tokenURIs[_id];
        } else {
            return super.uri(_id);
        }
    }

    function create(
        address _user,
        uint256 _quantity,
        string calldata _uri,
        bytes calldata _data
    ) external returns (uint256) {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "MultiNFT: !AUTHORIZED"
        );
        uint256 _tokenId = _getNextTokenID();
        _incrementTokenId();

        creators[_tokenId] = _msgSender();
        tokenURIs[_tokenId] = _uri;

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _tokenId);
        }

        _mint(_user, _tokenId, _quantity, _data);
        tokenSupply[_tokenId] = _quantity;
        return _tokenId;
    }

    function burn(uint256 _id, uint256 _quantity)
        external
        ownersOnly(_id)
        returns (bool)
    {
        _burn(_msgSender(), _id, _quantity);
        tokenSupply[_id] = tokenSupply[_id].sub(_quantity);
        return true;
    }

    function setTokenURI(uint256 _tokenId, string memory _newURI)
        external
        creatorOnly(_tokenId)
        returns (bool)
    {
        tokenURIs[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
        return true;
    }

    function creatorOf(uint256 _id) public view returns (address) {
        return creators[_id];
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    /**
     * @dev calculates the next token ID based on value of _tokenIds
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _tokenIds.add(1);
    }

    /**
     * @dev increments the value of _tokenIds
     */
    function _incrementTokenId() private {
        _tokenIds++;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return
            ERC1155Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }
}
