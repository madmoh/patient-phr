pragma solidity <0.7.0;

import "./Shared.sol";
import "./Controller.sol";


// TODO: replace uint with more specific type
// TODO: make the events targeted if they are
// TODO: make sure the records and the requests are available

contract PatientRecords {
    // State variables
    address public patient;
    // Shared.Record[] public records; // TODO: better if it's something like mapping (ks_kPp# => Shared.Record) records;
    bytes32[] bundleHashes;
    mapping(bytes32 => Shared.Record) records;
    Controller controller;
    
    
    // Constructor
    // TODO: try to find more elegant solution
    constructor(address controllerAddress) public {
        patient = msg.sender;
        controller = Controller(controllerAddress);
    }
    
    
    // Modifiers
    modifier onlyPatient {
        require(msg.sender == patient, "Owner patient required");
        _;
    }
    
    modifier onlyDoctor {
        require(controller.isDoctorRegistered(msg.sender), "Doctor required");
        _;
    }
    
    modifier onlyOracle {
        require(controller.isOracleRegistered(msg.sender), "Oracle required");
        _;
    }
    
    
    // Adding a record (done by patient)
    event recordAddedPatient(); // Inform patient // TODO: finish this // TODO: make sure this is correct (no timeout issues)
    function addRecord(bytes32 _bundleHash, byte _permissions) public onlyPatient {
        bundleHashes.push(_bundleHash);
        
        Shared.Record memory newRecord;
        // newRecord.bundleHash = _bundleHash;
        newRecord.permissions = _permissions;
        records[_bundleHash] = newRecord;
        
        emit recordAddedPatient();
    }
    
    
    // Request a record (done by doctor)
    // TODO: transaction fees related to _oracleCount
    // TODO: penalize if oracle responded to PRSC but didn't send to doctor
    event recordRequestedDoctor();
    event recordRequestedPatient(bytes doctorPublicKey); // Inform doctor about successful request, and inform patient about new request (must contain doctor's public key)
    function requestRecord(uint _recordIndex, bytes memory _publicKey, uint _minOracleCount, uint _maxOracleCount) public onlyDoctor {
        // require(Shared.checkPublicKey(_publicKey), "Valid public key required");
        // require((uint(keccak256(_publicKey)) & (0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == uint(msg.sender), "Valid public key required");
        require(_minOracleCount <= _maxOracleCount, "_minOracleCount <= _maxOracleCount required");

        Shared.Request memory request;
        request.doctor = msg.sender;
        request.requestTime = block.timestamp;
        request.minOracleCount = _minOracleCount;
        request.maxOracleCount = _maxOracleCount;
        request.grant = false;
        request.oraclesEvaluated = false;
        
        records[bundleHashes[_recordIndex]].requests[records[bundleHashes[_recordIndex]].requestCount] = request;
        records[bundleHashes[_recordIndex]].requestCount += 1;
        
        emit recordRequestedDoctor();
        emit recordRequestedPatient(_publicKey);
    }
    
    
    // Respond to a pending request (done by patient) // TODO: need more efficient way to track pending requests
    event requestRespondedDoctor();
    event requestRespondedPatient();
    event requestRespondedOracles(); // TODO: must include bundle hash and so and so
    function respondRequest(uint _recordIndex, uint _requestIndex, bool _grant) public onlyPatient {
        records[bundleHashes[_recordIndex]].requests[_requestIndex].grant = _grant;
        
        emit requestRespondedDoctor();
        emit requestRespondedPatient();
        
        if (_grant) {
            emit requestRespondedOracles();
        
            // call function after 2 hours
        }
    }
    
    
    // // Add an participating oracle (dony by oracle)
    // event oracleAdded();
    // function addOracleParticipation(uint _recordIndex, uint _requestIndex) public onlyOracle {
    //     require(records[_recordIndex].requests[_requestIndex].grant, "Granted request required");
    //     require(records[_recordIndex].requests[_requestIndex].requestTime + 1 hours <= block.timestamp &&
    //         records[_recordIndex].requests[_requestIndex].oracleResponsesCount > 0, "Request no longer accepts oracles");
    //     Shared.OracleResponse storage oracleResponse;
    //     oracleResponse.participationTime = block.timestamp;
    //     oracleResponse.didRespond = false;
    //     records[_recordIndex].requests[_requestIndex].oracleResponsesCount += 1;
    //     records[_recordIndex].requests[_requestIndex].oracleResponses[msg.sender] = oracleResponse;
    // }
    
    
    // Add oracle response (done by oracle)
    // TODO: to think about: what if patient revoked after oracle participated?
    // TODO: maybe let doctor select 1 hours
    // NOTE:
    /* 
     * There are 3 cases:
     * 1- still waiting for min: reach min then evaluate
     * 2- got min but not max: evaluate on timeout
     * 3- got max: evaluate
     */
    function addOracleResponse(uint _recordIndex, uint _requestIndex, bytes32 _bundleHash) public onlyOracle {
        Shared.Record storage record = records[bundleHashes[_recordIndex]];
        Shared.Request storage request = record.requests[_requestIndex];
        
        require(request.grant, "Granted request required");
        require(!request.oraclesEvaluated, "Unevaluated request required");
        
        if (request.oracleAddresses.length < request.minOracleCount ||
        request.oracleAddresses.length >= request.minOracleCount &&
        request.oracleAddresses.length < request.maxOracleCount &&
        request.requestTime + 1 hours <= block.timestamp) {
            uint latency = block.timestamp - request.requestTime;
            uint isHashCorrect = _bundleHash == bundleHashes[_recordIndex] ? 1 : 0;  // TODO: this should not be bundle hash but rather ks_kPp#

            // TODO: make sure this is working correctly
            uint oracleRating = 100 / (latency) * isHashCorrect;
            request.oracleAddresses.push(msg.sender);
            request.oracleRatings[msg.sender] = oracleRating; // TODO: shouldn't be in ledger, directly send to measure reputation
            
        }
        
        if ((request.oracleAddresses.length >= request.minOracleCount && request.requestTime + 1 hours <= block.timestamp) ||
            request.oracleAddresses.length == request.maxOracleCount) {
            evaluateOracles(_recordIndex, _requestIndex);
            request.oraclesEvaluated = true;
            
        }
    }
    
    
    
    event tokenCreatedDoctor(bytes32 tokenID, address oracleAddress); // oracle info
    // event tokenCreatedOracle(bytes32 tokenID, address doctorAddress); // doctor info
    function evaluateOracles(uint _recordIndex, uint _requestIndex) internal {
        Shared.Record storage record = records[bundleHashes[_recordIndex]];
        Shared.Request storage request = record.requests[_requestIndex];
        
        uint[] memory reputations = controller.getOracleReputations(request.oracleAddresses);
        uint[] memory ratings = new uint[](request.oracleAddresses.length);
        
        address bestOracleAddress;
        uint bestOracleScore = 0;
        
        for (uint i = 0; i < request.oracleAddresses.length; i++) {
            uint oracleRating = request.oracleRatings[request.oracleAddresses[i]];
            uint oracleReputation = reputations[i];
            
            uint oracleScore = oracleRating * (oracleReputation + 1)**2;
            
            if (oracleScore >= bestOracleScore) {
                bestOracleScore = oracleScore;
                bestOracleAddress = request.oracleAddresses[i];
            }
            
            ratings[i] = oracleRating;
        }
        
        controller.submitContractOracleRatings(request.oracleAddresses, ratings);
        
        bytes32 tokenID = keccak256(abi.encodePacked(request.doctor, bestOracleAddress, block.timestamp));
        
        emit tokenCreatedDoctor(tokenID, bestOracleAddress);
        
        // emit tokenCreatedDoctor(tokenID, request.doctor);
        controller.submitOracleToken(bestOracleAddress, tokenID, request.doctor);
        
    }
    
    
}