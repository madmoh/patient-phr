pragma solidity <0.7.0;

import "./Shared.sol";
import "./Controller.sol";


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
    function requestRecord(uint16 _recordIndex, bytes memory _publicKey, uint8 _minOracleCount, uint8 _maxOracleCount) public onlyDoctor {
        // require(Shared.checkPublicKey(_publicKey), "Valid public key required");
        // require((uint256(keccak256(_publicKey)) & (0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == uint256(msg.sender), "Valid public key required");
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
    function respondRequest(uint16 _recordIndex, uint16 _requestIndex, bool _grant) public onlyPatient {
        records[bundleHashes[_recordIndex]].requests[_requestIndex].grant = _grant;
        
        emit requestRespondedDoctor();
        emit requestRespondedPatient();
        
        if (_grant) {
            emit requestRespondedOracles();
        
            // call function after 2 hours
        }
    }


    // Add oracle response (done by oracle)
    // TODO: to think about: what if patient revoked after oracle participated?
    // TODO: maybe let doctor select 1 hours
    // TODO LATER: consider all oracles are bad
    // NOTE:
    /* 
     * There are 3 cases to start evaluating oracles and stop accepting more oracle responses:
     * 1- still waiting for min: reach min then evaluate
     * 2- got min but not max: evaluate on timeout
     * 3- got max: evaluate
     */
    function addOracleResponse(uint16 _recordIndex, uint16 _requestIndex, bytes32 _bundleHash) public onlyOracle {
        Shared.Record storage record = records[bundleHashes[_recordIndex]];
        Shared.Request storage request = record.requests[_requestIndex];
        
        require(request.grant, "Granted request required");
        require(!request.oraclesEvaluated, "Unevaluated request required");
        
        uint16 latency = (uint16)(block.timestamp - request.requestTime);
        
        if (request.oracleAddresses.length < request.minOracleCount ||
            (request.oracleAddresses.length >= request.minOracleCount &&
            request.oracleAddresses.length < request.maxOracleCount &&
            latency <= 1 hours)) {
                
            uint8 isHashCorrect = _bundleHash == bundleHashes[_recordIndex] ? 1 : 0;
                
            // TODO LATER: this should not be bundle hash but rather ks_kPp#
            uint16 input_start = 1;
            uint16 input_end = 3600;
            uint16 output_start = 2**16 - 1;
            uint16 output_end = 1;

            // TODO: make sure this is working correctly
            uint16 oracleRating = isHashCorrect;
            if (latency < 1)
                oracleRating *= 2**16 - 1;
                
            else if (latency > 1 hours)
                oracleRating *= 0;
                
            else
                oracleRating *= output_start + ((output_end - output_start) / (input_end - input_start)) * (latency - input_start);

            // TODO: shouldn't be in ledger, directly send to measure reputation
            request.oracleAddresses.push(msg.sender);
            request.oracleRatings[msg.sender] = oracleRating;
            
        }
        
        if ((request.oracleAddresses.length >= request.minOracleCount && request.requestTime + 1 hours <= block.timestamp) ||
            request.oracleAddresses.length == request.maxOracleCount) {
            evaluateOracles(_recordIndex, _requestIndex);
            request.oraclesEvaluated = true;
            
        }
    }
    
    
    
    event tokenCreatedDoctor(bytes32 tokenID, address oracleAddress); // oracle info
    event tokenCreatedOracle(bytes32 tokenID, address doctorAddress); // doctor info
    function evaluateOracles(uint16 _recordIndex, uint16 _requestIndex) internal {
        Shared.Record storage record = records[bundleHashes[_recordIndex]];
        Shared.Request storage request = record.requests[_requestIndex];
        
        uint16[] memory reputations = controller.getOracleReputations(request.oracleAddresses);
        uint16[] memory ratings = new uint16[](request.oracleAddresses.length);
        
        address bestOracleAddress;
        uint64 bestOracleScore = 0;
        
        for (uint16 i = 0; i < request.oracleAddresses.length; i++) {
            uint16 oracleRating = request.oracleRatings[request.oracleAddresses[i]];
            uint16 oracleReputation = reputations[i];
            
            uint64 oracleScore = oracleRating * (oracleReputation + 1)**2;
            
            if (oracleScore >= bestOracleScore) {
                bestOracleScore = oracleScore;
                bestOracleAddress = request.oracleAddresses[i];
            }
            
            ratings[i] = oracleRating;
        }
        
        controller.submitContractOracleRatings(request.oracleAddresses, ratings);
        
        bytes32 tokenID = keccak256(abi.encodePacked(request.doctor, bestOracleAddress, block.timestamp));
        
        emit tokenCreatedDoctor(tokenID, bestOracleAddress);
        emit tokenCreatedOracle(tokenID, request.doctor);

        controller.submitDoctorToken(request.doctor, tokenID, bestOracleAddress);
        controller.submitOracleToken(bestOracleAddress, tokenID, request.doctor);
        
    }
    
    
}