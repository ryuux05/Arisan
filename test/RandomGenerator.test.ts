import { expect } from "chai";
import hre from "hardhat";
import { EntropyEvents__factory, RandomGenerator, RandomGenerator__factory } from 
"../typechain-types"
import { Signer } from 'ethers'
import { EntropyEvents, EntropyStructs } from "../typechain-types/@pythnetwork/entropy-sdk-solidity/EntropyEvents";

describe("Random Generator", function() {
    let randomGeneratorFactory: RandomGenerator__factory;
    let randomGenerator: RandomGenerator;
    let addr1: Signer;

    before(async function() {
        const signers = await hre.ethers.getSigners();
        addr1 = signers[0];

        randomGeneratorFactory = await hre.ethers.getContractFactory("RandomGenerator");

        randomGenerator = await randomGeneratorFactory.deploy("0x549Ebba8036Ab746611B4fFA1423eb0A4Df61440");
        
        await randomGenerator.waitForDeployment();
    })

    describe("Get random number", function() {
        it("Should generate random number", async function() {
            const userRandomNumber = hre.ethers.randomBytes(32);

            // await expect(
            //     requestReceipt = await randomGenerator.requestRandomNumber(userRandomNumber)
            // )
            //     .to.emit(randomGenerator, "Requested");

            const requestReceipt = await randomGenerator.requestRandomNumber(userRandomNumber, {
                value: hre.ethers.parseEther("0.0001"),
            })


            await requestReceipt.wait();

            console.log(`request tx  : ${requestReceipt.hash}`);

            const sequenceNumber =
            requestReceipt.removedEvent();
            console.log(`sequence    : ${sequenceNumber}`);
        })
    })
})