pragma solidity <0.7.0;
import "remix_tests.sol";
import "remix_accounts.sol";
import "./Controller.sol";
import "./PatientRecords.sol";

contract StandardTest {
    
    address controllerOwner;
    address patient;
    address doctor;
    address oracle0;
    address oracle1;
    address oracle2;
    
    Controller controller;
    PatientRecords patientRecords;
    
    function beforeAll() public {
        controllerOwner = TestsAccounts.getAccount(0);
        patient         = TestsAccounts.getAccount(1);
        doctor          = TestsAccounts.getAccount(2);
        oracle0         = TestsAccounts.getAccount(3);
        oracle1         = TestsAccounts.getAccount(4);
        oracle2         = TestsAccounts.getAccount(5);
    }
    
    // #sender: account-0
    function testControllerDeployment() public {
        controller = new Controller();
        Assert.equal(controller.owner, controllerOwner, "controllerOwner should be the owner of controller smart contract");
    }
    
    // #sender: account-1
    function testPatientRecordCreation() public {
        patientRecords = new PatientRecords(address(controller));
        Assert.equal(controller.owner, controllerOwner, "patient should be the owner of patientRecords smart contract");
    }
    
}
