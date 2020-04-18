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
        uint requestTime; // Time of receiving a request
        uint minOracleCount;
        uint maxOracleCount;
        
        bool grant; // Decision of patient to consent or not
        
        bool oraclesEvaluated;
        address[] oracleAddresses;
        mapping (address => uint) oracleRatings;
    }
    
    struct Patient {
        bool registered;
    }
    
    struct Doctor {
        bool registered;
    } 
    
    struct Oracle {
        bool registered;
        
        uint averageContractRating;
        uint contractRatingCount;
        
        uint averageDoctorRating;
        uint doctorRatingCount;
        
        bytes32[] tokenIDs;
        mapping (bytes32 => OracleToken) tokens;
    }
    
    struct OracleToken {
        bool exists;
        address doctorAddress;
        // TODO: maybe here we should have info about the file
    }
    
    
    // Functions
    // function checkPublicKey(bytes memory _publicKey) public returns (bool) {
    //     // 2 ** 160 - 1 == 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    //     return (uint(keccak256(_publicKey)) & (0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == uint(msg.sender);
    // }
    
}