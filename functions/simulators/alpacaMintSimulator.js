const { simulateScript, decodeResult } = require('@chainlink/functions-toolkit') ;
const requestConfig = require('../configs/alpacaMintConfig.js') ; 
async function main() {
  const {
    responseBytesHexstring , 
    errorString ,  
    capturedTerminalOutput ,
} = await simulateScript(requestConfig); 

if (responseBytesHexstring) {
  console.log(`decode result returned by the script : ${decodeResult(
    responseBytesHexstring , requestConfig.expectedReturnType
  ).toString()}`);   
 } 
 if (errorString) {
  console.log({errorString}); 
}
}
main().catch((error) => {
  console.error(error);  
  process.exit(1);

});