import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "hardhat-contract-sizer";

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.19",

        settings: {
            evmVersion: "paris",
            metadata: {
                bytecodeHash: "none",
            },
            optimizer: {
                enabled: true,
                runs: 1_000_000,
            },
        },
    },
    etherscan: {
        apiKey: {
            avalancheFujiTestnet: process.env.FUJI_API_KEY || "",
            bscTestnet: process.env.TBSC_API_KEY || "",
            goerli: process.env.ETH_API_KEY || "",
            bsc: process.env.TBSC_API_KEY || "",
        },
    },
    networks: {
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            chainId: 43113,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
        // bsc: {
        //     url: "https://bsc-dataseed1.binance.org/",
        //     chainId: 56,
        //     accounts:
        //         process.env.MAINTAINER_KEY !== undefined
        //             ? [process.env.MAINTAINER_KEY]
        //             : [],
        // },
        bscTest: {
            url: "https://data-seed-prebsc-1-s2.binance.org:8545/",
            chainId: 97,
            accounts: [
                "d2e8272301fed486c54b71ebb9ee9220df040636ac9dad691f3bf06573c05648",
            ],
        },
        goerli: {
            url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            chainId: 5,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
        tomoTest: {
            url: "https://rpc.testnet.tomochain.com",
            chainId: 89,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
    },

    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
};

export default config;
