// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract dTSLA is ConfirmedOwner , FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;
enum MintOrRedeem {
mint , 
redeem
}
struct dTslaRequest {
    uint256 amountOfToken;
    address requester ;
    MintOrRedeem mintOrRedeem;
}
address constant SEPOLI_FUNCTION_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
string private s_mintSourceCode ;
uint64 immutable i_SubId;
uint32 constant callbackGasLimit = 300_000;
bytes32 constant donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
mapping(bytes32 requstId => dTslaRequest request ) private s_requestIdToRequest; 
constructor(string memory mintSourceCode , uint64 subscriptionId ) ConfirmedOwner(msg.sender) FunctionsClient(SEPOLI_FUNCTION_ROUTER) {
    s_mintSourceCode = mintSourceCode; 
    i_SubId = subscriptionId; 
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



} // mint the dtsla token


// user request to sell the TSLA for the usdc (redeemption token ) 
// have chainink function call where our bank 
// 1 sell tsla on the brokrage 
// 2 buy usdc on the brokage 
// 3 send usdc to this contrat for the user

function sendRedeemRequest() external {} // redeem the dtsla token 

function _redeemFullFillRequest(bytes32 requestId, bytes memory response) internal {} // redeem the dtsla token

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/) internal override {
    dTslaRequest storage request = s_requestIdToRequest[requestId];
    if (request.mintOrRedeem == MintOrRedeem.mint) {
      _mintFullFillRequest(requestId, response);
    } else {
      _redeemFullFillRequest(requestId,response);
    }
  }

// currrently incomplete 
  function _getCollateralRatioAdjustedTotalValue(uint256 addedNumberOfToken) internal  view {
    uint256 calculatedValue =  getCalculatednewValue(addedNumberOfToken);
  }
  function getCalculatednewValue(uint256 addedNumberOfToken) internal view returns (uint256) {
    return (totalSupply() + addedNumberOfToken)*getTslaPrice(); 
  }
  function getTslaPrice() public view returns (uint256) {
    AggregatorV3Interface pricefeed = AggregatorV3Interface(0x1c1e3c8e8e7c5abf5d7e1c245d380c4a4d7e4c8c); // sepoli aggregrator address for the tsla/usd price feed 
     
  }

}

