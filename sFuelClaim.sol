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
interface BattlegroundContract{ 

function internalmint(uint sleeveId, address to) external;
    }
interface PodContract{
    function safeMint(address to, uint release, uint rarity, uint color, uint organism) external;

}
    //card serial with level
/// @custom:security-contact contact@supa.foundation
contract ClaimSFuel is  Pausable, AccessControl,  ReentrancyGuard {
        address public podContractAddress;
        address public battlegroundContractAddress;
       uint public battlegroundMin;
    event mintSuccessful(string[] mintedPods,address user);
    using Counters for Counters.Counter;
        using ECDSA for bytes32;
         mapping(string=>string[]) public minted;
    uint[] public rewardRange;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
    mapping(string=>bool) public seenNoncesDiscord;
    constructor(address _podContractAddress, address _battlegroundContractAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
     _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    podContractAddress=_podContractAddress;
        battlegroundContractAddress=_battlegroundContractAddress;
    }
   
 function setPodContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    podContractAddress = _addr;
   
  }
  function setBattlegroundContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    battlegroundContractAddress = _addr;
   
  }

    function setSFuelRange(uint[] memory _rewardRange,uint _battlegroundMin) public onlyRole(DEFAULT_ADMIN_ROLE){
        delete rewardRange;
        rewardRange=_rewardRange;
        battlegroundMin=_battlegroundMin;

    }
    function verifySignature(string memory discordUser, uint SFuelAmount,bytes memory sig) internal virtual returns (bool) {
       return hasRole(SIGN_ROLE, keccak256(bytes(abi.encodePacked(discordUser,Strings.toString(SFuelAmount))))
        .toEthSignedMessageHash()
        .recover(sig));
    }
    function mintSFuelRewards(string memory discordUser, uint SFuelAmount, bytes memory sig) public nonReentrant{
        require(verifySignature(discordUser,SFuelAmount,sig)==true,"Invalid signature");
        require(seenNoncesDiscord[discordUser]==false,"Reward already claimed");
        require(SFuelAmount>=battlegroundMin,"Insufficient SFuel to claim rewards");
        seenNoncesDiscord[discordUser]=true;
        PodContract m=PodContract(podContractAddress);
       
         bytes32  hashKeccak=keccak256(abi.encodePacked(discordUser,Strings.toString(SFuelAmount)));
         for(uint i=0; i<rewardRange.length;i++){
             if(SFuelAmount>rewardRange[i]){
                 hashKeccak=keccak256(abi.encodePacked(hashKeccak));
                 uint organism=randomize(hashKeccak,2);
                 uint color=randomize(hashKeccak,7);
                 m.safeMint(msg.sender, 0, i, color, organism);
                minted[discordUser].push(string(abi.encodePacked(Strings.toString(0),"-",Strings.toString(i),"-",Strings.toString(color),"-",Strings.toString(organism))));
             }
         }
         if(SFuelAmount>=battlegroundMin){
            BattlegroundContract b = BattlegroundContract(battlegroundContractAddress);
            b.internalmint(1,msg.sender);
         }
        
        emit mintSuccessful(minted[discordUser],msg.sender); 
    }


     
     function randomize(bytes32 hash, uint range) private view returns (uint) {
        // sha3 and now have been deprecated
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, hash)))% range;
        // convert hash to integer
        // players is an array of entrants
        
    }
 
}