// 0- SUPA Tokens
// 1- Pods
// 2- Cards
// 3- Card Sleeves
// 4- Battleground





// SPDX-License-Identifier: NONE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // security for non-reentrant
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
interface NFTClaiming{ 
function mintNFTReward(string memory serial, address walletAddress, uint amount, uint cardlevel) external ;
}

//withdraw function
contract ClaimRewards is ReentrancyGuard, AccessControl {
 using ECDSA for bytes32;
      bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
    mapping(address=>mapping(bytes =>bool)) claimedReward;
mapping(uint=>address) public rewardContractAddress;
 event claimedRewardEvent(bytes sig, address userWalletAddress);
mapping(string=>bool) public uuidClaimed;
     constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
    }

      function verifyMPSig(uint rewardType, string memory serial, address walletAddress,uint amount, string memory uuid,bytes memory sig) internal virtual returns (bool) {
          bytes memory toByte=bytes(abi.encodePacked(Strings.toString(rewardType),serial,walletAddress, amount,uuid));
       return hasRole(SIGN_ROLE, keccak256(toByte)
        .toEthSignedMessageHash()
        .recover(sig));
    }
    function getReward(uint rewardType, string memory serial, uint amount, uint cardlevel,string memory uuid,bytes memory sig) public nonReentrant{
        require(verifyMPSig(rewardType,serial, msg.sender, amount, uuid,  sig),"Invalid signature provided"); 
        require(rewardContractAddress[rewardType]!=address(0),"Invalid contract address");
        require(uuidClaimed[uuid]==false,"Already claimed");
        if(rewardType==0){
                  IERC20  txnToken = IERC20(rewardContractAddress[rewardType]);
                    txnToken.transfer(msg.sender, amount);
        }else {
                NFTClaiming txnToken = NFTClaiming(rewardContractAddress[rewardType]);
                    txnToken.mintNFTReward(serial, msg.sender,amount,cardlevel);
        }
        claimedReward[msg.sender][sig]=true;
        uuidClaimed[uuid]=true;
        emit claimedRewardEvent(sig, msg.sender);
    }
       function getRewardAdmin(uint rewardType, string memory serial, uint amount, uint cardlevel) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(rewardContractAddress[rewardType]!=address(0),"Invalid contract address");
        if(rewardType==0){
                  IERC20  txnToken = IERC20(rewardContractAddress[rewardType]);
                    txnToken.transfer(msg.sender, amount);

        }else {
                NFTClaiming txnToken = NFTClaiming(rewardContractAddress[rewardType]);
                    txnToken.mintNFTReward(serial, msg.sender,amount,cardlevel);
        }
    }
    function setRewardContractAddress(address _contractAddress,uint _rewardType) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardContractAddress[_rewardType]=_contractAddress;
    }
    function balanceRemaining() public view returns (uint){
         IERC20  txnToken = IERC20(rewardContractAddress[0]);
         return txnToken.balanceOf(address(this));
    }
    function withdrawTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20  txnToken = IERC20(rewardContractAddress[0]);
       txnToken.transfer(msg.sender,  txnToken.balanceOf(address(this)));

    }
          
}