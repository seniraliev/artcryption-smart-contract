// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/ISingleNFT.sol";
import "contracts/interfaces/IMultiNFT.sol";
import "contracts/interfaces/IOwnershipCertificate.sol";
import "contracts/interfaces/ILicense.sol";

import "hardhat/console.sol";

contract Marketplace is Initializable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public PLATFORM_FEE_PERCENTAGE;
    uint256 public SECOND_SALE_ROYALTY_PERCENTAGE;

    uint256 public counter;

    address public admin;

    IERC20 public weth;
    ISingleNFT singleNFT;
    IMultiNFT multiNFT;
    IOwnershipCertificate ownershipCertificate;
    ILicense license;

    enum SaleType {
        FixedSale,
        EnglishAuction,
        DutchAuction
    }

    enum TokenTypes {
        ERC1155,
        ERC721
    }

    struct AssetToken {
        TokenTypes assetType;
        address seller;
        address creator;
        address tokenAddress;
        uint256 tokenId;
        uint256 quantity;
        uint256 price; // price in eth
        string uri;
        address[] stakeholders;
        uint256[] royaltySplit; // stakeholders[i] => royaltySplit[i]
    }

    struct SaleData {
        SaleType saleType;
        AssetToken assetToken;
        address buyer;
        bool available;
        bool lazyMint;
    }

    struct DutchAuctionData {
        uint256 startingPrice;
        uint256 startAt;
        uint256 expiresAt;
        uint256 discountRate;
    }

    struct EnglishAuctionData {
        address highestBidder;
        uint256 highestBid;
        uint256 startPrice;
        bool active;
        uint256 duration;
        uint256 expiresAt;
    }

    /** @dev mapping token Id => Sale Info */
    mapping(uint256 => SaleData) internal saleData;

    /** @dev mapping token Id => Dutch Auction Info */
    mapping(uint256 => DutchAuctionData) internal dutchAuctionData;

    /** @dev mapping token Id => English Auction Info */
    mapping(uint256 => EnglishAuctionData) internal englishAuctionData;

    /** @dev mapping token Address => token Id => Sale Id */
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        internal saleIdByAsset;

    event AssetListedForSale(
        uint256 indexed _saleId,
        address _tokenAddress,
        uint256 _tokenId,
        SaleType _saleType
    );
    event Sold(
        uint256 indexed _saleId,
        address _tokenAddress,
        uint256 _tokenId,
        address _seller,
        address _buyer
    );
    event Bid(uint256 indexed _saleId, uint256 _bid, address indexed _bidder);
    event StartAuction(uint256 indexed _saleId);
    event EndAuction(
        uint256 indexed _saleId,
        uint256 _bid,
        address indexed _bidder
    );
    event SalePaused(uint256 indexed _saleId);
    event SaleUnpaused(uint256 indexed _saleId);
    event AdminChanged(address indexed _admin, address indexed _caller);
    event FeeWithdrawal(
        address indexed _admin,
        uint256 _ethBal,
        uint256 _wethBal
    );
    event AddedURIForLazyMint(address indexed _seller, string _uri);
    event RoyaltiesUpdated(uint256 saleId);
    event PlatformFeePercentage(
        uint256 _platform_fee_percenage
    );
    event SecondSaleRoyaltyPercentage(
        uint256 _second_sale_royalty_percentage
    );

    error InvalidRequest();

    /**
    @dev Modifier to check whether msgSender is Owner
     */
    modifier onlyOwner(
        address tokenAddress,
        uint256 tokenId,
        TokenTypes tokenType,
        bool lazyMint,
        string memory uri
    ) {
        if (tokenAddress == address(0)) {
            require(lazyMint, "Marketplace: !LAZY_MINT");
        } else if (tokenType == TokenTypes.ERC1155) {
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

    /**
    @dev Modifier to check whether this contract has transfer approval.
     */
    modifier hasTransferApproval(
        TokenTypes tokenType,
        address tokenAddress,
        uint256 tokenId,
        address sender
    ) {
        if (tokenAddress != address(0)) {
            if (tokenType == TokenTypes.ERC721) {
                IERC721 tokenContract = IERC721(tokenAddress);
                require(
                    tokenAddress == address(0) ||
                        tokenContract.getApproved(tokenId) == address(this) ||
                        tokenContract.isApprovedForAll(sender, address(this)),
                    "token transfer not approved"
                );
            } else {
                IERC1155 tokenContract = IERC1155(tokenAddress);
                require(
                    tokenAddress == address(0) ||
                        tokenContract.isApprovedForAll(sender, address(this)),
                    "token transfer not approved"
                );
            }
        }
        _;
    }

    /**
    @dev Modifier to check whether caller is seller or admin.
     */
    modifier onlySellerOrAdmin(uint256 _saleId) {
        require(
            _msgSender() == saleData[_saleId].assetToken.seller ||
                hasRole(ADMIN_ROLE, _msgSender()),
            "Marketplace: !AUTHORIZED"
        );
        _;
    }

    function initialize(
        IERC20 _weth,
        ISingleNFT _singleNFT,
        IMultiNFT _multiNFT,
        IOwnershipCertificate _ownershipCertificate,
        ILicense _license,
        address _admin
    ) public initializer {
        weth = _weth;
        admin = _admin;
        singleNFT = _singleNFT;
        multiNFT = _multiNFT;
        ownershipCertificate = _ownershipCertificate;
        license = _license;
        PLATFORM_FEE_PERCENTAGE = 15;
        SECOND_SALE_ROYALTY_PERCENTAGE = 10;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /**
    @dev Function to add new Art to market.
    @param assetData - contains details of NFT. refer struct ArtData
     */
    function addAssetForFixedSale(
        AssetToken calldata assetData,
        bool lazyMint,
        string memory uri
    )
        external
        onlyOwner(
            assetData.tokenAddress,
            assetData.tokenId,
            assetData.assetType,
            lazyMint,
            uri
        )
        hasTransferApproval(
            assetData.assetType,
            assetData.tokenAddress,
            assetData.tokenId,
            _msgSender()
        )
        returns (uint256 saleId)
    {
        AssetToken calldata temp = assetData;
        saleId = _registerItemForSale(SaleType.FixedSale, temp, lazyMint, uri);
        emit AssetListedForSale(
            saleId,
            temp.tokenAddress,
            temp.tokenId,
            SaleType.FixedSale
        );
    }

    /**
    @dev Function to add new Art to market.
    @param assetData - contains details of NFT. refer struct ArtData
    @param auctionData - contains auction details
     */
    function addAssetForDutchAuction(
        AssetToken calldata assetData,
        DutchAuctionData calldata auctionData,
        bool lazyMint,
        string memory uri
    )
        external
        onlyOwner(
            assetData.tokenAddress,
            assetData.tokenId,
            assetData.assetType,
            lazyMint,
            uri
        )
        hasTransferApproval(
            assetData.assetType,
            assetData.tokenAddress,
            assetData.tokenId,
            _msgSender()
        )
        returns (uint256 saleId)
    {
        require(
            auctionData.startingPrice > 0,
            "Marketplace: start price should be greater than zero"
        );
        require(
            auctionData.discountRate > 0,
            "Marketplace: discount rate should be a positive value"
        );
        require(
            auctionData.startAt > block.timestamp,
            "Marketplace: start date should be greater than current time"
        );
        require(
            auctionData.expiresAt > auctionData.startAt,
            "Marketplace: end date should be greater than start date"
        );
        AssetToken calldata temp = assetData;
        saleId = _registerItemForSale(
            SaleType.DutchAuction,
            temp,
            lazyMint,
            uri
        );
        dutchAuctionData[saleId] = auctionData;
        emit AssetListedForSale(
            saleId,
            temp.tokenAddress,
            temp.tokenId,
            SaleType.DutchAuction
        );
    }

    /**
    @dev Function to add new Art to market for english auction.
    @param assetData - contains details of NFT. refer struct ArtData
    @param startPrice - base price for the auction
    @param duration - duration of the auction
     */
    function addAssetForEnglishAuction(
        AssetToken calldata assetData,
        uint256 startPrice,
        uint256 duration,
        bool lazyMint,
        string memory uri
    )
        external
        onlyOwner(
            assetData.tokenAddress,
            assetData.tokenId,
            assetData.assetType,
            lazyMint,
            uri
        )
        returns (uint256 saleId)
    {
        AssetToken calldata temp = assetData;
        saleId = _createEnglishAuction(
            temp,
            startPrice,
            duration,
            lazyMint,
            uri
        );
        emit AssetListedForSale(
            saleId,
            temp.tokenAddress,
            temp.tokenId,
            SaleType.EnglishAuction
        );
    }

    function _createEnglishAuction(
        AssetToken calldata assetData,
        uint256 _startPrice,
        uint256 _duration,
        bool lazyMint,
        string memory _uri
    )
        internal
        hasTransferApproval(
            assetData.assetType,
            assetData.tokenAddress,
            assetData.tokenId,
            _msgSender()
        )
        returns (uint256 saleId)
    {
        require(
            _startPrice > 0,
            "Marketplace: start price should be greater than zero"
        );
        require(
            _duration > 0,
            "Marketplace: discount rate should be a positive value"
        );

        saleId = _registerItemForSale(
            SaleType.EnglishAuction,
            assetData,
            lazyMint,
            _uri
        );
        englishAuctionData[saleId] = EnglishAuctionData({
            highestBidder: address(0),
            startPrice: _startPrice,
            highestBid: 0,
            active: false,
            duration: _duration,
            expiresAt: 0
        });
    }

    function pauseSale(uint256 _saleId) external onlySellerOrAdmin(_saleId) {
        saleData[_saleId].available = false;
        emit SalePaused(_saleId);
    }

    function unpauseSale(uint256 _saleId) external onlySellerOrAdmin(_saleId) {
        saleData[_saleId].available = true;
        emit SaleUnpaused(_saleId);
    }

    function startAuction(uint256 _saleId) external {
        SaleData memory sale = saleData[_saleId];
        require(
            sale.saleType == SaleType.EnglishAuction,
            "Marketplace: not allowed to place bids for this auction"
        );
        require(
            msg.sender == sale.assetToken.seller,
            "Marketplace: not allowed to start this auction"
        );
        require(
            !englishAuctionData[_saleId].active &&
                englishAuctionData[_saleId].expiresAt < block.timestamp,
            "Marketplace: Auction is in active now"
        );

        englishAuctionData[_saleId].active = true;
        englishAuctionData[_saleId].expiresAt =
            block.timestamp +
            englishAuctionData[_saleId].duration;

        emit StartAuction(_saleId);
    }

    function bid(uint256 _saleId, uint256 _amount) external payable {
        SaleData memory sale = saleData[_saleId];
        require(
            sale.saleType == SaleType.EnglishAuction,
            "Marketplace: not allowed to place bids for this auction"
        );
        require(
            englishAuctionData[_saleId].active,
            "Marketplace: Auction not active yet"
        );
        require(
            block.timestamp < englishAuctionData[_saleId].expiresAt,
            "Marketplace: Auction period is over"
        );
        if (msg.value == 0) {
            _fetchWETH(_amount);
        } else {
            require(
                msg.value > englishAuctionData[_saleId].highestBid,
                "value < highest"
            );
        }

        englishAuctionData[_saleId].highestBidder = _msgSender();
        englishAuctionData[_saleId].highestBid = _amount;

        address prevHighestBidder = _msgSender();
        uint256 prevHighestBid = _amount;

        weth.transfer(prevHighestBidder, prevHighestBid);

        emit Bid(_saleId, _amount, msg.sender);
    }

    function endAuction(uint256 _saleId) external returns (bool) {
        SaleData memory sale = saleData[_saleId];
        require(
            sale.saleType == SaleType.EnglishAuction,
            "Marketplace: place bids for this auction"
        );
        require(
            msg.sender == sale.assetToken.seller,
            "Marketplace: not allowed to end this auction"
        );
        require(
            block.timestamp < englishAuctionData[_saleId].expiresAt,
            "Marketplace: Auction period is over"
        );

        englishAuctionData[_saleId].active = false;
        englishAuctionData[_saleId].expiresAt = block.timestamp;
    
        if (englishAuctionData[_saleId].highestBidder != address(0)) {
            if (sale.assetToken.assetType == TokenTypes.ERC721) {
                IERC721(sale.assetToken.tokenAddress).safeTransferFrom(
                    sale.assetToken.seller,
                    englishAuctionData[_saleId].highestBidder,
                    sale.assetToken.tokenId
                );
            } else {
                IERC1155(sale.assetToken.tokenAddress).safeTransferFrom(
                    sale.assetToken.seller,
                    englishAuctionData[_saleId].highestBidder,
                    sale.assetToken.tokenId,
                    sale.assetToken.quantity,
                    bytes("")
                );
            }
            _splitAmount(
                sale.assetToken,
                englishAuctionData[_saleId].highestBidder,
                englishAuctionData[_saleId].highestBid,
                true
            );
        }

        emit EndAuction(
            _saleId,
            englishAuctionData[_saleId].highestBid,
            englishAuctionData[_saleId].highestBidder
        );
        return true;
    }

    function buy(uint256 _saleId, bool _buyNow)
        external
        payable
        returns (bool success)
    {
        SaleData memory sale = saleData[_saleId];
        require(
            sale.available && sale.assetToken.seller != address(0),
            "Marketplace: Currently not available for sale"
        );

        saleData[_saleId].available = false;
        saleData[_saleId].assetToken.seller = address(0);

        uint256 price;
        if (_buyNow || sale.saleType == SaleType.FixedSale) {
            price = sale.assetToken.price;
        } else if (sale.saleType == SaleType.DutchAuction) {
            require(
                dutchAuctionData[_saleId].startAt <= block.timestamp,
                "Marketplace: Auction not started yet"
            );
            require(
                dutchAuctionData[_saleId].expiresAt >= block.timestamp,
                "Marketplace: Auction period is over"
            );
            price = _getCurrentPrice(
                dutchAuctionData[_saleId].startingPrice,
                dutchAuctionData[_saleId].startAt,
                dutchAuctionData[_saleId].discountRate
            );
        } else {
            // Raised when there is a buy request for english auction
            revert InvalidRequest();
        }

        if (msg.value == 0) {
            _fetchWETH(price);
            _splitAmount(sale.assetToken, _msgSender(), price, true);
            _executeSale(sale.assetToken, _saleId);
        } else if (msg.value >= price) {
            uint256 remainder = msg.value - price;
            if (remainder > 0) {
                payable(_msgSender()).transfer(remainder);
            }
            _splitAmount(sale.assetToken, address(this), price, false);
            _executeSale(sale.assetToken, _saleId);
        }

        return true;
    }

    function setRoyaltySplit(
        uint256 _saleId,
        address[] memory stakeholders,
        uint256[] memory royaltySplit
    ) external {
        SaleData memory sale = saleData[_saleId];
        require(sale.assetToken.creator == _msgSender());
        require(royaltySplit.length == stakeholders.length);
        require(
            _verifyRoyaltySplit(royaltySplit),
            "Marketplace: Invalid values for royalty split"
        );
        saleData[_saleId].assetToken.stakeholders = stakeholders;
        saleData[_saleId].assetToken.royaltySplit = royaltySplit;
        emit RoyaltiesUpdated(_saleId);
    }

    function withdrawAllFee() external onlyRole(ADMIN_ROLE) returns (bool) {
        uint256 ethBal = address(this).balance;
        uint256 wethBal = weth.balanceOf(address(this));
        if (ethBal > 0) {
            payable(admin).transfer(ethBal);
        }

        if (wethBal > 0) {
            weth.transfer(admin, wethBal);
        }

        emit FeeWithdrawal(admin, ethBal, wethBal);
        return true;
    }

    function setPlatformFeePercentage(
        uint256 _platform_fee_percenage
    ) external onlyRole(ADMIN_ROLE) returns (bool) {
        PLATFORM_FEE_PERCENTAGE = _platform_fee_percenage;        

        emit PlatformFeePercentage(
            _platform_fee_percenage
        );
        return true;
    }

    function setSecondSaleRoyaltyPercentage(
        uint256 _second_sale_royalty_percentage
    ) external onlyRole(ADMIN_ROLE) returns (bool) {
        SECOND_SALE_ROYALTY_PERCENTAGE = _second_sale_royalty_percentage;

        emit SecondSaleRoyaltyPercentage(
            _second_sale_royalty_percentage
        );
        return true;
    }

    function changeAdmin(address _admin)
        external
        onlyRole(ADMIN_ROLE)
        returns (bool)
    {
        require(
            _admin != address(0),
            "Marketplace: admin address cannot be null"
        );
        admin = _admin;
        emit AdminChanged(_admin, _msgSender());
        return true;
    }

    function getSeller(uint256 _saleId) external view returns (address) {
        return saleData[_saleId].assetToken.seller;
    }

    function getBuyer(uint256 _saleId) external view returns (address _buyer) {
        _buyer = saleData[_saleId].buyer;
        require(_buyer != address(0), "Marketplace: Asset yet to be sold");
    }

    function _registerItemForSale(
        SaleType saleType,
        AssetToken calldata assetData,
        bool lazyMint,
        string memory uri
    ) internal returns (uint256 saleId) {
        counter++;
        saleId = (lazyMint ||
            saleIdByAsset[_msgSender()][assetData.tokenAddress][
                assetData.tokenId
            ] ==
            0)
            ? counter
            : saleIdByAsset[_msgSender()][assetData.tokenAddress][
                assetData.tokenId
            ];
        address[] memory stakeholders = new address[](1);
        stakeholders[0] = _msgSender();

        uint256[] memory royaltySplit = new uint256[](1);
        royaltySplit[0] = 100;

        AssetToken memory asset = AssetToken({
            assetType: assetData.assetType,
            seller: _msgSender(),
            creator: assetData.creator,
            tokenAddress: assetData.tokenAddress,
            tokenId: lazyMint ? 0 : assetData.tokenId,
            quantity: assetData.quantity,
            price: assetData.price,
            uri: uri,
            stakeholders: stakeholders,
            royaltySplit: royaltySplit
        });

        saleData[saleId] = SaleData({
            saleType: saleType,
            assetToken: asset,
            available: true,
            buyer: address(0),
            lazyMint: lazyMint
        });

        if (!lazyMint) {
            saleIdByAsset[_msgSender()][assetData.tokenAddress][
                assetData.tokenId
            ] = saleId;
        }
    }

    function _fetchWETH(uint256 price) internal {
        require(
            weth.balanceOf(_msgSender()) > price,
            "Marketplace: Insufficient Balance"
        );
        require(
            weth.allowance(_msgSender(), address(this)) >= price,
            "Marketplace: Insufficient allowance to fetch funds"
        );
        weth.approve(_msgSender(), price);
    }

    function _getCurrentPrice(
        uint256 startingPrice,
        uint256 startAt,
        uint256 discountRate
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startAt;
        uint256 discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function _splitAmount(
        AssetToken memory _asset,
        address sender,
        uint256 _amount,
        bool paidAsToken
    ) internal {
        uint256 _platformFee = (PLATFORM_FEE_PERCENTAGE * _amount) / 100;
        uint256 _priceWithoutFee = (_amount) - _platformFee;
        uint256 _royaltyAmount = (_asset.seller == _asset.creator)
            ? _priceWithoutFee
            : (SECOND_SALE_ROYALTY_PERCENTAGE * _amount) / 100;
        address[] memory _creators = _asset.stakeholders;
        uint256[] memory _royaltySplit = _asset.royaltySplit;

        uint256 creatorsLength = _creators.length;
        uint256 _remainingAmount = (_royaltyAmount == _priceWithoutFee)
            ? 0
            : _priceWithoutFee - _royaltyAmount;
        uint256 _shareAmount;
        if (paidAsToken) {
            for (uint256 i = 0; i < creatorsLength; i++) {
                _shareAmount = (_royaltySplit[i] * _royaltyAmount) / 100;
                uint256 _value = _shareAmount;
                weth.transferFrom(sender, _creators[i], _value);
            }
            if (_remainingAmount > 0) {
                weth.transferFrom(sender, _asset.seller, _remainingAmount);
            }
        } else {
            for (uint256 i = 0; i < creatorsLength; i++) {
                _shareAmount = (_royaltySplit[i] * _royaltyAmount) / 100;
                uint256 _value = _shareAmount;
                payable(_creators[i]).transfer(_value);
            }
            if (_remainingAmount > 0) {
                payable(_asset.seller).transfer(_remainingAmount);
            }
        }
    }

    function _executeSale(AssetToken memory _asset, uint256 _saleId) internal {
        uint256 tokenId;
        if (saleData[_saleId].lazyMint) {
            if (saleData[_saleId].assetToken.assetType == TokenTypes.ERC721) {
                tokenId = singleNFT.create(_msgSender(), _asset.uri);
            } else {
                tokenId = multiNFT.create(
                    _msgSender(),
                    saleData[_saleId].assetToken.quantity,
                    _asset.uri,
                    bytes("")
                );
            }
            saleData[_saleId].assetToken.tokenId = tokenId;
        } else {
            tokenId = _asset.tokenId;
            _asset.assetType == TokenTypes.ERC721
                ? IERC721(_asset.tokenAddress).transferFrom(
                    _asset.seller,
                    _msgSender(),
                    tokenId
                )
                : IERC1155(_asset.tokenAddress).safeTransferFrom(
                    _asset.seller,
                    _msgSender(),
                    tokenId,
                    _asset.quantity,
                    bytes("")
                );
        }
        saleData[_saleId].buyer = _msgSender();
        ownershipCertificate.grantCertificate(
            _asset.tokenAddress,
            tokenId,
            _asset.creator,
            _asset.seller,
            _msgSender(),
            _asset.uri
        );
        emit Sold(
            _saleId,
            _asset.tokenAddress,
            tokenId,
            _asset.seller,
            _msgSender()
        );
    }

    function _verifyRoyaltySplit(uint256[] memory _royaltySplit)
        internal
        pure
        returns (bool valid)
    {
        uint256 len = _royaltySplit.length;
        uint256 sum = 0;
        for (uint256 i = 0; i < len; i++) {
            sum = sum + _royaltySplit[i];
        }
        valid = (sum == 100);
    }
}
