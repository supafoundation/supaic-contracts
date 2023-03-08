// SPDX-License-Identifier: UNLICENSED
//0xCF07021cf1575bbD5604EA11cBAF195e9B258cD2-testnet
  //ERC20 needs to register itself and give permission to these pods to mint.
  //Pods contract needs to be whitelisted by MP contract
//supa token address
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
pragma solidity ^0.8.6;

interface DustContract{ 

function burn(uint amount) external ;
function mint(address to, uint256 amount) external;

    }
interface MPContract{
 function updateWL(int RDnew, int GRnew, int BKnew, int BUnew, int WHnew, int ORnew, int PRnew, address playerAddress) external;

}
    //card serial with level
/// @custom:security-contact contact@supa.foundation
contract DustPods is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable, ERC721Royalty, ReentrancyGuard {
    using Counters for Counters.Counter;
        using ECDSA for bytes32;
    string private base = "https://bucket.supa.foundation/pods/json/";
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
    IERC20 private supaToken = IERC20(0x86A677e61cd7e2E7020F8D0c9f75AED099642d5a);

    Counters.Counter private _tokenIdCounter;
 event mintSuccessful(uint256 tokenId);  
  event mintDustComplete(address walletAddress);  
    event mintDustSuccessful(address dustContractAddress, uint amount);
      mapping(uint=>bool) public releaseExists;

       struct Slot {
      uint rate;
      uint rarity;
         }
        struct DustAllocation{
            uint rate;
            uint amount;
        }
         struct Dust {
      string dustSerial;
      uint dustRarity;
         }
        mapping(string=>mapping(uint=>Dust[])) public podDust;

        mapping(uint=>mapping(uint=>mapping(uint=>Slot[]))) public individualSlotRarity;

    struct Pod{
        uint release;
        uint rarity;
        uint color;
        uint organism;
    }
        address public withdrawalAddress;

        address public mpContractAddress;
        uint expiryDuration=300;
        mapping(uint=>uint) public podSUPAPrice;
        mapping(uint=>int) public podMPPrice;
        mapping(uint=>uint) public podRelease;
        mapping(uint=>Pod) public podInfo;
        mapping(uint=>mapping(uint=>address)) public whitelistedForContract;
        mapping(uint=>DustAllocation[]) public dustToGiveFromPodSlot;
        mapping(string=>address) public dustContractAddress;
    constructor(address _mpContractAddress) ERC721("SUPA Foundation: Internal Conflict Pods", "SUPAPODS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
     _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    mpContractAddress=_mpContractAddress;
    _setDefaultRoyalty(msg.sender, 150);
        
    }
    function _baseURI() internal view override returns (string memory) {
    return base;
    }
  function setBaseURI(string memory _base) public onlyRole(MINTER_ROLE) {
     
    base = _base;
   
  }
  function setMPContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    mpContractAddress = _addr;
   
  }
 function setSUPAContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    supaToken = IERC20(_addr);
   
  }

   function setExpiryDuration(uint _exp) public onlyRole(MINTER_ROLE) {
     
    expiryDuration = _exp;
   
  }
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function withdraw() onlyRole(DEFAULT_ADMIN_ROLE) public payable returns(bool) {
        payable(withdrawalAddress).transfer(address(this).balance);
         supaToken.transfer(withdrawalAddress, supaToken.balanceOf(address(this)));
        return true;
        }

     function setWithdrawalAddress(address _addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
     
    withdrawalAddress = _addr;
   
  }

    function setDustContractAddress(string memory _dustSerial, address _dustContractAddress) public onlyRole(MINTER_ROLE) returns(bool){
        dustContractAddress[_dustSerial]=_dustContractAddress;
        return true;
    }

    function getWhitelistedForContract(uint release, uint rarity) public view returns(address){
        return  whitelistedForContract[release][rarity];
    }
    function setPodCharacteristics(uint release, uint rarity, Slot[] calldata slot1, Slot[] calldata slot2,Slot[] calldata slot3,int MPPrice, uint SUPAPrice, address _whitelistedForContract) public onlyRole(MINTER_ROLE) returns(bool){
       whitelistedForContract[release][rarity]=_whitelistedForContract;
        releaseExists[release]=true;
       delete individualSlotRarity[release][rarity][0];
        delete individualSlotRarity[release][rarity][1];
         delete individualSlotRarity[release][rarity][2];
        for(uint h=0; h<slot1.length;h++){
          individualSlotRarity[release][rarity][0].push(slot1[h]);

        }
         for(uint b=0; b<slot2.length;b++){
        individualSlotRarity[release][rarity][1].push(slot2[b]);
        

        }
         for(uint c=0; c<slot3.length;c++){
             
        individualSlotRarity[release][rarity][2].push(slot3[c]);

        }

        podSUPAPrice[rarity]=SUPAPrice;
        podMPPrice[rarity]=MPPrice;
        return true;
    }
    function setRarityDustAmount(uint slotRarity, DustAllocation[] calldata dustAllocation)public onlyRole(MINTER_ROLE) returns(bool){
         delete dustToGiveFromPodSlot[slotRarity];
      
         for(uint g=0; g<dustAllocation.length;g++){
       
        dustToGiveFromPodSlot[slotRarity].push(dustAllocation[g]);

        }
        return true;
    }
  
   function setRoyalties(address recipient, uint96 val) public onlyRole(DEFAULT_ADMIN_ROLE){
        _setDefaultRoyalty(recipient, val);
    }



 function verifySignature(bytes memory hashBytes, bytes memory sig) internal virtual returns (bool) {
       
       return hasRole(SIGN_ROLE, keccak256(hashBytes)
        .toEthSignedMessageHash()
        .recover(sig));
    }
   function setSpecs(uint release, uint rarity, uint color, uint organism, Dust[] calldata dust) public onlyRole(MINTER_ROLE) {
       string memory internalSerial=string(abi.encodePacked(Strings.toString(release),"-",Strings.toString(rarity),"-",Strings.toString(color),"-",Strings.toString(organism)));
                delete podDust[internalSerial][0];
                delete podDust[internalSerial][1];
                delete podDust[internalSerial][2];
                delete podDust[internalSerial][3];


       for(uint i=0; i<dust.length; i++){

       podDust[internalSerial][dust[i].dustRarity].push(dust[i]);

       }

   }

    function mintPod(uint release, uint rarity, uint color, uint organism) public nonReentrant returns(bool){
        require((organism==0 || organism==1) && rarity>=0 && rarity<=4 && color>=0 && color<=6 && releaseExists[release]==true,"Invalid input");
            if(podSUPAPrice[rarity]>0){
            require(
          supaToken.allowance(msg.sender,address(this)) >= podSUPAPrice[rarity],
            "Please make sure you have sufficient approved SUPA Token to purchase NFT"
          ); 
         
          supaToken.transferFrom(msg.sender, address(this), podSUPAPrice[rarity]);   

            }
            
         MPContract mp=MPContract(mpContractAddress);
         if(color==0){
         mp.updateWL(-podMPPrice[rarity],0,0,0,0,0,0,msg.sender);

         }else if(color==1){
         mp.updateWL(0,-podMPPrice[rarity],0,0,0,0,0,msg.sender);
         }else if(color==2){
         mp.updateWL(0,0,-podMPPrice[rarity],0,0,0,0,msg.sender);
         }else if(color==3){
         mp.updateWL(0,0,0,-podMPPrice[rarity],0,0,0,msg.sender);
         }else if(color==4){
         mp.updateWL(0,0,0,0,-podMPPrice[rarity],0,0,msg.sender);
         }else if(color==5){
         mp.updateWL(0,0,0,0,0,-podMPPrice[rarity],0,msg.sender);
         }else {
         mp.updateWL(0,0,0,0,0,0,-podMPPrice[rarity],msg.sender);
         }

       string memory podSerial=string(abi.encodePacked(Strings.toString(release),"-",Strings.toString(rarity),"-",Strings.toString(color),"-",Strings.toString(organism)));
                _tokenIdCounter.increment();    
                uint256 tokenId = _tokenIdCounter.current();

        _safeMint(msg.sender, tokenId);
        podInfo[tokenId]=Pod({release:release, rarity:rarity, color:color, organism:organism});     
         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(podSerial, '.json')));
      emit mintSuccessful(_tokenIdCounter.current());
    
    return true;
    }
         function getPodInfo(uint tokenId) public view returns(uint, uint, uint, uint){

             return (podInfo[tokenId].release, podInfo[tokenId].rarity, podInfo[tokenId].color, podInfo[tokenId].organism);
         }
     function mintDust(string memory hash, uint timestamp, bytes memory sig, uint tokenID) public nonReentrant returns (bool){
                require(timestamp+expiryDuration>block.timestamp);
                 require(ownerOf(tokenID)==msg.sender,"You do not own this pod");
        
        bytes memory hashBytes=abi.encodePacked(hash,Strings.toString(tokenID),Strings.toString(timestamp)); 
        require(verifySignature(hashBytes,sig)==true,"Invalid Signature");
        uint podrarity= podInfo[tokenID].rarity;
        uint podcolor=podInfo[tokenID].color;
        uint podorganism=podInfo[tokenID].organism;
        require(whitelistedForContract[podInfo[tokenID].release][podrarity]==address(this),"Pod not usable for this contract.");
      
        bytes32  hashKeccak=keccak256(abi.encodePacked(hash));
        for(uint j=0; j<3;j++){
          uint podrelease= podInfo[tokenID].release;

        hashKeccak=keccak256(abi.encodePacked(hashKeccak));
        uint rng1=randomize(hashKeccak,100);
        string memory serial=string(abi.encodePacked(Strings.toString(podrelease),"-",Strings.toString(podrarity),"-",Strings.toString(podcolor),"-",Strings.toString(podorganism)));

        for(uint k=0; k<individualSlotRarity[podrelease][podrarity][j].length;k++){
            if(individualSlotRarity[podrelease][podrarity][j][k].rate>rng1){
                    uint dustRarity=individualSlotRarity[podrelease][podrarity][j][k].rarity;
                       hashKeccak=keccak256(abi.encodePacked(hashKeccak));
                        uint rng2=randomize(hashKeccak,100);

                    for(uint l=0; l<dustToGiveFromPodSlot[dustRarity].length;l++){
                     if(dustToGiveFromPodSlot[dustRarity][l].rate>rng2){
                    uint dustAmount=dustToGiveFromPodSlot[dustRarity][l].amount;
                        hashKeccak=keccak256(abi.encodePacked(hashKeccak));
                        Dust memory dustType=podDust[serial][dustRarity][randomize(hashKeccak, podDust[serial][dustRarity].length)];
                DustContract m=DustContract(dustContractAddress[dustType.dustSerial]);
                m.mint(msg.sender,dustAmount);
                emit mintDustSuccessful(dustContractAddress[dustType.dustSerial],dustAmount);

                    break;
                  }
                    }
                
                    break;
            }
       
        }
               



                emit mintDustComplete(msg.sender);
                    }
            _burn(tokenID);

        return true;
        }
     
     function randomize(bytes32 hash, uint range) private view returns (uint) {

        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, hash)))% range;
   
    }

            function mintNFTReward(string memory serial, address to, uint amount,uint cardlevel)  public onlyRole(MINTER_ROLE){
            uint _release=convertString(substring(serial,0,1));
                        uint _rarity=convertString(substring(serial,2,3));
            uint _color=convertString(substring(serial,4,5));
            uint _organism=convertString(substring(serial,6,7));

                for(uint t=0;t<amount;t++){
                _tokenIdCounter.increment();    
                uint256 tokenId = _tokenIdCounter.current();
                 _safeMint(to, tokenId);

               podInfo[tokenId]=Pod({release:_release, rarity:_rarity, color:_color, organism:_organism});

         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(serial, '.json')));
                }
       

    }
    function safeMint(address to, uint release, uint rarity, uint color, uint organism) public onlyRole(MINTER_ROLE) {
        _tokenIdCounter.increment();    
                uint256 tokenId = _tokenIdCounter.current();
       string memory podSerial=string(abi.encodePacked(Strings.toString(release),"-",Strings.toString(rarity),"-",Strings.toString(color),"-",Strings.toString(organism)));
        _safeMint(to, tokenId);
    
                podInfo[tokenId]=Pod({release:release, rarity:rarity, color:color, organism:organism});

         _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(podSerial, '.json')));

    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty,AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
        function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory ) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex-startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
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