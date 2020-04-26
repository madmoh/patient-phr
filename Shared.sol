pragma solidity <0.7.0;

library Shared {
    // Structs
    struct Record {
        byte permissions; // Access rules
        
        mapping(uint => Request) requests;
        uint requestCount;

        // TODO: uint bundleSize; // Can be requested from IPFS through oracles to measure throughput instead of latency
    }
    
    struct Request {
        address doctor; // Requester
        uint256 requestTime; // Time of receiving a request
        uint8 minOracleCount;
        uint8 maxOracleCount;
        
        bool grant; // Decision of patient to consent or not
        
        bool oraclesEvaluated;
        address[] oracleAddresses;
        mapping (address => uint16) oracleRatings;
    }
    
    struct Patient {
        bool registered;
    }
    
    struct Doctor {
        bool registered;
        
        bytes32[] tokenIDs;
        mapping (bytes32 => DoctorToken) tokens;
    }
    
    struct DoctorToken {
        bool exists;
        address oracleAddress;
        
        // TODO: maybe here we should have info about the file
    }

    struct Oracle {
        bool registered;
        
        uint16 averageContractRating;
        uint16 contractRatingCount;
        
        uint16 averageDoctorRating;
        uint16 doctorRatingCount;
        
        bytes32[] tokenIDs;
        mapping (bytes32 => OracleToken) tokens;
    }
    
    struct OracleToken {
        bool exists;
        address doctorAddress;
        // TODO: maybe here we should have info about the file
    }
    
    
}