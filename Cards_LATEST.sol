// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

interface DustContract{ 

function burn(uint amount) external ;
function mint(address to, uint256 amount) external;

    }
    //card serial with level
/// @custom:security-contact contact@supa.foundation
contract SUPATCG is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable, ERC721Royalty,ReentrancyGuard {
    using Counters for Counters.Counter;
    string private base = "https://bucket.supa.foundation/cards/json/";
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
      bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");
    Counters.Counter private _tokenIdCounter;
 event mintSuccessful(uint256 tokenId);  
  event mintedRewards(bool status);  

 event mintCardsFromPodSuccessful(Cards[] cardList);
 event cardUpgradeSuccessful(uint tokenId, uint cardLevel);
 event mintCardsSpecialDeck(SpecialCards[] cardList);
 event mintCardsStarterDeck(Cards[] cardList,uint color, uint organism);
  event dustedCardSuccessful(uint256 tokenId);  
        mapping(uint => string) public serialForCard;
        mapping(string=>uint) public cardSerialRarity;
        mapping(uint=>uint) public cardLevel;
         mapping(uint=>uint) public variationForCard;
    mapping(address=>mapping(uint=>uint)) public deckPrice;
       mapping(string=>address) public cardSerialContractAddress;
       mapping(uint=>mapping(uint=>uint)) public requiredDust;
       mapping(uint=>mapping(uint=>Cards[])) public starterDeck;
       mapping(uint=>SpecialCards[]) public specialDeck;
       mapping(uint=>uint) public rarityForCard;
       mapping(address=>mapping(uint=>bool)) public claimedStarterDeck;
        mapping(address=>uint) public backendNonce;
        mapping(string=>bool) public backendReceipt;
            address public recipient;

       struct Cards {
      uint cardLevel;
      string cardSerial;
      uint cardVariation;
         }
         struct SpecialCards {
      uint cardLevel;
      string cardSerial;
      uint cardVariation;
         }
    constructor() ERC721("SUPA Foundation: Internal Conflict Card", "SUPATCG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);    
        _setDefaultRoyalty(msg.sender, 150);

    }
    function _baseURI() internal view override returns (string memory) {
    return base;
    }
  function setBaseURI(string memory _base) public onlyRole(MINTER_ROLE) {
     
    base = _base;
   
  }
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
        function addCardToCollection(string memory cardSerial, uint rarity, address cardSerialContractAddr) public  onlyRole(MINTER_ROLE) returns(bool){
            cardSerialRarity[cardSerial]=rarity;
            cardSerialContractAddress[cardSerial]=cardSerialContractAddr;
            return true;

        }
     function mintCardsFromPack(address receiver,Cards[] memory cardsToMint) public onlyRole(MINTER_ROLE) nonReentrant returns (bool success){
      for(uint j=0; j<cardsToMint.length; j++){

            _tokenIdCounter.increment();

         
        _safeMint(receiver, _tokenIdCounter.current());
        cardLevel[_tokenIdCounter.current()]=cardsToMint[j].cardLevel;
        serialForCard[_tokenIdCounter.current()]=cardsToMint[j].cardSerial;
        rarityForCard[_tokenIdCounter.current()]=cardSerialRarity[cardsToMint[j].cardSerial];
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(cardsToMint[j].cardSerial,'-',Strings.toString(cardsToMint[j].cardLevel),'-',Strings.toString(cardsToMint[j].cardVariation), '.json')));

      }
        emit mintCardsFromPodSuccessful(cardsToMint);
         return true;
    }
    
      function mintFromDust(string memory dustSerial) public payable  nonReentrant returns (bool success){
         IERC20  cardDust = IERC20(cardSerialContractAddress[dustSerial]);
        require(
          cardDust.allowance(msg.sender,address(this)) >= requiredDust[1][cardSerialRarity[dustSerial]],
            "Please make sure you have sufficient approved level 0 cards to create a level 1 card"
          ); 
          require(cardSerialContractAddress[dustSerial]!=address(0),"Invalid Card");
          cardDust.transferFrom(msg.sender, address(this), requiredDust[1][cardSerialRarity[dustSerial]]); 
          DustContract dustToBurn= DustContract(cardSerialContractAddress[dustSerial]);
            dustToBurn.burn(requiredDust[1][cardSerialRarity[dustSerial]]); 
                 _tokenIdCounter.increment();

       
         
        _safeMint(msg.sender, _tokenIdCounter.current());
               cardLevel[_tokenIdCounter.current()]=1;
        serialForCard[_tokenIdCounter.current()]=dustSerial;
        variationForCard[_tokenIdCounter.current()]=0;
        rarityForCard[_tokenIdCounter.current()]=cardSerialRarity[dustSerial];
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(dustSerial,'-1-0', '.json')));

        
         emit mintSuccessful(_tokenIdCounter.current());
         return true;
    }


   
        function levelUpFromDust(uint _tokenID) public payable nonReentrant returns(bool success){
            require(ownerOf(_tokenID)==msg.sender, "You do not own this Card");
       
            IERC20 cardDust = IERC20(cardSerialContractAddress[serialForCard[_tokenID]]);

            require( cardLevel[_tokenID]>=1 &&  cardLevel[_tokenID]<5,"Invalid level for card");

            require(
          cardDust.allowance(msg.sender,address(this)) >= requiredDust[cardLevel[_tokenID]+1][rarityForCard[_tokenID]],
            "Please make sure you have sufficient approved level 0 cards to upgrade your card"
          ); 
           cardDust.transferFrom(msg.sender, address(this),requiredDust[cardLevel[_tokenID]+1][rarityForCard[_tokenID]]); 
                DustContract dustToBurn= DustContract(cardSerialContractAddress[serialForCard[_tokenID]]);
         
            dustToBurn.burn(requiredDust[cardLevel[_tokenID]+1][rarityForCard[_tokenID]]); 
            cardLevel[_tokenID]++;
        _setTokenURI(_tokenID, string(abi.encodePacked(serialForCard[_tokenID],'-',Strings.toString(cardLevel[_tokenID]),'-',Strings.toString(variationForCard[_tokenID]), '.json')));
            emit cardUpgradeSuccessful(_tokenID,cardLevel[_tokenID]);
            return true;
           
        }
    
     function createStarterDeck(uint color, uint organism, Cards[] memory cards) public onlyRole(MINTER_ROLE) {
         delete  starterDeck[color][organism];
          for(uint a=0; a<cards.length; a++){
              starterDeck[color][organism].push(cards[a]);
          }
      }
      //add disable function
    function addSpecialDeck(uint deckSerial, SpecialCards[] memory cards,uint _deckPrice, address paymentMethod) public onlyRole(DEFAULT_ADMIN_ROLE) {
        deckPrice[paymentMethod][deckSerial]=_deckPrice;
        delete specialDeck[deckSerial];
        for(uint d=0; d<cards.length; d++){

            specialDeck[deckSerial].push(cards[d]);
        }
    }
    function mintSpecialDeck(uint deckSerial,address paymentMethod) public nonReentrant returns(bool success){
           IERC20  scpay = IERC20(paymentMethod);
        require(
          scpay.allowance(msg.sender,recipient) >= deckPrice[paymentMethod][deckSerial],
            "Please ensure you have approved the required amount to mint Special Deck"
          ); 
            scpay.transferFrom(msg.sender, recipient, deckPrice[paymentMethod][deckSerial]); 

        for(uint i=0; i<specialDeck[deckSerial].length; i++){
                    safeMintStarterDeck(msg.sender,specialDeck[deckSerial][i].cardSerial,specialDeck[deckSerial][i].cardLevel,specialDeck[deckSerial][i].cardVariation);
                }
           emit mintCardsSpecialDeck(specialDeck[deckSerial]);

     }
     function backendMintSpecialDeck(uint deckSerial, address to, string memory receipt, uint nonce) public  onlyRole(MINTER_ROLE)  nonReentrant returns(bool success){
          require(backendNonce[to]<nonce && backendReceipt[receipt]==false,"Already claimed");
            backendNonce[to]=nonce;
            backendReceipt[receipt]=true;
           for(uint i=0; i<specialDeck[deckSerial].length; i++){
            safeMintStarterDeck(to,specialDeck[deckSerial][i].cardSerial,specialDeck[deckSerial][i].cardLevel,specialDeck[deckSerial][i].cardVariation);
        }
                   emit mintCardsSpecialDeck(specialDeck[deckSerial]);

    }
    // function mintStarterDeck(uint color, uint organism) public nonReentrant returns  nonReentrant(bool success){
    //            require ((organism==0 || organism==1) && color>=0 && color<7,"Invalid selection");
    //     require(claimedStarterDeck[msg.sender][organism]==false,"Already claimed starter deck");
    //     for(uint i=0; i<starterDeck[color][organism].length; i++){
    //         safeMintStarterDeck(msg.sender,starterDeck[color][organism][i].cardSerial,starterDeck[color][organism][i].cardLevel);
    //     }
    //     claimedStarterDeck[msg.sender][organism]=true;
    //    emit mintCardsStarterDeck(starterDeck[color][organism],color,organism);

    //     return true;
    // }
       function mintStarterDeck(uint color, uint organism, address playerAddress)  public onlyRole(MINTER_ROLE) nonReentrant returns(bool success){
               require ((organism==0 || organism==1) && color>=0 && color<7,"Invalid selection");
        require(claimedStarterDeck[playerAddress][organism]==false,"Already claimed starter deck");
        for(uint i=0; i<starterDeck[color][organism].length; i++){
            safeMintStarterDeck(playerAddress,starterDeck[color][organism][i].cardSerial,starterDeck[color][organism][i].cardLevel,starterDeck[color][organism][i].cardVariation);
        }
        claimedStarterDeck[playerAddress][organism]=true;
       emit mintCardsStarterDeck(starterDeck[color][organism],color,organism);

        return true;
    }
    function setRequiredDust(uint level, uint rarity, uint amount) public onlyRole(MINTER_ROLE) {
            requiredDust[level][rarity]=amount;
    }
       function changeRecipient(address _recipient) public onlyRole(AUTHORIZED_ROLE) returns(bool){
      recipient=payable(_recipient);
      return true;
  }  
    function cardToDust(uint _tokenID) public nonReentrant returns(bool success){
     require(ownerOf(_tokenID)==msg.sender, "Not Allowed");
     require(cardLevel[_tokenID]>=2,"Card has to be at least level 2");
        uint l=0;
        for(uint k=cardLevel[_tokenID]; k>0; k--){
            l+=requiredDust[k][rarityForCard[_tokenID]];
        }
    DustContract tokenToMint= DustContract(cardSerialContractAddress[serialForCard[_tokenID]]);
        _burn(_tokenID);
        tokenToMint.mint(msg.sender,l/2);
        emit dustedCardSuccessful(_tokenID);
    return true;
    }
    function safeMint(address to, string memory cardSerial,uint cardlevel, uint variation) public onlyRole(MINTER_ROLE) {
        _tokenIdCounter.increment();    
        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(to, tokenId);
         cardLevel[_tokenIdCounter.current()]=cardlevel;
        serialForCard[_tokenIdCounter.current()]=cardSerial;
        rarityForCard[_tokenIdCounter.current()]=cardSerialRarity[cardSerial];
        variationForCard[_tokenIdCounter.current()]=variation;

        
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(cardSerial,'-',Strings.toString(cardlevel),'-',Strings.toString(variation), '.json')));

    }
        function mintNFTReward(string memory cardSerialWithLevelAndVariation, address to, uint amount,uint cardlevel)  public onlyRole(MINTER_ROLE){
        string memory cardSerial=substring(cardSerialWithLevelAndVariation,0,15);
        uint variation=convertString(substring(cardSerialWithLevelAndVariation,18,19));
        require(keccak256(bytes(substring(cardSerialWithLevelAndVariation,16,17)))==keccak256(bytes(Strings.toString(cardlevel))),"Card level does not match card serial");
        for(uint t=0; t<amount; t++){
          _tokenIdCounter.increment();    
        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(to, tokenId);
         cardLevel[_tokenIdCounter.current()]=cardlevel;
        serialForCard[_tokenIdCounter.current()]=cardSerial;
        rarityForCard[_tokenIdCounter.current()]=cardSerialRarity[cardSerial];
         variationForCard[_tokenIdCounter.current()]=variation;

        
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(cardSerialWithLevelAndVariation, '.json')));


        }
               emit mintedRewards(true);

        }
      function safeMintStarterDeck(address to, string memory cardSerial,uint cardlevel,uint variation) private  {
        _tokenIdCounter.increment();    
                uint256 tokenId = _tokenIdCounter.current();

        _safeMint(to, tokenId);
         cardLevel[_tokenIdCounter.current()]=cardlevel;
        serialForCard[_tokenIdCounter.current()]=cardSerial;
        rarityForCard[_tokenIdCounter.current()]=cardSerialRarity[cardSerial];
         variationForCard[_tokenIdCounter.current()]=variation;

        
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(cardSerial,'-',Strings.toString(cardlevel),'-',Strings.toString(variation), '.json')));

    }
 
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.
  function setRoyalties(address recipient, uint96 val) public onlyRole(DEFAULT_ADMIN_ROLE){
        _setDefaultRoyalty(recipient, val);
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty,ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory ) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex-startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty,AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
     function numberFromAscII(bytes1 b) private pure returns (uint8 res) {
        if (b>="0" && b<="9") {
            return uint8(b) - uint8(bytes1("0"));
        } else if (b>="A" && b<="F") {
            return 10 + uint8(b) - uint8(bytes1("A"));
        } else if (b>="a" && b<="f") {
            return 10 + uint8(b) - uint8(bytes1("a"));
        }
        return uint8(b); // or return error ... 
    }

  function convertString(string memory str) public pure returns (uint256 value) {
    bytes memory b = bytes(str);
    uint256 number = 0;
    uint i = 0;
    while (i < b.length && b[i] == '0') {
        i++;
    }
    for (; i < b.length; i++) {
        number = number << 4;
        number |= numberFromAscII(b[i]);
    }
    return number;
}
   
}