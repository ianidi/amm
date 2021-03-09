require("chai/register-should");
require('mocha-steps')

const HDWalletProvider = require('truffle-hdwallet-provider-privkey');
const privateKey = "5aef343adb11c2c335092029c7d3f3857fea5b32e8a88446e74970fb7533c16b";
const endpointUrl = "https://ropsten.infura.io/v3/c010ef4cc4754cfba5eba886a7508afd";

const config = {
    networks: {
        ropsten: {
            provider: function() {
              return new HDWalletProvider([privateKey], endpointUrl);
            },
            network_id: '3',
          },
        mainnet: {
            host: "localhost",
            port: 8545,
            network_id: "1",
        },
        // ropsten: {
        //     provider: function() {
        //       return new HDWalletProvider(
        //         //private keys array
        //         [privateKey],
        //         //url to ethereum node
        //         endpointUrl
        //       )
        //     },
        //     gas: 5000000,
        //     gasPrice: 25000000000,
        //     network_id: 3
        //   },
        rinkeby: {
            host: "localhost",
            port: 8545,
            network_id: "4",
        },
        goerli: {
            host: "localhost",
            port: 8545,
            network_id: "5",
        },
        develop: {
            host: "localhost",
            port: 8545,
            network_id: "*",
	},
    },
    mocha: {
        enableTimeouts: false,
        grep: process.env.TEST_GREP,
        reporter: "eth-gas-reporter",
        reporterOptions: {
            currency: "USD",
            excludeContracts: ["Migrations"]
        }
    },
    compilers: {
        solc: {
            version: ">=0.5.10",
            settings: {
                optimizer: {
                    enabled: true
                }
            }
        }
    }
}

const _ = require('lodash')

try {
    _.merge(config, require('./truffle-local'))
}
catch(e) {
    if(e.code === 'MODULE_NOT_FOUND') {
        // eslint-disable-next-line no-console
        console.log('No local truffle config found. Using all defaults...')
    } else {
        // eslint-disable-next-line no-console
        console.warn('Tried processing local config but got error:', e)
    }
}

module.exports = config
