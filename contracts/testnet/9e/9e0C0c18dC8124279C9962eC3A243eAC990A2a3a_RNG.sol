// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

contract RNG {

    struct eventsStruct {
        mapping (uint256 => bool)  numbers;
        uint256[] numbersArray;
        uint256 startTimeStamp;
        uint256 endTimeStamp;
        uint256 count;
        uint256 range;
        uint256 offSet;
        bool existStatus;
    }

    mapping (uint256 => eventsStruct) public events;

    uint8 eventId = 0;

    // Add event
    function addEvent(uint256 _startTimeStamp, uint256 _endTimeStamp, uint256 _range, uint256 _offSet) public returns (bool) {
        require(events[eventId].existStatus == false, "Event already exist");

        eventsStruct storage eventObject = events[eventId];
        eventObject.startTimeStamp = _startTimeStamp;
        eventObject.endTimeStamp = _endTimeStamp;
        eventObject.count = 0;
        eventObject.range = _range;
        eventObject.offSet = _offSet;
        eventObject.existStatus = true;

        eventId++;
        return true;
    }

    // Find random number
    function randomWinner(uint256 _eventId) public returns (uint256, bool) {
        eventsStruct storage choosedEvent = events[_eventId];
        require(choosedEvent.existStatus == true, "Event with this Id not Exist");
        require(choosedEvent.numbersArray.length < choosedEvent.range, "Winners: Maximum length reached");
        require((choosedEvent.startTimeStamp <= block.timestamp) && (block.timestamp <= choosedEvent.endTimeStamp), "TimeStamp: Shoud be in timestamp");
        bool check = false;
        bool valid = false;
        uint256 randomNumber;
        uint256 count1 = 0;

        do {
            randomNumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, count1))) % choosedEvent.range;
            randomNumber = randomNumber + choosedEvent.offSet;

            if(choosedEvent.count >= choosedEvent.range) {
                randomNumber = choosedEvent.range;
                check = true;
            }

            if(choosedEvent.numbers[randomNumber] == false && randomNumber < choosedEvent.range) {
                choosedEvent.numbers[randomNumber] = true;
                choosedEvent.numbersArray.push(randomNumber);
                choosedEvent.count++;
                check = true;
                valid = true;
            }
            count1++;
        }
        while (check == false);

        return (randomNumber, valid);
    }

    // Reset the winners
    function resetData(uint256 _eventId) public returns (bool) {
        eventsStruct storage choosedEvent = events[_eventId];
        require(choosedEvent.existStatus == true, "Event with this Id not Exist");

        uint256[] memory tempArray;
        for(uint8 i = 0; i < choosedEvent.numbersArray.length; i++) {
            choosedEvent.numbers[choosedEvent.numbersArray[i]] = false;
        }
        choosedEvent.numbersArray = tempArray;
        choosedEvent.count = 0;

        return true;
    }

    // Remove and reset event data
    function removeAndResetEvent(uint256 _eventId) public returns (bool) {
        eventsStruct storage choosedEvent = events[_eventId];
        require(choosedEvent.existStatus == true, "Event with this Id not exist");

        uint256[] memory tempArray;
        choosedEvent.existStatus = false;
        choosedEvent.startTimeStamp = 0;
        choosedEvent.endTimeStamp = 0;
        choosedEvent.count = 0;
        choosedEvent.range = 0;
        choosedEvent.offSet = 0;

        for(uint8 i=0; i < choosedEvent.numbersArray.length; i++) {
            choosedEvent.numbers[choosedEvent.numbersArray[i]] = false;
        }

        choosedEvent.numbersArray = tempArray;
        return true;
    }

    // Get current time stamp
    function getTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }
}