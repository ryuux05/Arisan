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
        uint participantCount;
        bytes32 name;
        uint256 monthlyDeposit;
        uint256 monthlyEarning;
        uint256 currentDeposited;
        address token;
        uint256 depositStartTime;
        address[] participants;
        mapping(address => bool) isParticipant;
        mapping(address => bool) hasDeposit;
        mapping(address => bool) hasWon;
        mapping(address => uint256) participantCollateral; 
        uint256 collateralAmount;
        uint256 round;
        uint256 currentRoundWinCount;
        ArisanStatus status;
    }

    //Counter
    uint256 public arisanCount;

    //Mapping
    mapping(uint256 => Arisan) public ArisanPool;

    // Events
    event ParticipantJoined(address participant);
    event DepositReceived(address participant, uint256 amount);
    event WinnerSelected(address winner, uint256 amount);
    event ArisanCreated(address creator, uint256 id, uint256 monthlyDeposit, uint participantCount);

    constructor(){
        arisanCount = 0;
    }

    function createArisan(address _token, uint256 _participantCount, bytes32 _name, uint256 _monthlyDeposit, uint256 _monthlyEarning, uint256 _collateralAmount) external payable{
        require(ArisanPool[arisanCount].creator == address(0), "Id used.");

        Arisan storage newArisan = ArisanPool[arisanCount];

        newArisan.id = arisanCount;
        newArisan.creator = msg.sender;
        newArisan.participantCount = _participantCount;
        newArisan.name = _name;
        newArisan.monthlyDeposit = _monthlyDeposit;
        newArisan.monthlyEarning = _monthlyEarning;
        newArisan.currentDeposited = 0;
        newArisan.round = 0;
        newArisan.currentRoundWinCount = 0;
        newArisan.status = ArisanStatus.Pending;

        newArisan.participants.push(msg.sender);
        newArisan.isParticipant[msg.sender] = true;
        newArisan.hasDeposit[msg.sender] = false;
        newArisan.hasWon[msg.sender] = false;
        
        if(_token == address(0)) {
            require(msg.value >= _collateralAmount, "Insufficient ether.");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _collateralAmount);
        }

        newArisan.participantCollateral[msg.sender] = _collateralAmount;

        arisanCount += 1;

        //Emit event
        emit ArisanCreated(msg.sender, arisanCount, _monthlyDeposit, _participantCount);
    }

    function joinArisan(uint256 _arisanId, address _token, uint256 _collateralAmount) external payable{
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];

        require(arisan.status == ArisanStatus.Pending, "You can't join");
        require(!arisan.isParticipant[msg.sender], "Already a participant.");
        require(arisan.participants.length < arisan.participantCount, "Arisan is full.");

        arisan.participants.push(msg.sender);
        arisan.isParticipant[msg.sender] = true;
        arisan.hasDeposit[msg.sender] = false;
        arisan.hasWon[msg.sender] = false;

        if(_token == address(0)) {
            require(msg.value >= _collateralAmount, "Insufficient ether.");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _collateralAmount);
        }
        arisan.participantCollateral[msg.sender] = _collateralAmount;
    }

    function leaveArisan(uint256 _arisanId) internal {
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];

        if(arisan.hasDeposit[msg.sender] == false) {
            arisan.currentDeposited += arisan.participantCollateral[msg.sender];
            arisan.participantCollateral[msg.sender] = 0;
        }

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
        require(ArisanPool[_arisanId].participants.length == ArisanPool[_arisanId].participantCount, "Participant is not enough.");

        ArisanPool[_arisanId].status = ArisanStatus.Started;
        ArisanPool[_arisanId].depositStartTime = block.timestamp;

    }

    function depositArisan(uint256 _arisanId, address _token, uint256 _tokenAmount) external payable nonReentrant {
        require(_arisanId <= arisanCount, "Arisan does not exist.");
        Arisan storage arisan = ArisanPool[_arisanId];
        require(arisan.status == ArisanStatus.Started, "Arisan is not started");
        require(arisan.isParticipant[msg.sender], "You are not a participant");
        require(arisan.hasDeposit[msg.sender] != true, "You have already deposited");
        require(arisan.status == ArisanStatus.Started, "Arisan is not active.");
        require(arisan.currentDeposited < arisan.monthlyEarning, "Target amount already reached.");
        require(arisan.round > 0, "The round is over");


        if(_token == address(0)) {
            require(msg.value >= _tokenAmount, "Insufficient ether.");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _tokenAmount);
        }

        arisan.hasDeposit[msg.sender] = true;

        arisan.currentDeposited += msg.value;

        // Check if target amount is reached
        if (arisan.currentDeposited >= arisan.monthlyEarning) {
            // Proceed to select a winner
            selectWinner(_arisanId);
        }

        //emit DepositMade(_arisanId, msg.sender, amountToDeposit, isEth);
    }

    function selectWinner(uint256 _arisanId) internal {
        Arisan storage arisan = ArisanPool[_arisanId];

        address[] memory eligibleParticipants = getEligibleParticipants(_arisanId);

        require(eligibleParticipants.length > 0, "No eligible participants.");

        // Generate a pseudo-random number
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % eligibleParticipants.length;

        address winner = eligibleParticipants[randomIndex];

        arisan.currentRoundWinCount += 1;

        distributeFunds(_arisanId, winner);

        arisan.hasWon[winner] = true;

        resetForNextDeposit(_arisanId);

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

    function distributeFunds(uint256 _arisanId, address winner) internal nonReentrant {
        Arisan storage arisan = ArisanPool[_arisanId];

        uint256 amountToSend = arisan.currentDeposited;

        if(arisan.token == address(0)) {
            (bool sent, ) = winner.call{value: amountToSend}("");
            require(sent, "Failed to send Ether.");
        } else {
            IERC20(arisan.token).transfer(winner, amountToSend);
        }

        // Reset currentDeposited
        arisan.currentDeposited = 0;
    }

    function resetForNextDeposit(uint256 _arisanId) internal {
        Arisan storage arisan = ArisanPool[_arisanId];

        // Reset hasDeposited mapping
        for (uint256 i = 0; i < arisan.participants.length; i++) {
            arisan.hasDeposit[arisan.participants[i]] = false;
        }

        if (arisan.currentRoundWinCount == arisan.participants.length) {
            // Go to next round if there is more round
            if(arisan.round > 0) {
                for (uint256 i = 0; i < arisan.participants.length; i++) {
                    arisan.hasWon[arisan.participants[i]] = false;
                }
                arisan.currentRoundWinCount = 0;
                arisan.round -= 1;
            } else {
                arisan.status = ArisanStatus.Ended;
            }
        }
    }

}