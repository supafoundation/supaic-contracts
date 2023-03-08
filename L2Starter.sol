// SPDX-License-Identifier: UNLICENSED
//0xCF07021cf1575bbD5604EA11cBAF195e9B258cD2-testnet
  //ERC20 needs to register itself and give permission to these pods to mint.
  //Pods contract needs to be whitelisted by MP contract
//supa token address
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
interface DustContract{ 

function burn(uint amount) external ;
function mint(address to, uint256 amount) external;

    }
interface CardContract{
    function safeMint(address to, string memory cardSerial,uint cardlevel, uint cardVariation) external ;

}
    //card serial with level
/// @custom:security-contact contact@supa.foundation
contract L2Deck is  Pausable, AccessControl,  ReentrancyGuard {
        address public cardContractAddress;
        address public withdrawalAddress;

    using Counters for Counters.Counter;
        using ECDSA for bytes32;
  
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
    IERC20 private supaToken = IERC20(0x86A677e61cd7e2E7020F8D0c9f75AED099642d5a);
      mapping(uint=>Cards[]) public starterDeck;
     mapping(uint=>DeckInfo) public deckInfo;
     mapping(uint => Counters.Counter) public deckCounter;
    struct DeckInfo {
      uint price;
      uint promoqty;
      uint discount;
    }
    struct Cards {
      uint cardLevel;
      string cardSerial;
      uint cardVariation;
         }
    constructor(address _cardContractAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
     _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    cardContractAddress=_cardContractAddress;
        
    }
   
 function setCardContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    cardContractAddress = _addr;
   
  }
 function setSUPAContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    supaToken = IERC20(_addr);
   
  }
 function setWithdrawalAddress(address _addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
     
    withdrawalAddress = _addr;
   
  }

  function createL2Deck(uint deckserial,  Cards[] memory cards, uint price,uint promoqty, uint discount) public onlyRole(MINTER_ROLE) {
      //limited time.
         delete  starterDeck[deckserial];
         deckInfo[deckserial].price=price;
         deckInfo[deckserial].promoqty=promoqty;
         deckInfo[deckserial].discount=discount;
         delete starterDeck[deckserial];
          for(uint a=0; a<cards.length; a++){
              starterDeck[deckserial].push(cards[a]);
          }
      }
    // function mintL2Deck(uint deckserial) public nonReentrant {
    //   require(deckInfo[deckserial].price>0,"Deck does not exist");
    //     uint deckPrice;
    //    if(deckCounter[deckserial].current()<=deckInfo[deckserial].promoqty){
    //     deckPrice= deckInfo[deckserial].price*(100-deckInfo[deckserial].discount)/100;
    //    } else{
    //       deckPrice=deckInfo[deckserial].price;

    //    }
    //      require(supaToken.allowance(msg.sender,address(this)) >= deckPrice,  
    //      "Please make sure you have sufficient approved SUPA Token to purchase Level 2 Deck"); 
    //      deckCounter[deckserial].increment();
    //       CardContract m = CardContract(cardContractAddress);
    //       supaToken.transferFrom(msg.sender, address(this), deckPrice);   
    //        for(uint a=0; a<starterDeck[deckserial].length; a++){
    //         m.safeMint(msg.sender, starterDeck[deckserial][a].cardSerial, starterDeck[deckserial][a].cardLevel, starterDeck[deckserial][a].cardVariation);
    //       }

    // }

    function mintL2Deck(uint deckserial) public nonReentrant {
    // Determine the deck price based on the current promotion
    uint deckPrice = deckCounter[deckserial].current() <= deckInfo[deckserial].promoqty
        ? (deckInfo[deckserial].price * (100 - deckInfo[deckserial].discount)) / 100
        : deckInfo[deckserial].price;
    require(deckInfo[deckserial].price>0,'Invalid deck');
    // Check that the user has sufficient SUPA Token balance and allowance
    require(supaToken.balanceOf(msg.sender) >= deckPrice, "Insufficient SUPA Token balance");
    require(supaToken.allowance(msg.sender, address(this)) >= deckPrice, "Insufficient SUPA Token allowance");

    // Transfer the tokens to the contract and increment the deck counter
    supaToken.transferFrom(msg.sender, address(this), deckPrice);
    deckCounter[deckserial].increment();

    // Mint the NFTs using the CardContract
    CardContract m = CardContract(cardContractAddress);
    for (uint i = 0; i < starterDeck[deckserial].length; i++) {
        Cards memory card = starterDeck[deckserial][i];
        m.safeMint(msg.sender, card.cardSerial, card.cardLevel, card.cardVariation);
    }
}
function resetCounter(uint deckserial) public  onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        deckCounter[deckserial].reset();

    }
    function getDeckPrice(uint deckserial) public virtual view returns(uint,bool){
  
       if(deckCounter[deckserial].current()<=deckInfo[deckserial].promoqty){
        return ((deckInfo[deckserial].price*(100-deckInfo[deckserial].discount)/100), true);
       } else{
        return (deckInfo[deckserial].price,false);

       }

    }
       function withdraw() onlyRole(DEFAULT_ADMIN_ROLE) public payable returns(bool) {
        payable(withdrawalAddress).transfer(address(this).balance);
         supaToken.transfer(withdrawalAddress, supaToken.balanceOf(address(this)));
        return true;
        }

    //withdrawal
}