pragma solidity <0.7.0;

import "./Shared.sol";

contract Controller {
    // State variables
    address public owner;
    mapping (address => Shared.Patient) public patients;
    mapping (address => Shared.Doctor) public doctors;
    mapping (address => Shared.Oracle) public oracles;

    
    // Modifier
    modifier notOwner {
        require(msg.sender != owner, "Controller owner account cannot call this function");
        _;
    }
    
    modifier onlyNotRegistered {
        require(!patients[msg.sender].registered, "Unregistered account required");
        require(!doctors[msg.sender].registered, "Unregistered account required");
        require(!oracles[msg.sender].registered, "Unregistered account required");
        _;
    }
    
    
    // Constructor
    constructor() public {
        owner = msg.sender;
    }

    // Add patient
    function addPatient() public onlyNotRegistered notOwner {
        Shared.Patient memory patient;
        patient.registered = true;
        
        patients[msg.sender] = patient;
    }
    
    // Add and check registration doctor
    function addDoctor() public onlyNotRegistered notOwner {
        Shared.Doctor memory doctor;
        doctor.registered = true;
        
        doctors[msg.sender] = doctor;
    }
    
    function isDoctorRegistered(address doctorAddress) view public returns (bool) {
        return doctors[doctorAddress].registered;
    }
    
    // Add and check registration oracles
    function addOracle() public onlyNotRegistered notOwner {
        Shared.Oracle memory oracle;
        oracle.registered = true;
        oracle.averageContractRating = 50;
        oracle.contractRatingCount = 0;
        oracle.averageDoctorRating = 50;
        oracle.doctorRatingCount = 0;
        
        oracles[msg.sender] = oracle;
    }
    
    function isOracleRegistered(address _oracleAddress) view public returns (bool) {
        return oracles[_oracleAddress].registered;
    }
    
    // TODO: maybe add a modifier
    function getOracleReputations(address[] memory _oracleAddresses) view public returns (uint16[] memory) {
        uint16[] memory reputations = new uint16[](_oracleAddresses.length);

        // NOTE: we are assuming oracleAddresses 
        for (uint16 i = 0; i < _oracleAddresses.length; i++) {
            Shared.Oracle memory oracle = oracles[_oracleAddresses[i]];
            
            reputations[i] = (oracle.averageContractRating + oracle.averageDoctorRating) / 2;
        }
        
        return reputations;
    }
    
    function submitContractOracleRatings(address[] memory _oracleAdresses, uint16[] memory _ratings) public onlyNotRegistered {
        for (uint16 i = 0; i < _oracleAdresses.length; i++) {
            Shared.Oracle storage oracle = oracles[_oracleAdresses[i]];
            oracle.averageContractRating = (oracle.contractRatingCount * oracle.averageContractRating + _ratings[i]) / (oracle.contractRatingCount + 1);
            oracle.contractRatingCount += 1;
        }
    }
    
    function submitDoctorToken(address _doctorAddress, bytes32 _tokenID, address _oracleAddress) public onlyNotRegistered {
        doctors[_doctorAddress].tokenIDs.push(_tokenID);
        doctors[_doctorAddress].tokens[_tokenID] = Shared.DoctorToken(true, _oracleAddress);
        
    }
    
    function submitOracleToken(address _oracleAddress, bytes32 _tokenID, address _doctorAddress) public onlyNotRegistered {
        oracles[_oracleAddress].tokenIDs.push(_tokenID);
        oracles[_oracleAddress].tokens[_tokenID] = Shared.OracleToken(true, _doctorAddress);
        
    }
    
    // TODO: think about the correct modifier here
    function submitDoctorOracleRating(bytes32 _tokenID, address _oracleAddress, uint16 _rating) public {
        require(oracles[_oracleAddress].tokens[_tokenID].exists &&
                doctors[msg.sender].tokens[_tokenID].exists,
                "Valid token required");
                
        require(oracles[_oracleAddress].tokens[_tokenID].doctorAddress == msg.sender &&
                doctors[msg.sender].tokens[_tokenID].oracleAddress == _oracleAddress,
                "Valid token required");
        
        Shared.Oracle storage oracle = oracles[_oracleAddress];
        oracle.averageDoctorRating = (oracle.contractRatingCount * oracle.averageContractRating + _rating) / (oracle.contractRatingCount + 1);
        oracle.doctorRatingCount += 1;
    }
}