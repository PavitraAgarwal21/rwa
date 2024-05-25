// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract dTSLA is ConfirmedOwner , FunctionsClient , ERC20  {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

enum MintOrRedeem {
mint , 
redeem
}

struct dTslaRequest {
    uint256 amountOfToken;
    address requester ;
    MintOrRedeem mintOrRedeem;
}

error dtsla__doesnt_Meet_Minimum_Withdrawl_Amount();
error dtsl__not_Enough_Collateral_In_Bank() ;
error dtsla__Transfer_Failed(); 

address constant SEPOLI_FUNCTION_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
string private s_mintSourceCode ;
string private s_redeemSourceCode ; 
uint64 immutable i_SubId;
uint32 constant callbackGasLimit = 300_000;
bytes32 constant donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
address constant SEPOLI_TSLA_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF ;  // acutually it is for the link/usd price feed bcz sepoli supoorted only this 
address constant SEPOLI_USDC_PRICE = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E ; 
address constant SEPOLI_USDC_CONTRACT_ADDRESS = 0x2730E8320D2a3b0b30AaFE7d8D3d453F57EEDf41 ;
uint256 constant ADDITIONAL_FEDD_PRECISION = 1e18;
uint256 constant PRECISION = 1e18;
uint256 constant COLLATERAL_PRECISION = 100 ; 
uint256 constant COLLATERAL_RATIO = 200 ;
uint256 constant MININMUM_WITHDRAWL_AMOUNT = 100;


uint256 s_portfolioBalance  ;
mapping(bytes32 requstId => dTslaRequest request ) private s_requestIdToRequest; 
mapping (address user => uint256 ) private s_userToAmountToWithdraw ; 
constructor(string memory mintSourceCode , uint64 subscriptionId , string memory redeemSourceCode) 
ConfirmedOwner(msg.sender) 
FunctionsClient(SEPOLI_FUNCTION_ROUTER) 
    ERC20("dtsla","dtsla")
{
    s_mintSourceCode = mintSourceCode; 
    i_SubId = subscriptionId; 
    s_redeemSourceCode = redeemSourceCode;
}
// so there are mainly 
//1 see how may tsla is bought by a user
//2 if enough dtsla is there then user can redeem it for tsla 
//3 mint the dtsla token 
// imp this is the two transaction function means - 
// first send the mint request ot the chainlink oracle 
// then chainklink oracle will gave the response that it contain the appropriate amount to dtsla or not 
function sendMintRequest(uint256 amount) external returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_mintSourceCode);
 bytes32 requstId = _sendRequest(req.encodeCBOR(), i_SubId, callbackGasLimit, donId); 
 /*
   these gave the request to the chainlink oracle 
 */ 
s_requestIdToRequest[requstId] = dTslaRequest(
    amount,
    msg.sender,
    MintOrRedeem.mint
);
return requstId; 
} // mint the dtsla token
// we gave the sendmintrequest to the chainlink oracle and then chainlink oracle will gave the response that it contain the appropriate amount to dtsla or not
// to this funciton and it is internal  
function _mintFullFillRequest(bytes32 requestId, bytes memory response) internal {

//our chainlink function see how much tsla token is bought  
//return the amount of tsla iin the usdc , mint the dtsla 
uint256 amountOfTokenToMint = s_requestIdToRequest[requestId].amountOfToken;

// we want to know how much tsla in $ there is collateral in the bank 
// how much tsla in $ we want to mint  
// reading the response 
s_portfolioBalance = uint256(bytes32(response)) ;
if (_getCollateralRatioAdjustedTotalValue(amountOfTokenToMint) > s_portfolioBalance) {
    revert dtsl__not_Enough_Collateral_In_Bank();
} 
if (amountOfTokenToMint != 0 ) {
  _mint(s_requestIdToRequest[requestId].requester, amountOfTokenToMint); 

}

}// mint the dtsla token


// user request to sell the TSLA for the usdc (redeemption token ) 
// have chainink function call where our bank 
// 1 sell tsla on the brokrage 
// 2 buy usdc on the brokage 
// 3 send usdc to this contrat for the user

// these are the fucntion which keep the price packed 
function sendRedeemRequest(uint256 amountOfTsla) external  {
    uint256 tslaInUsdc = getUsdcValueOfUsd(getTslaValueofUsd(amountOfTsla)) ; 
    if (tslaInUsdc > MININMUM_WITHDRAWL_AMOUNT) {
        revert dtsla__doesnt_Meet_Minimum_Withdrawl_Amount() ; 
    }

   FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode);
 bytes32 requstId = _sendRequest(req.encodeCBOR(), i_SubId, callbackGasLimit, donId); 
 /*
we have to gave the information 
how much tsla token to sell f
And for what amount this has been selling in the usdc .
 */ 
string[] memory args = new string[](2);
args[0] = amountOfTsla.toString();
args[1] = tslaInUsdc.toString();
req.setArgs(args);
s_requestIdToRequest[requstId] = dTslaRequest(
    amountOfTsla,
    msg.sender,
    MintOrRedeem.redeem
);
_burn(msg.sender, amountOfTsla); // to get equivallent usdc , should have to burn sdtal token 



} // redeem the dtsla token 

function getUsdcValueOfUsd(uint256 amount ) public view returns (uint256) {
 return  ((amount / getUsdcPrice()) /PRECISION) ; // here i think it is divide as we have to convert the usd into the usdc  
}
function getTslaValueofUsd(uint256 amount ) public view returns (uint256) {
 return ((amount * getTslaPrice())/PRECISION) ;
} 



function _redeemFullFillRequest(bytes32 requestId, bytes memory response) internal {
 
 // first how much amount of usdc is returned from the respnse 
 uint256 usdcAmount = uint256(bytes32(response)) ;

 
 // if its is zero then what we have burn please mint it back to the requester and 
 if (usdcAmount ==0 ) {
  //how much of the token is burned 
  uint256 amountOfTokenBurned = s_requestIdToRequest[requestId].amountOfToken ; 
  // now we have to mine it 
  _mint( s_requestIdToRequest[requestId].requester, amountOfTokenBurned) ; // into which account and amount 
  return ; 
}





// but if they send the correct amount of usdc then we have to add it to the mapping 
s_userToAmountToWithdraw[s_requestIdToRequest[requestId].requester] += usdcAmount ;


// also make the mapping where we can have the information that how much amount of usdc they have to have redeeme 


} // redeem the dtsla token

// NOW WE HAVE TO IMPLEMENT FINAL WITHDRAWL FUNCTION 

function withdrwal() external {

    uint256 amount = s_userToAmountToWithdraw[msg.sender] ; 
    s_userToAmountToWithdraw[msg.sender] = 0 ;    
    bool success = ERC20(SEPOLI_USDC_CONTRACT_ADDRESS).transfer(msg.sender, amount) ;
    if (!success) {
        revert dtsla__Transfer_Failed();
    }
    

}


  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/) internal override {
    dTslaRequest storage request = s_requestIdToRequest[requestId];
    if (request.mintOrRedeem == MintOrRedeem.mint) {
      _mintFullFillRequest(requestId, response);
    } else {
      _redeemFullFillRequest(requestId,response);
    }
  }


// currrently incomplete 
  function _getCollateralRatioAdjustedTotalValue(uint256 addedNumberOfTokenToMint) internal  view returns (uint256) {
    uint256 calculatedNewTotalValue =  getCalculatedNewTotalValue(addedNumberOfTokenToMint);
    return ( (calculatedNewTotalValue * COLLATERAL_RATIO )/ COLLATERAL_PRECISION);

  }
  function getCalculatedNewTotalValue(uint256 addedNumberOfToken) internal view returns (uint256) {
    return ((totalSupply() + addedNumberOfToken)*getTslaPrice())/PRECISION; 
  }
  function getTslaPrice() public view returns (uint256) {
    AggregatorV3Interface pricefeed = AggregatorV3Interface(SEPOLI_TSLA_PRICE_FEED); // sepoli aggregrator address for the tsla/usd price feed 
     (,int256 price , , ,) =  pricefeed.latestRoundData();
      return uint256(price)*ADDITIONAL_FEDD_PRECISION ; // SO THAT WE CAN GET THE PRECSION UPTO 18 DECIMALS 

  }
function getUsdcPrice() public view returns (uint256) {
    AggregatorV3Interface pricefeed = AggregatorV3Interface(SEPOLI_USDC_PRICE); // sepoli aggregrator address for the tsla/usd price feed 
     (,int256 price , , ,) =  pricefeed.latestRoundData();
      return uint256(price)*ADDITIONAL_FEDD_PRECISION ; // SO THAT WE CAN GET THE PRECSION UPTO 18 DECIMALS 

}


/*
            Get functions 
*/

function getRequests(bytes32 requestId) public view returns (dTslaRequest memory) {
    return s_requestIdToRequest[requestId];
}

function getPendingWithdrawlAmount() public view returns (uint256) {
    return s_userToAmountToWithdraw[msg.sender];
}
function getSubId() public view returns (uint64) {
    return i_SubId;
}
function getMintSourceCode() public view returns (string memory) {
    return s_mintSourceCode;
}
function getCollateralPrecision() public pure returns (uint256) {
    return COLLATERAL_PRECISION;
}

function getCollateralRatio() public pure returns (uint256) {
    return COLLATERAL_RATIO;
}

function getPortfolioBalance() public view returns (uint256) {
    return s_portfolioBalance;
}


}