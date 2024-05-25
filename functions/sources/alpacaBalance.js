if (secrets.alpacakey == "" || secrets.alpacasecret == "") {
 throw Error("Alpaca API key and secret are required.")
} 

const url = 'https://paper-api.alpaca.markets/v2/account';
const headers = {
    accept : 'application/json',
    'APCA-API-KEY-ID' : secrets.alpacakey,
    'APCA-API-SECRET-KEY' : secrets.alpacasecret  ,  
} 

const alphcaRequest = Functions.makeHttpRequest( {
   url: url,
    headers: headers
})

const [response] = await Promise.all([alphcaRequest])
const portfolioBalance = await response.data.portfolio_value;
console.log(`portfolio balance ${portfolioBalance}`); 

return Functions.encodeUint256(Math.round(portfolioBalance * 100))

