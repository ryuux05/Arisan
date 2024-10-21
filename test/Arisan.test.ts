import { expect } from "chai";
import hre from "hardhat";
import { Contract, ContractFactory, Signature, Signer } from 'ethers'
import { ArisanContract, ArisanContract__factory } from "../typechain-types";


describe("Arisan", function() {
    let arisanContractFactory: ArisanContract__factory;
    let arisanContract: ArisanContract;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addr3: Signer;
    let addr4: Signer;
    let addrs: Signer[];

    async function joinArisan(_arisanId: number, _addr: Signer, collateralAmount: bigint) {
        return arisanContract
        .connect(_addr)
        .joinArisan(
            _arisanId,
            hre.ethers.ZeroAddress, 
            collateralAmount, 
            {
                value: collateralAmount,
            }
        )
    }

    before(async function () {
        [owner, addr1, addr2, addr3, addr4, ...addrs] = await hre.ethers.getSigners();

        arisanContractFactory = await hre.ethers.getContractFactory("ArisanContract");
        arisanContract = await arisanContractFactory.deploy();
        await arisanContract.waitForDeployment();
    })

    before(async function() {
        const participantCount = 3;
        const name = hre.ethers.encodeBytes32String("Test Arisan");
        const monthlyDeposit = hre.ethers.parseEther("1");
        const monthlyEarning = hre.ethers.parseEther("3");
        const collateralAmount = hre.ethers.parseEther("0.5");

        await expect(
            arisanContract.createArisan(
              hre.ethers.ZeroAddress, // Using Ether
              participantCount,
              name,
              monthlyDeposit,
              monthlyEarning,
              collateralAmount,
              { value: collateralAmount } // Sending collateral in Ether
            )
          )
            .to.emit(arisanContract, "ArisanCreated")
            .withArgs(await owner.getAddress(), 0, monthlyDeposit, participantCount);

          const arisan = await arisanContract.getArisan(0);
          expect(arisan.currentParticipantsCount).to.equal(1);
    })

    it("Should be deployed", async function () {
        expect(await arisanContract.arisanCount()).to.equal(1);
    })

    it("Should create arisan successfully", async function() {
        const participantCount = 3;
        const name = hre.ethers.encodeBytes32String("Test Arisan");
        const monthlyDeposit = hre.ethers.parseEther("1");
        const monthlyEarning = hre.ethers.parseEther("3");
        const collateralAmount = hre.ethers.parseEther("0.5");

        await expect(
            arisanContract.createArisan(
              hre.ethers.ZeroAddress, // Using Ether
              participantCount,
              name,
              monthlyDeposit,
              monthlyEarning,
              collateralAmount,
              { value: collateralAmount } // Sending collateral in Ether
            )
          )
            .to.emit(arisanContract, "ArisanCreated")
            .withArgs(await owner.getAddress(), 1, monthlyDeposit, participantCount);
        
        const arisan = await arisanContract.getArisan(0);
        expect(arisan.currentParticipantsCount).to.equal(1);
        
    })

    it("Should allow participants to join arisan", async function() {
        const collateralAmount = hre.ethers.parseEther("0.5");
        // addr1 joins the Arisan
        await expect(
            arisanContract
            .connect(addr1)
            .joinArisan(1, hre.ethers.ZeroAddress, collateralAmount, {
                value: collateralAmount,
            })
        )
            .to.emit(arisanContract, "ParticipantJoined")
            .withArgs(await addr1.getAddress());

        // Verify that addr1 is a participant
        const isParticipant = await arisanContract.isParticipant(1, await addr1.getAddress());
        expect(isParticipant).to.be.true;
    })

    it("Should start arisan and allow pariticipants to deposit to an arisan", async function() {
        const depositAmount = hre.ethers.parseEther("1");
        const collateralAmount = hre.ethers.parseEther("0.5");
        await expect(
            joinArisan(0, addr2, collateralAmount)
        )
            .to.emit(arisanContract, "ParticipantJoined")
            .withArgs(await addr2.getAddress());
        await expect(
            joinArisan(0, addr2, collateralAmount)
        )
            .to.be.revertedWith("Already a participant.")    
        await expect(
            joinArisan(0, addr3, collateralAmount)
        )
        .to.emit(arisanContract, "ParticipantJoined")
        .withArgs(await addr3.getAddress());
        await expect(
            joinArisan(0, addr4, collateralAmount)
        )
            .to.be.revertedWith("You can't join")

        const arisan = await arisanContract.getArisan(0);
        expect(arisan.currentParticipantsCount).to.equal(3);
        expect(arisan.status).to.equal(1);
        await expect(
            await arisanContract.depositArisan(
                0,
                hre.ethers.ZeroAddress,
                {
                    value: depositAmount
                }
            )
        )
            .to.emit(arisanContract, "DepositReceived")
            .withArgs(await owner.getAddress());
        
        const currentDeposited = await arisanContract.getCurrentDeposited(0);
        expect(currentDeposited).to.equal(hre.ethers.parseEther("1"));
    })

})