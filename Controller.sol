pragma solidity <0.7.0;

import "./Shared.sol";

contract Controller {
    // State variables
    address owner;
    mapping (address => Shared.Patient) public patients;
    mapping (address => Shared.Doctor) public doctors;
    mapping (address => Shared.Oracle) public oracles;

    
    // Modifier
    modifier notOwner {
        require(msg.sender != owner);
        _;
    }
    
    modifier onlyNotRegistered {
        require(!patients[msg.sender].registered);
        require(!doctors[msg.sender].registered);
        require(!doctors[msg.sender].registered);
        _;
    }
    
    
    // Constructor
    constructor() public {
        owner = msg.sender;
    }

    // Add patient
    function addPatient() public onlyNotRegistered notOwner {
        Shared.Patient memory patient = Shared.Patient(true);
        patients[msg.sender] = patient;
    }
    
    // Add and check registration doctor
    function addDoctor() public onlyNotRegistered notOwner {
        Shared.Doctor memory doctor = Shared.Doctor(true);
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
    function getOracleReputations(address[] memory _oracleAddresses) view public returns (uint[] memory) {
        uint[] memory reputations = new uint[](_oracleAddresses.length);

        // NOTE: we are assuming oracleAddresses 
        for (uint i = 0; i < _oracleAddresses.length; i++) {
            Shared.Oracle memory oracle = oracles[_oracleAddresses[i]];
            
            reputations[i] = (oracle.averageContractRating + oracle.averageDoctorRating) / 2;
        }
        
        return reputations;
    }
    
    function submitContractOracleRatings(address[] memory _oracleAdresses, uint[] memory _ratings) public onlyNotRegistered {
        for (uint i = 0; i < _oracleAdresses.length; i++) {
            Shared.Oracle storage oracle = oracles[_oracleAdresses[i]];
            oracle.averageContractRating = (oracle.contractRatingCount * oracle.averageContractRating + _ratings[i]) / (oracle.contractRatingCount + 1);
            oracle.contractRatingCount += 1;
        }
    }
    
    function submitOracleToken(address _oracleAddress, bytes32 _tokenID, address _doctorAddress) public onlyNotRegistered {
        oracles[_oracleAddress].tokenIDs.push(_tokenID);
        oracles[_oracleAddress].tokens[_tokenID] = Shared.OracleToken(true, _doctorAddress);
    }
    
    // TODO: think about the correct modifier here
    function submitDoctorOracleRating(bytes32 _tokenID, address _oracleAddress, uint _rating) public {
        require(oracles[_oracleAddress].tokens[_tokenID].exists);
        Shared.Oracle storage oracle = oracles[_oracleAddress];
        oracle.averageDoctorRating = (oracle.contractRatingCount * oracle.averageContractRating + _rating) / (oracle.contractRatingCount + 1);
        oracle.doctorRatingCount += 1;
    }
}