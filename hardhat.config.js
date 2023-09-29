require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config() ;
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",

  networks: {
    development: {
      url: process.env.PROVIDER_URL, // URL where Ganache is running
      chainId: 1337, // Ganache's default chain ID
      accounts:[`${process.env.PRIVATE_KEY}`]
    },
  },

  settings: {
    optimizer: {
      enabled: true,
      runs: 50000 // Number of optimization runs, adjust as needed
    },
  },

};
