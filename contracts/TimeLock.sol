// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/* 

we need to send back some amount to the smart contract and remaining to the lender
when the sender was not repayed loan on the correct time


*/

contract Timelock {

    struct Beneficiary {
        address payable beneficiaryAddress; // for whom we want to send the amount
        uint releaseTime; 
        uint256 amount ;
    }

    Beneficiary[] public beneficiaries;

    uint8 onlyOnce = 0 ;
    address owner ;
    
    constructor() payable{}

    modifier  releaseFundsCheck(uint index) {
        require(beneficiaries[index].releaseTime != 0, "The Amount was borrowed to borrower") ;
        require(beneficiaries[index].releaseTime != 1, "The Amount was transferred to the lender") ;
        require(block.timestamp >= beneficiaries[index].releaseTime, "Release time has not yet arrived");
        _;
    }



    modifier addBenficiaryCheck(uint _releaseTime){
        require(_releaseTime > block.timestamp, "Release time must be in the future");
        _;
    }

    modifier onlyOnceCheck(){
        require(onlyOnce == 0, "Only once the function is callable") ;
        _;
    }

    modifier isOwner(){
        require(msg.sender == owner, "only owner can call the function") ;
        _;
    }

    modifier removeBenficiaryCheck(uint index) {
        require(beneficiaries[index].releaseTime != 0 && beneficiaries[index].releaseTime != 1,
         "Already Amount was transfered to either back to borrower or to lender") ;
        _;
    }

    function release(uint index) public payable releaseFundsCheck(index) isOwner() {
        uint amount = address(this).balance / beneficiaries.length;
        require(amount > 0, "No funds to release");
        beneficiaries[index].beneficiaryAddress.transfer(amount);
        beneficiaries[index].releaseTime = 1 ; // means the release function is called by the lender 
        // if the borrower doesn't pay the money
    }


    function addBeneficiary(address payable _beneficiaryAddress, uint _releaseTime, uint amount) public payable
    addBenficiaryCheck(_releaseTime) isOwner() {
        beneficiaries.push(Beneficiary(_beneficiaryAddress, _releaseTime, amount));
    }


    function removeBenficiary(uint index, address _borrower) public payable removeBenficiaryCheck(index) isOwner() returns(bool){
        // this function is called when the user pays the loan in correct time
        beneficiaries[index].releaseTime = 0 ; // the amount will be borrowed to the borrower
        // Now we will send the amount to the borrower
        payable(_borrower).transfer(beneficiaries[index].amount) ; // transferring fund to the borrower
        return true ;
    }


    function setOwner(address _owner) public onlyOnceCheck(){
        owner = _owner ; // here we are setting the Lending and borrowing owner
        // only these functions are callable by the Lending and Borrowing smart contract
        onlyOnce += 1 ;
    }

    


}
/*

1695385193286
0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,1695385193286,500000000000000000
*/