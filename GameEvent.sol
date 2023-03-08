// SPDX-License-Identifier: NONE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // security for non-reentrant
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


interface IERC2981Royalties {
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _value - the sale price of the NFT asset specified by _tokenId
    /// @return _receiver - address of who should be sent the royalty payment
    /// @return _royaltyAmount - the royalty payment amount for value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}
interface MPContract{
 function updateWL(int RDnew, int GRnew, int BKnew, int BUnew, int WHnew, int ORnew, int PRnew, address playerAddress) external;

}
//withdraw function
contract EventPayment is ReentrancyGuard, AccessControl {
        using ECDSA for bytes32;

event PaymentUsed(address indexed sender, string paymentId, uint paymentMethod);

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
        bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");
 IERC20 private supaToken = IERC20(0x86A677e61cd7e2E7020F8D0c9f75AED099642d5a);
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
   
    // Currency is in Matic (lower price than ethereum)
         address public mpContractAddress;
mapping(address => mapping(string => bool)) public usedPaymentIds;

 event mpPaid(MutationPoints amount, address buyer, string paymentId);
 event supaPaid(uint amount, address buyer, string paymentId);
struct MutationPoints {
    int RD;
    int GR;
    int BK;
    int BU;
    int WH;
    int OR;
    int PR;
    }

mapping(address=>mapping(string=>MutationPoints)) public checkMPPayment;
mapping(address=>mapping(string=>uint)) public checkSUPAPayment;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
     _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
  
        
    }

function makeSUPAPayment(string memory paymentId, uint paymentAmount, bytes memory sig)  public{
     require(verifySUPASig(paymentAmount, paymentId ,msg.sender,sig),"Invalid signature provided"); 
         require(
             supaToken.allowance(msg.sender,address(this)) >= paymentAmount,
            "Approval for payment required"
        );
    require(!usedPaymentIds[msg.sender][paymentId], "PaymentId already used");

    usedPaymentIds[msg.sender][paymentId] = true;

  supaToken.transferFrom(msg.sender, address(this), paymentAmount);
        checkSUPAPayment[msg.sender][paymentId]=paymentAmount;
    emit PaymentUsed(msg.sender, paymentId, 1);

}

        
function verifySUPASig(uint paymentAmount, string memory uuid, address playerAddress,bytes memory sig) internal virtual returns(bool){
       bytes memory toByte=bytes(abi.encodePacked(playerAddress,uuid,Strings.toString(paymentAmount)));
       return hasRole(SIGN_ROLE, keccak256(toByte)
        .toEthSignedMessageHash()
        .recover(sig));

}
  function setMPContractAddress(address _addr) public onlyRole(MINTER_ROLE) {
     
    mpContractAddress = _addr;
   
  }
     function verifyMPSig(int WH, int GR, int BU, int BK, int PR, int RD, int OR, address playerAddress, string memory uuid, bytes memory sig) internal virtual returns (bool) {
          bytes memory mutations=abi.encodePacked(int2str(WH),int2str(GR),int2str(BU),int2str(BK),int2str(PR),int2str(RD),int2str(OR));
          bytes memory toByte=bytes(abi.encodePacked(playerAddress,uuid,mutations));
       return hasRole(SIGN_ROLE, keccak256(toByte)
        .toEthSignedMessageHash()
        .recover(sig));
    }



function makeMPPayment(int WHnew, int GRnew, int BUnew, int BKnew, int PRnew, int RDnew, int ORnew, string memory paymentId, bytes memory sig)  public {
    require(verifyMPSig(WHnew, GRnew, BUnew, BKnew, PRnew, RDnew, ORnew, msg.sender, paymentId, sig),"Invalid signature provided"); 
    require(!usedPaymentIds[msg.sender][paymentId], "PaymentId already used");
    usedPaymentIds[msg.sender][paymentId] = true;

         MPContract mp=MPContract(mpContractAddress);
        mp.updateWL(WHnew,GRnew,BUnew,BKnew,PRnew,RDnew,ORnew,msg.sender);
        checkMPPayment[msg.sender][paymentId]=MutationPoints({WH:WHnew, GR:GRnew, BU: BUnew, BK:BKnew, PR:PRnew, RD: RDnew, OR:ORnew});
    emit PaymentUsed(msg.sender, paymentId, 2);

}
function withdraw(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
       IERC20  txnToken = IERC20(tokenAddress);
        txnToken.transfer(msg.sender,txnToken.balanceOf(address(this)));


}
function checkContractBalance(address tokenAddress) public view returns (uint){
  IERC20  txnToken = IERC20(tokenAddress);
  return txnToken.balanceOf(address(this));
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

