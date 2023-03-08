// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
interface MutationPointsGetter {
    function NFTMutationPoints(uint256 tokenId)
        external
        returns (
            uint256 RD,
            uint256 GR,
            uint256 BK,
            uint256 BU,
            uint256 WH,
            uint256 OR,
            uint256 PR
        );
}

contract MutationPointsFarming is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    address public SUPAVirusAddr;
    address public SUPACellAddr;
    MutationPointsGetter SUPAVirus;
    MutationPointsGetter SUPACell;

    mapping(address => bool) public whitelistedContract;
    mapping(uint256 => uint256) public lastFarmedVirus;
    mapping(uint256 => uint256) public lastFarmedCell;
    uint256 public multiplier;

    struct MutationPoints {
        uint256 WH;
        uint256 GR;
        uint256 BU;
        uint256 BK;
        uint256 PR;
        uint256 RD;
        uint256 OR;
    }

    mapping(address => MutationPoints) public playerMutationPoints;
    mapping(string => bool) public txnDone;

    bool public isPaused;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");

    address payable contractOwner;

    function initialize() initializer public {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        contractOwner = payable(msg.sender);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
  
      
      function verifyMPSig(int WH, int GR, int BU, int BK, int PR, int RD, int OR, address playerAddress, string memory uuid, bytes memory sig) internal virtual returns (bool) {
          bytes memory mutations=abi.encodePacked(int2str(WH),int2str(GR),int2str(BU),int2str(BK),int2str(PR),int2str(RD),int2str(OR));
          bytes memory toByte=bytes(abi.encodePacked(playerAddress,uuid,mutations));
       return hasRole(SIGN_ROLE, keccak256(toByte)
        .toEthSignedMessageHash()
        .recover(sig));
    }
    function setPause(bool toPause) public onlyRole(DEFAULT_ADMIN_ROLE){
            isPaused = toPause;

    }
    function setMultiplier(uint newMultiplier) public onlyRole(DEFAULT_ADMIN_ROLE){
            multiplier = newMultiplier;

    }

    function update(int WHnew, int GRnew, int BUnew, int BKnew, int PRnew, int RDnew, int ORnew, address playerAddress, string memory uuid, bytes memory sig) public  nonReentrant{
           require(
           isPaused==false ,
            "Updating is Paused."
        );

          require(verifyMPSig(WHnew, GRnew, BUnew, BKnew, PRnew, RDnew, ORnew,playerAddress,uuid,sig),"Invalid signature provided"); 
         require(txnDone[uuid]==false,"Already claimed");
         require( int(playerMutationPoints[playerAddress].RD)+ RDnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].GR)+ GRnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].BK)+ BKnew>=0,"Insufficient balance");  
         require( int(playerMutationPoints[playerAddress].BU)+ BUnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].WH)+ WHnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].OR)+ ORnew>=0,"Insufficient balance");  
        require( int(playerMutationPoints[playerAddress].PR)+ PRnew>=0,"Insufficient balance");
       playerMutationPoints[playerAddress].RD= uint(int(playerMutationPoints[playerAddress].RD)+RDnew);
        playerMutationPoints[playerAddress].GR= uint(int(playerMutationPoints[playerAddress].GR)+GRnew);
        playerMutationPoints[playerAddress].BK= uint(int(playerMutationPoints[playerAddress].BK)+BKnew);
        playerMutationPoints[playerAddress].BU= uint(int(playerMutationPoints[playerAddress].BU)+BUnew);
         playerMutationPoints[playerAddress].WH= uint(int(playerMutationPoints[playerAddress].WH)+WHnew);
         playerMutationPoints[playerAddress].OR= uint(int(playerMutationPoints[playerAddress].OR)+ORnew);
         playerMutationPoints[playerAddress].PR= uint(int(playerMutationPoints[playerAddress].PR)+PRnew);
            txnDone[uuid]=true;
        
     }
 function whitelistContract(address nftContract, bool toWhitelist) public onlyRole(DEFAULT_ADMIN_ROLE) {
            whitelistedContract[nftContract] = toWhitelist;

            }
 function updateWL(int WHnew, int GRnew, int BUnew, int BKnew, int PRnew, int RDnew, int ORnew, address playerAddress) public  nonReentrant{
           require(
           isPaused==false ,
            "Updating is Paused."
        );
        require(
           whitelistedContract[msg.sender] == true || contractOwner==payable(msg.sender),
            "Invalid requester"
        );
         require( int(playerMutationPoints[playerAddress].RD)+ RDnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].GR)+ GRnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].BK)+ BKnew>=0,"Insufficient balance");  
         require( int(playerMutationPoints[playerAddress].BU)+ BUnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].WH)+ WHnew>=0,"Insufficient balance");
         require( int(playerMutationPoints[playerAddress].OR)+ ORnew>=0,"Insufficient balance");  
        require( int(playerMutationPoints[playerAddress].PR)+ PRnew>=0,"Insufficient balance");
    playerMutationPoints[playerAddress].RD= uint(int(playerMutationPoints[playerAddress].RD)+RDnew);
        playerMutationPoints[playerAddress].GR= uint(int(playerMutationPoints[playerAddress].GR)+GRnew);
        playerMutationPoints[playerAddress].BK= uint(int(playerMutationPoints[playerAddress].BK)+BKnew);
        playerMutationPoints[playerAddress].BU= uint(int(playerMutationPoints[playerAddress].BU)+BUnew);
         playerMutationPoints[playerAddress].WH= uint(int(playerMutationPoints[playerAddress].WH)+WHnew);
         playerMutationPoints[playerAddress].OR= uint(int(playerMutationPoints[playerAddress].OR)+ORnew);
         playerMutationPoints[playerAddress].PR= uint(int(playerMutationPoints[playerAddress].PR)+PRnew);
        
     }
     function farmOwner(uint organism,uint start, uint end) public {
        require(
           isPaused==false ,
            "Farming is Paused."
        );
                require(organism==0||organism==1,"invalidOrganism");
                if(organism==0){
                uint totalSUPAVirus=IERC721Upgradeable(SUPAVirusAddr).balanceOf(msg.sender);
                    if (end>totalSUPAVirus){
                        end=totalSUPAVirus;
                    }
                for(uint256 i = start; i < end; i++) {
               uint tokenID= IERC721EnumerableUpgradeable(SUPAVirusAddr).tokenOfOwnerByIndex(msg.sender,i);
                    farm(tokenID,0);
                 }
                }
                else{
                   uint totalSUPACell=IERC721Upgradeable(SUPACellAddr).balanceOf(msg.sender);
                    if (end>totalSUPACell){
                        end=totalSUPACell;
                    }
                 for(uint256 i = start; i < end; i++) {
                   uint tokenID= IERC721EnumerableUpgradeable(SUPACellAddr).tokenOfOwnerByIndex(msg.sender,i);
                    farm(tokenID,1);
                 }
                }
               


     }
     
    function farm(uint tokenId, uint organism ) public  nonReentrant{
         require(
           isPaused==false ,
            "Farming is Paused."
        );

        require(organism==0 || organism==1,"invalidOrganism");
        if(organism==0){
                //SUPAVirus
           require( IERC721Upgradeable(SUPAVirusAddr).ownerOf(tokenId)==msg.sender);
         if(block.timestamp>lastFarmedVirus[tokenId]+86400){
    (uint RDnew, uint GRnew, uint BKnew, uint BUnew, uint WHnew, uint ORnew, uint PRnew) =  SUPAVirus.NFTMutationPoints(tokenId);
        playerMutationPoints[msg.sender].RD+= RDnew*multiplier;
        playerMutationPoints[msg.sender].GR+= GRnew*multiplier;
        playerMutationPoints[msg.sender].BK+= BKnew*multiplier;
        playerMutationPoints[msg.sender].BU+= BUnew*multiplier;
        playerMutationPoints[msg.sender].WH+= WHnew*multiplier;
        playerMutationPoints[msg.sender].OR+= ORnew*multiplier;
        playerMutationPoints[msg.sender].PR+= PRnew*multiplier;
        lastFarmedVirus[tokenId]=block.timestamp;
         }
       
                } else{
       require( IERC721Upgradeable(SUPACellAddr).ownerOf(tokenId)==msg.sender);
        if(block.timestamp>lastFarmedCell[tokenId]+86400){
  (uint RDnew, uint GRnew, uint BKnew, uint BUnew, uint WHnew, uint ORnew, uint PRnew) =  SUPACell.NFTMutationPoints(tokenId);
        playerMutationPoints[msg.sender].RD+= RDnew*multiplier;
        playerMutationPoints[msg.sender].GR+= GRnew*multiplier;
        playerMutationPoints[msg.sender].BK+= BKnew*multiplier;
        playerMutationPoints[msg.sender].BU+= BUnew*multiplier;
        playerMutationPoints[msg.sender].WH+= WHnew*multiplier;
        playerMutationPoints[msg.sender].OR+= ORnew*multiplier;
        playerMutationPoints[msg.sender].PR+= PRnew*multiplier;
        lastFarmedCell[tokenId]=block.timestamp;
        }
       
                }
   
    }



function int2str(int i) internal pure returns (string memory _uintAsString){
    if (i == 0) return "0";
    bool negative = i < 0;
    uint j = uint(negative ? -i : i);
    uint l = j;     // Keep an unsigned copy
    uint len;
    while (j != 0){
        len++;
        j /= 10;
    }
    if (negative) ++len;  // Make room for '-' sign
    bytes memory bstr = new bytes(len);
    uint k = len;
    while (l != 0){
       k = k-1;
       uint8 temp = (48 + uint8(l % 10));    
        bstr[k] = bytes1(temp);
        l /= 10;
    }
    if (negative) {    // Prepend '-'
        bstr[0] = '-';
    }
    return string(bstr);
}
}