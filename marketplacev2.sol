// SPDX-License-Identifier: NONE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface IERC2981Royalties {
function royaltyInfo(uint256 _tokenId, uint256 _value) external view returns (address _receiver, uint256 _royaltyAmount);
}

contract NFTMarket is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
using CountersUpgradeable for CountersUpgradeable.Counter;
CountersUpgradeable.Counter public listingID;
CountersUpgradeable.Counter public removalID;

uint public maxBuy;
uint public maxWithdraw;

mapping(address => uint) public nftTypeID;
mapping(address => bool) public isContractActive;
mapping(address => mapping(uint => uint)) public itemID;
mapping(uint => uint) public tokenId;
mapping(address => bool) public hasSerial;
mapping(address => uint) public minimumCurrencyPrice;
mapping(uint => address) public lister;
mapping(uint => ItemInfo) public itemInfo;
mapping(uint => ItemInfo) public tokenIDRemoved;

bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

IERC20Upgradeable private supaToken;
address payable public withdrawalAddress;
address payable public contractOwner;
uint256 public listingPrice;

event itemListed(uint indexed itemId, uint price, address indexed lister);
event itemWithdrawn(uint indexed itemId, address indexed lister, uint removalID);
event itemSold(uint indexed itemId, uint price, address indexed buyer, address indexed lister, uint removalID);
event batchBuy(uint[] itemId, address indexed buyer);
event batchWithdraw(uint[] itemId, address indexed lister);
struct ItemInfo {
    uint itemPrice;
    address itemCurrency;
    uint tokenID;
    bool isListed;
    bool hasSerial;
    address itemContractAddress;
    address lister;
    uint nftTypeID;
    uint timestampListed;
    uint timestampSold;
    uint listingID;
}

function initialize(address _supaTokenAddress) public initializer {
    __AccessControl_init();
    __ReentrancyGuard_init();
    __ERC721Holder_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
    _setupRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);

    supaToken = IERC20Upgradeable(_supaTokenAddress);
    withdrawalAddress = payable(address(0));
    contractOwner = payable(address(0));
    listingPrice = 0.01 ether;
}

function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}



 function setListingType(address _contractAddress, bool _isContractActive, bool _hasSerial, uint _nftTypeID) public onlyRole(MINTER_ROLE) {
        nftTypeID[_contractAddress]=_nftTypeID;
        isContractActive[_contractAddress]=_isContractActive;
        hasSerial[_contractAddress]=_hasSerial;
    }

  function maxAmount(uint _maxBuy, uint _maxWithdraw) public onlyRole(MINTER_ROLE){
    maxBuy=_maxBuy;
    maxWithdraw=_maxWithdraw;
  }
function whitelistCurrency(address currency, uint minimumPrice)  public onlyRole(MINTER_ROLE){
        minimumCurrencyPrice[currency]=minimumPrice;
}
    function batchListNFT(  address _contractAddress,uint[] memory tokenID, uint price, address currency) public{
      require(tokenID.length<=maxWithdraw,"Max batch listing.");
        for(uint d=0; d<tokenID.length;d++){
          listNFT(_contractAddress, tokenID[d],price, currency);
        }
      
    }
function listNFT(address _contractAddress, uint tokenID, uint price, address currency) public nonReentrant{
require(minimumCurrencyPrice[currency]!=0,"Unsupported currency");
require(minimumCurrencyPrice[currency]<=price,"Listing price is too low");
require(isContractActive[_contractAddress]==true,"Listing for this item is inactive");
require(IERC721Upgradeable(_contractAddress).ownerOf(tokenID)==msg.sender,"You do not own this NFT");
 require(
             supaToken.allowance(msg.sender,address(this)) >= listingPrice,
            "0.01 SUPA is required for listing."
        );


  supaToken.transferFrom(msg.sender, address(this), listingPrice);
 IERC721Upgradeable(_contractAddress).transferFrom(msg.sender, address(this), tokenID);
        listingID.increment();
        uint256 itemId = listingID.current();
    
       itemInfo[itemId]=ItemInfo({itemPrice:price, itemCurrency:currency,tokenID:tokenID,  isListed:true, hasSerial:hasSerial[_contractAddress],itemContractAddress:_contractAddress,lister:msg.sender,nftTypeID:nftTypeID[_contractAddress], timestampListed:block.timestamp, timestampSold:0, listingID:listingID.current()});  
       emit itemListed(itemId, price,msg.sender);
       
        //emit event listed;
}

function withdrawNFT(uint itemId) public nonReentrant{
require(itemInfo[itemId].lister==msg.sender,"You do not own this NFT");
itemInfo[itemId].lister=address(this);
itemInfo[itemId].isListed=false;
IERC721Upgradeable(itemInfo[itemId].itemContractAddress).transferFrom( address(this),msg.sender, itemInfo[itemId].tokenID);
//emit event removal
      removalID.increment();
       tokenIDRemoved[removalID.current()]=itemInfo[itemId];
  emit itemWithdrawn(itemId, msg.sender,removalID.current());
}
function batchWithdrawNFT(uint[] memory itemId) public{
    require(itemId.length<=maxWithdraw);

 for(uint i=0; i<itemId.length; i++){
    withdrawNFT(itemId[i]);

  }

  emit batchWithdraw(itemId, msg.sender);
}
function batchBuyNFT(uint[] memory itemId) public{
  require(itemId.length<=maxBuy);
  for(uint i=0; i<itemId.length; i++){
    buyNFT(itemId[i]);

  }
emit batchBuy(itemId, msg.sender);
}
function batchPrice(uint[] memory itemId) public view returns(uint){
   require(itemId.length<=maxBuy);
   
    uint totalPrice;
  for(uint j=0; j<itemId.length;j++ ){
    require(itemInfo[itemId[j]].isListed==true,"Item no longer listed");

    totalPrice+=itemInfo[itemId[j]].itemPrice;
  }
  return totalPrice;
}
function buyNFT(uint itemId) public nonReentrant{
       IERC20Upgradeable  txnToken = IERC20Upgradeable(itemInfo[itemId].itemCurrency);
  
     require(
             txnToken.allowance(msg.sender,address(this)) >= itemInfo[itemId].itemPrice,
            "Please ensure you have approved this transaction"
        );
        address nftContract=itemInfo[itemId].itemContractAddress;
         if (checkRoyalties(nftContract)==true) {
        IERC2981Royalties royaltyChecker = IERC2981Royalties(nftContract);
        (address receiver, uint256 royalties)=royaltyChecker.royaltyInfo(itemInfo[itemId].tokenID,itemInfo[itemId].itemPrice);
       // txnToken.transferFrom(msg.sender,address(this),itemPrice[itemId])
        if(receiver!=address(0) && royalties!=0){
         txnToken.transferFrom(msg.sender, receiver, royalties);
         txnToken.transferFrom(msg.sender, itemInfo[itemId].lister, itemInfo[itemId].itemPrice-royalties);

        }else{
          txnToken.transferFrom(msg.sender, itemInfo[itemId].lister, itemInfo[itemId].itemPrice);

        }

        } else {
          txnToken.transferFrom(msg.sender, itemInfo[itemId].lister, itemInfo[itemId].itemPrice);

        }
      IERC721Upgradeable(nftContract).transferFrom(address(this), msg.sender, itemInfo[itemId].tokenID);

      itemInfo[itemId].isListed=false;
      itemInfo[itemId].timestampSold=block.timestamp;
        removalID.increment();
       tokenIDRemoved[removalID.current()]=itemInfo[itemId];
     emit itemSold(itemId, itemInfo[itemId].itemPrice,msg.sender,itemInfo[itemId].lister,removalID.current());

}
function withdraw(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
       IERC20Upgradeable  txnToken = IERC20Upgradeable(tokenAddress);
        txnToken.transfer(msg.sender,txnToken.balanceOf(address(this)));


}
function checkContractBalance(address tokenAddress) public view returns (uint){
  IERC20Upgradeable  txnToken = IERC20Upgradeable(tokenAddress);
  return txnToken.balanceOf(address(this));
}
  function checkRoyalties(address _contract) internal view returns (bool) {
    (bool success) = IERC165Upgradeable(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
    return success;
 }
}

