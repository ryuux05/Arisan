import { expect } from "chai";
import hre from "hardhat";
import { Contract, ContractFactory, Signature, Signer } from 'ethers'
import { SwapHandler__factory, SwapHandler } from "../typechain-types";

describe("Swap", function() {
    let addr1: Signer;
    let swapHandlerContractFactory: SwapHandler__factory;
    let swapHandler: SwapHandler;

    before(async function() {
        const signers = await hre.ethers.getSigners();
        addr1 = signers[0];
        swapHandlerContractFactory = await hre.ethers.getContractFactory("SwapHandler");
        swapHandler = await swapHandlerContractFactory.deploy("0xE592427A0AEce92De3Edee1F18E0157C05861564");

        swapHandler.waitForDeployment();
    })

    describe("Swap from WETH to USDT", function() {
        it("Should swap", async function() {
            
        })
    })
})