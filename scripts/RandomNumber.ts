import hre from "hardhat";
import { RandomGenerator } from "../typechain-types";

async function main() {

    const randomGeneratorAddress = "0x9fe1B04D7a2BeB28BfAE67929839C8Fd6eE68174";

    const RandomGenerator = await hre.ethers.getContractFactory("RandomGenerator");
    const randomGenerator = RandomGenerator.attach(randomGeneratorAddress) as RandomGenerator;

    const userRandomNumber = hre.ethers.randomBytes(32);
    const requestFee = hre.ethers.parseEther("0.001");

    // Request a random number
    const tx = await randomGenerator.requestRandomNumber(userRandomNumber, {
      value: requestFee,
    });

    console.log(`request tx  : ${tx.hash}`);
    await tx.wait();

    // Listen for the Generated event
    randomGenerator.on(
        "Generated",
        (setter, sequenceNumber: number, generatedNumber: number, event) => {
        console.log("Random number generated:");
        console.log("Sequence Number:", sequenceNumber.toString());
        console.log("Generated Number:", generatedNumber);
        // Remove the listener if you only want to listen once
        randomGenerator.removeAllListeners("Generated");
        }
    );

    console.log("Waiting for the random number to be generated...");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
