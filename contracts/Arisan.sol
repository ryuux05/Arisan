// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// interface IArisanContract {
//     function createArisan(uint256 _id, uint256 _participantCount, bytes32 _name, uint256 _monthlyDeposit, uint256 _monthlyEarning) external;
//     function joinArisan(uint _id) external;
//     function depositArisan(uint256 _id, address _token, uint256 _tokenAmount) payable external;

// }
contract ArisanContract is ReentrancyGuard{

    enum ArisanStatus {
        Pending,
        Started,
        Ended
    }

    struct Arisan{
        uint256 id;
        address creator;
        uint32 participantCount;
        bytes32 name;
        uint256 monthlyDeposit;
        uint256 monthlyEarning;
        uint256 currentDeposited;
        uint256 depositStartTime;
        address[] participants;
        mapping(address => bool) isParticipant;
        mapping(address => bool) hasWon;
        uint256 collateralAmount;
        ArisanStatus status;
    }

    //Counter
    uint256 public arisanCount;

    //Mapping
    mapping(uint256 => Arisan) public ArisanPool;

    // Events
    event ParticipantJoined(address participant);
    event DepositReceived(address participant);
    event WinnerSelected(address winner, uint256 amount);
    event ArisanCreated(address creator, uint256 id, uint256 monthlyDeposit, uint participantCount);

    constructor(){
        arisanCount = 0;
    }

    function createArisan(address _token, uint32 _participantCount, bytes32 _name, uint256 _monthlyDeposit, uint256 _monthlyEarning, uint256 _collateralAmount) external payable{
        require(ArisanPool[arisanCount].creator == address(0), "Id used.");

        Arisan storage newArisan = ArisanPool[arisanCount];

        newArisan.id = arisanCount;
        newArisan.creator = msg.sender;
        newArisan.name = _name;
        newArisan.monthlyDeposit = _monthlyDeposit;
        newArisan.monthlyEarning = _monthlyEarning;
        newArisan.currentDeposited = 0;

        newArisan.status = ArisanStatus.Pending;
        newArisan.participantCount = _participantCount;
        newArisan.participants.push(msg.sender);
        newArisan.hasWon[msg.sender] = false;
        
        if(_token == address(0)) {
            require(msg.value >= _collateralAmount, "Insufficient ether.");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _collateralAmount);
        }

        newArisan.isParticipant[msg.sender] = true;
        arisanCount += 1;

        //Emit event
        emit ArisanCreated(msg.sender, newArisan.id, _monthlyDeposit, _participantCount);
    }

    function joinArisan(uint256 _arisanId, address _token, uint256 _collateralAmount) external payable{
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];

        require(arisan.status == ArisanStatus.Pending, "You can't join");
        require(arisan.participants.length < arisan.participantCount, "Arisan is full.");
        require(!arisan.isParticipant[msg.sender], "Already a participant.");

        if(_token == address(0)) {
            require(msg.value >= _collateralAmount, "Insufficient ether.");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _collateralAmount);
        }

        arisan.isParticipant[msg.sender] = true;
       
        arisan.participants.push(msg.sender);
        arisan.hasWon[msg.sender] = false;
        if(arisan.participants.length == arisan.participantCount) {
            startArisan(_arisanId);
        }
        emit ParticipantJoined(msg.sender);
    }

    function leaveArisan(uint256 _arisanId) internal {
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];

         // Remove participant from the Arisan
        arisan.isParticipant[msg.sender] = false;

        // Remove from participants array
        for (uint256 i = 0; i < arisan.participants.length; i++) {
            if (arisan.participants[i] == msg.sender) {
                arisan.participants[i] = arisan.participants[arisan.participants.length - 1];
                arisan.participants.pop();
                break;
            }
        }
    }

    function startArisan(uint256 _arisanId) internal{
        require(_arisanId <= arisanCount, "Arisan does not exist.");

        Arisan storage arisan = ArisanPool[_arisanId];
        require(arisan.participants.length == arisan.participantCount, "Participant is not enough.");

        arisan.status = ArisanStatus.Started;
        arisan.depositStartTime = block.timestamp;

    }

    function depositArisan(uint256 _arisanId, address _token) external payable nonReentrant {
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];
        require(arisan.status == ArisanStatus.Started, "Arisan is not started");
        require(arisan.isParticipant[msg.sender], "You are not a participant");
        require(arisan.status == ArisanStatus.Started, "Arisan is not active.");
        require(arisan.currentDeposited < arisan.monthlyEarning, "Target amount already reached.");

        uint256 depositAmount;
        if(_token == address(0)) {
            // Deposit is in ETH
            depositAmount = msg.value;
            require(depositAmount == arisan.monthlyDeposit, "Incorrect deposit amount.");
            arisan.currentDeposited += depositAmount;
        } else {
            // Deposit is in ERC20 token
            depositAmount = arisan.monthlyDeposit;
            require(msg.value == 0, "ETH not accepted for this Arisan.");
            
            // Check allowance
            uint256 allowance = IERC20(_token).allowance(msg.sender, address(this));
            require(allowance >= depositAmount, "Insufficient token allowance.");

            // Transfer tokens from participant to contract
            bool success = IERC20(_token).transferFrom(msg.sender, address(this), depositAmount);
            require(success, "Token transfer failed.");
            
            arisan.currentDeposited += depositAmount;
        }


        // Check if target amount is reached
        if (arisan.currentDeposited >= arisan.monthlyEarning) {
            // Proceed to select a winner
            selectWinner(_arisanId);
        }

        emit DepositReceived(msg.sender);
    }

    function selectWinner(uint256 _arisanId) internal {
        Arisan storage arisan = ArisanPool[_arisanId];

        address[] memory eligibleParticipants = getEligibleParticipants(_arisanId);

        require(eligibleParticipants.length > 0, "No eligible participants.");

        // Generate a pseudo-random number
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % eligibleParticipants.length;

        address winner = eligibleParticipants[randomIndex];

        distributeFunds(_arisanId, winner, address(0));

        arisan.hasWon[winner] = true;

        //emit WinnerSelected(_arisanId, winner, arisan.currentDeposited);
    }

    function getEligibleParticipants(uint256 _arisanId) internal view returns (address[] memory) {
        Arisan storage arisan = ArisanPool[_arisanId];
        uint256 count = 0;
        uint256 totalParticipants = arisan.participants.length;

        // Count eligible participants
        for (uint256 i = 0; i < totalParticipants; i++) {
            if (!arisan.hasWon[arisan.participants[i]]) {
                count++;
            }
        }

        // Initialize array with the count of eligible participants
        address[] memory eligibleParticipants = new address[](count);
        uint256 index = 0;

        // Populate the array
        for (uint256 i = 0; i < totalParticipants; i++) {
            if (!arisan.hasWon[arisan.participants[i]]) {
                eligibleParticipants[index] = arisan.participants[i];
                index++;
            }
        }

        return eligibleParticipants;
    }

    function distributeFunds(uint256 _arisanId, address winner, address _token) internal nonReentrant {
        Arisan storage arisan = ArisanPool[_arisanId];

        uint256 amountToSend = arisan.currentDeposited;

        if(_token == address(0)) {
            (bool sent, ) = winner.call{value: amountToSend}("");
            require(sent, "Failed to send Ether.");
        } else {
            IERC20(_token).transfer(winner, amountToSend);
        }

        // Reset currentDeposited
        arisan.currentDeposited = 0;
    }

    //Some getter function
    function isParticipant(uint256 _arisanId, address _participant) public view returns (bool) {
        Arisan storage arisan = ArisanPool[_arisanId];
        return arisan.isParticipant[_participant];
    }

    function getCurrentDeposited(uint256 _arisanId) public view returns(uint256) {
        Arisan storage arisan = ArisanPool[_arisanId];
        return arisan.currentDeposited;
    }

    function hasWon(uint256 _arisanId, address _participant) public view returns (bool) {
        Arisan storage arisan = ArisanPool[_arisanId];
        return arisan.hasWon[_participant];
    }

    function getParticipants(uint256 _arisanId) public view returns (address[] memory) {
        return ArisanPool[_arisanId].participants;
    }

    function getArisan(uint256 _arisanId) public view returns (
        uint256 id,
        address creator,
        uint32 participantCount,
        bytes32 name,
        uint256 monthlyDeposit,
        uint256 monthlyEarning,
        uint256 currentDeposited,
        uint256 depositStartTime,
        uint256 collateralAmount,
        ArisanStatus status,
        uint256 currentParticipantsCount
    ) {
        Arisan storage arisan = ArisanPool[_arisanId];
        return (
            arisan.id,
            arisan.creator,
            arisan.participantCount,
            arisan.name,
            arisan.monthlyDeposit,
            arisan.monthlyEarning,
            arisan.currentDeposited,
            arisan.depositStartTime,
            arisan.collateralAmount,
            arisan.status,
            arisan.participants.length
        );
    }

}