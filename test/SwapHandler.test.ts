import { expect } from "chai";
import hre from "hardhat";
import { Contract, ContractFactory, Signature, Signer } from 'ethers'
import { SwapHandler__factory, SwapHandler } from "../typechain-types";
import { ABI } from "./ERC_ABI.json"

describe("Swap", function() {
    let addr1: Signer;
    let swapHandlerContractFactory: SwapHandler__factory;
    let swapHandler: SwapHandler;
    let WETH_Contract: Contract;
    let USDT_Contract: Contract;
    let balance: string;

    before(async function() {
        const signers = await hre.ethers.getSigners();
        addr1 = signers[0];
        swapHandlerContractFactory = await hre.ethers.getContractFactory("SwapHandler");
        swapHandler = await swapHandlerContractFactory.deploy("0xE592427A0AEce92De3Edee1F18E0157C05861564");
        swapHandler.waitForDeployment();
    })

    before(async function() {
        const ERC_ABI = ABI;

        //WETH contract
        const WETH_addr = '0xC02aaA39b223FE8D0a0e5C4F27eAD9083C756Cc2'
        WETH_Contract = new hre.ethers.Contract(WETH_addr, ERC_ABI, addr1);

        //USDT contract
        const USDT_addr = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        USDT_Contract = new hre.ethers.Contract(USDT_addr, ERC_ABI, addr1);

        // initial balance in ETH 
        const provider = hre.ethers.provider
        const balance = hre.ethers.formatEther(await provider.getBalance(await addr1.getAddress()));

        const num_weth = hre.ethers.formatEther((await WETH_Contract.balanceOf(await addr1.getAddress())))
        expect(num_weth).to.equal('0.0')

        console.log("ETH Balance: ", balance)
        console.log("WETH Balance: ", num_weth)
        console.log("---")
    })

    describe("Swap from WETH to USDT", function() {
        it("Should deposit and swap WETH", async function() {
            const tx = await WETH_Contract.deposit(
            {
                value: hre.ethers.parseEther('2'),
            })

            await tx.wait();
            
            const provider = hre.ethers.provider
            balance = hre.ethers.formatEther(await provider.getBalance(await addr1.getAddress()));

            const num_weth = hre.ethers.formatEther((await WETH_Contract.balanceOf(await addr1.getAddress())))
            expect(num_weth).to.equal('2.0')

            console.log("ETH Balance: ", balance)
            console.log("WETH Balance: ", num_weth)
            console.log("---")

        })

        it("Approve spending and swap", async function() {
            // approve swapper contract to spend for 1 WETH 
            const txx = await WETH_Contract.approve(await swapHandler.getAddress(), hre.ethers.parseEther('1'))
            await txx.wait()

            // 1 WETH -> USDT 
            const txxx = await swapHandler.swapExactInputSingle(hre.ethers.parseEther('1'))
            await txxx.wait()

            //Check USDT balance
            const num_weth_after = hre.ethers.formatEther((await WETH_Contract.balanceOf(await addr1.getAddress())));
            const num_usdt = (await USDT_Contract.balanceOf(await addr1.getAddress()));
            expect(num_weth_after).to.equal('1.0');

            console.log("ETH Balance: ", balance);
            console.log("WETH Balance: ", num_weth_after);
            console.log("USDT Balance: ", num_usdt);
            console.log("---");
        })
    })
})