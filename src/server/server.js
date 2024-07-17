import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import "babel-polyfill"


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

//Initialization of Oracles

const registerOracles = async () => {
  try {
    const fee = await flightSuretyApp.methods.getRegistrationFee().call();
    const accounts = await web3.eth.getAccounts();
    const oracleCount = Math.min(accounts.length, 20);
    for (let i = 0; i < oracleCount; i++) {
      const account = accounts[i];
      console.log('Registering oracle account:', account);
      await flightSuretyApp.methods.registerOracle().send({
        from: account,
        value: fee,
        gas: 5000000
      });
    }
    console.log(`${accounts.length} Oracles registered`);
  } catch (error) {
    console.error(`Error registering oracles: ${error.message}`);
  }
};

// Simulate Oracle Response
const simulateOracleResponse = async (requestedIndex, airline, flight, timestamp) => {
  try {
    const accounts = await web3.eth.getAccounts();
    for (const account of accounts) {
      const indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: account });
      console.log(`Oracles indexes: ${indexes} for account: ${account}`);
      for (const index of indexes) {
        if (requestedIndex == index) {
          try {
            const statusCode = Math.floor(Math.random() * 6) * 10; // Random status code (0, 10, 20, 30, 40, 50)
            console.log(`Submitting Oracle response for Flight: ${flight} at Index: ${index} with Status: ${statusCode}`);
            await flightSuretyApp.methods.submitOracleResponse(
              index, airline, flight, timestamp, statusCode
            ).send({ from: account, gas: 5000000 });
          } catch (e) {
            console.error(`Error submitting oracle response: ${e.message}`);
          }
        }
      }
    }
  } catch (error) {
    console.error(`Error simulating oracle response: ${error.message}`);
  }
};

// Register Oracles when starting the server
registerOracles();

flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});

flightSuretyApp.events.FlightStatusInfo({})
  .on('data', (event) => {
    console.log("FlightStatusInfo event:", event);
  })
  .on('error', (error) => {
    console.error(`FlightStatusInfo event error: ${error.message}`);
  });

const app = express();
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;


