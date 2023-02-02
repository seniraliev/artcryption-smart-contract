// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/interfaces/IMarketPlace.sol";

import "hardhat/console.sol";

contract AdditionalContent is Initializable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum ContentTypes {
        Pass,
        Asset,
        Other
    }

    /** 
    @dev Represents an additional content that will be transferred along with the sale.
    */
    struct AddCont {
        ContentTypes contentType;
        uint256 voucherCode;
        address creator;
    }

    IMarketPlace marketplace;

    /** @dev mapping addContId => Addtional Content */
    AddCont[] internal additionalContents;

    /** @dev mapping user address => [AdditionalContent] to fetch addtional content earned by a user */
    mapping(address => uint256[]) internal additionalContentForUser;

    /** @dev mapping Sale Id => [AdditionalContent] to add addtional content for sale */
    mapping(uint256 => uint256[]) internal additionalContentForSale;

    event CreatedAdditionalContent(
        uint256 indexed id,
        ContentTypes indexed _type,
        uint256 _additionalContentCode
    );

    event AddedAdditionalContentForSale(
        uint256 indexed _saleId,
        uint256[] _contentIds
    );

    event ClaimedAdditionalContent(
        uint256 indexed _saleId,
        uint256[] _contentIds,
        address _user
    );

    /**
    @dev Modifier to check whether caller is seller or admin.
     */
    modifier onlySellerOrAdmin(uint256 _saleId) {
        require(
            _msgSender() == marketplace.getSeller(_saleId) ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "AdditionalContent: !AUTHORIZED"
        );
        _;
    }

    function initialize(IMarketPlace _marketplace) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        marketplace = _marketplace;
    }

    function addAdditionalContent(
        ContentTypes _type,
        uint256 _additionalContentCode
    ) external returns (uint256 id) {
        AddCont memory ac = AddCont({
            contentType: _type,
            voucherCode: _additionalContentCode,
            creator: _msgSender()
        });
        additionalContents.push(ac);
        id = additionalContents.length;
        emit CreatedAdditionalContent(id, _type, _additionalContentCode);
    }

    function addAdditionalContentToSale(
        uint256 _saleId,
        uint256[] memory _addContIds
    ) external onlySellerOrAdmin(_saleId) returns (bool) {
        address sender = _msgSender();
        require(
            marketplace.getSeller(_saleId) == sender,
            "AdditionalContent: !AUTHORIZED"
        );
        uint256 idsLen = _addContIds.length;

        for (uint256 i = 0; i < idsLen; i++) {
            require(
                additionalContents[i].creator == sender,
                "AdditionalContent: !AUTHORIZED"
            );
        }
        additionalContentForSale[_saleId] = _addContIds;
        emit AddedAdditionalContentForSale(_saleId, _addContIds);
        return true;
    }

    function claimAdditionalContent(uint256 _saleId) external returns (bool) {
        address _user = _msgSender();        
        require(
            marketplace.getBuyer(_saleId) == _user,
            "AdditionalContent: !AUTHORIZED"
        );
        uint256[] memory _contentIds = additionalContentForSale[_saleId];
        additionalContentForUser[_user] = _contentIds;
        emit ClaimedAdditionalContent(_saleId, _contentIds, _user);
        return true;
    }

    function fetchAdditionalContent() external view returns (AddCont[] memory) {
        uint256[] memory _contentIds = additionalContentForUser[_msgSender()];
        uint256 numberOfAddConts = _contentIds.length;
        AddCont[] memory userAddContents = new AddCont[](numberOfAddConts);
        for (uint256 i = 0; i < numberOfAddConts; i++) {
            userAddContents[i] = additionalContents[_contentIds[i]];
        }
        return userAddContents;
    }
}
