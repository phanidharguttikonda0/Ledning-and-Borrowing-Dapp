// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "./IRTToken.sol" ;
import "./TimeLock.sol" ;

/* 

Due to the increase of the contract byte code , we are going to add the pricedrop function to the 
TimeLock contract by passing the past ether price only with out sending the borrower address and time stamp
and also,we will get doubt that we are not passing this function to the IRTToken right, basically we are
inherting the IRTToken , so what ever we include in that contract that will also effect the contract size
by increase in bytecode because the bytecode of the IRTToken is also included in this contract

    
*/

/* 
    Using functions instead of modifiers for writing the require or assert statements can decrease the 
    byte code of the contract's size, but that not effect a large change in the byte code but a small change
*/


contract LendingandBorrowing is IRTToken{

    // here creating the details of the loan
    struct loan {
        address borrower;
        address lender;
        uint256 amount ; // taken amount in IRT
        uint256 collateralAmount ;
        uint256 amountTobePaid ; // the amount to be paid in IRT tokens in order to get the collateral back
        uint256 loanTimeStamp ; // the time borrower assigned for loan
        uint256 durationTime ;
        uint256 lenderTimeStamp ; // the time stamp when the lender assigned payment
        /* 
        The duration time should be less than or equals to one year only, and the unix time will be converted
        in front-end and normal time is also get converted in to unix is also from fron-end itself
        */
        bool loanCleared ; // by default false
        uint256 index ; // until the lender assigned it will be the index of the borrowers
        // after lender assigned the loan it will be the benficiary index
        uint256 past_eth_price_in_rupees ;
    }



    // constructor

    constructor(address timelock) {
        lock = Timelock(timelock) ; // we will change the address after we deployed the time lock smart contract
    }



    // state of the Blockchain
    mapping(address => loan[]) public clearedLoans1 ; // for lender
    mapping (address => loan[]) public clearedLoans2 ; // for borrowers
    mapping(address => loan[]) public currentLoans1 ; // for lender who given loans to a borrower
    mapping(address => loan[]) public currentLoans2 ; // borrowers who has to pay the loan
    mapping(address => mapping(uint256 => loan)) public getLoan; 
    loan [] public  borrowers ; // list of borrowers who didn't get the lender
    uint benficiaryIndex = 0 ;
    Timelock lock ;



    // events that are emmited

    /* 
    
    Here the time stamp means the loancreated timestamp only not loanassignedtimestamp

    Means when an event is emitted we can use an alert like things using the details of the emitted event 

    
    */
    event LoanTaken(address _borrower, uint256 timestamp, uint256 _requestedAmount, uint256 collateralAmount) ;

    event Loanassigned(address _lender, address _borrower, uint256 timestampofloanassigned, 
    uint256 loancreatedtimestamp, uint256 totalAmount);

    event LoanRepayed(address _borrower, address _lender, uint timestamp, uint amountPaid, uint repayedtimestamp) ;

    event withdrawColletaralAmount(address lender, address borrower, uint timestamp, uint withdrawedAmount,
    uint withdrawltimestamp) ;

    event LoanRemoved(address borrower, uint timestamp, uint removedtimestamp) ;


    // modifiers for checking the elgibility to call a function

    function loanChecker_(uint256 _amount, uint256 durationtime) private view {
        
        // here we nedd to check whether sended amount is sufficient for the collateral Amount
        require(msg.value >= collateralCalculator(_amount, getCurrentETHPriceInRupees()), "Insufficient Amount has been sent") ;

        // and also duration time is less than or equals to one year (or) not
        require(isdurationTimelessthatOneyear(durationtime), "loan can only be given with in less than the one year") ;
    }


    modifier loanChecker(uint256 _amount, uint256 durationtime){
        loanChecker_(_amount, durationtime) ;
        _;
    }

    function loanAssigChecker_(address borrower, uint256 timestamp) private view{
                // we will check whether the user has the balance in his IRTtokens account
        require(balanceOf(msg.sender) >= getLoan[borrower][timestamp].amount, "Insufficient balance") ;
        require(msg.sender != borrower, "") ;
    }

    modifier loanAssigChecker(address borrower, uint256 timestamp){
        loanAssigChecker_(borrower, timestamp) ;
        _;
    }



    function repayLoanCheck_(address borrower, uint256 timestamp) private view {

         require(getLoan[borrower][timestamp].lenderTimeStamp != 0 ,"Cannot repay the loan without given by any lender") ;

        // firstly we will check whether the repayment time is completed or not 
        // should repay before 10 minutes before the deadline is acceptable.
        uint time = getLoan[borrower][timestamp].lenderTimeStamp + getLoan[borrower][timestamp].durationTime ; 
        require(time > block.timestamp+600, "Deadline before 10 min is not acceptable") ;
        
        // checking whether the balance of the IRTtokens are sufficient or not
        require(balanceOf(borrower) >= getLoan[borrower][timestamp].amountTobePaid,"Insufficient balance") ;
    }

    modifier repayLoanCheck(address borrower, uint256 timestamp){
        
        repayLoanCheck_(borrower, timestamp);
        _;
    }


    function removeLoanChecker_(uint256 timestamp) private view{
        require(getLoan[msg.sender][timestamp].lender == address(0), "Loan is assigned, no way to remove the loan");
    }

    modifier removeLoanChecker(uint256 timestamp){
        removeLoanChecker_(timestamp) ;
        _;
    }


    function withdrawCollateralCheck_(address borrower, uint256 timestamp) private view {
        require(getLoan[borrower][timestamp].lender == msg.sender, "only lender can withdraw funds") ;

        uint256 lastTime = getLoan[borrower][timestamp].loanTimeStamp + getLoan[borrower][timestamp].durationTime ;
        int256 pricedropcheck = pricedropedby(getLoan[borrower][timestamp].past_eth_price_in_rupees, 
        getCurrentETHPriceInRupees());
        require(lastTime >= block.timestamp || pricedropcheck >= 40, "still there is time and price is not droped yet") ;
    }
    modifier withdrawCollateralCheck(address borrower, uint256 timestamp) {

        withdrawCollateralCheck_(borrower, timestamp) ;
        _;
    }


    // functions

        function getcurrentLoansofLender() public view returns(loan[] memory){
        return currentLoans1[msg.sender] ;
    }


    function getcurrentLoansofBorrower() public view returns(loan[] memory){
        return currentLoans2[msg.sender] ;
    }


    function getcompletedLoansofLender() public view returns(loan[] memory){
        return clearedLoans1[msg.sender] ;
    }


    function getcompletedLoansofBorrower() public view returns(loan[] memory){
        return clearedLoans2[msg.sender] ;
    }


    function takeLoan(uint256 _amount, uint256 durationTime) public payable loanChecker(_amount, durationTime) 
    returns(bool){
        
        // collateral calculateral
        uint256 collateralAmount = collateralCalculator(_amount, getCurrentETHPriceInRupees());

        // loan amount to be paid in IRT
        uint256 loanAmount = loanCalculator(_amount);

        uint256 timestamp = block.timestamp ;

        // creating the loan document

        loan memory document = loan(msg.sender, address(0), _amount,  collateralAmount, loanAmount,
        timestamp, durationTime, 0, false, currentLoans2[msg.sender].length, getCurrentETHPriceInRupees()) ;

        // adding to current borrower loans
        currentLoans2[msg.sender].push(document) ;

        // adding it in to the borrowers list with no lenders
        borrowers.push(document) ;

        getLoan[msg.sender][timestamp] = document ;

        emit LoanTaken(msg.sender, timestamp, _amount, collateralAmount);

        return true ; // all goes well

    }

    // if a function is calling a payable function then that function should also be payable inorder to
    // send ethers to that contract
    function assignLoan(uint256 timestamp // time stamp of the loan becuase the borrower has so many loans
    , address borrower, uint indexofBorrowers) public payable loanAssigChecker(borrower, timestamp) returns(bool){

        //console.log("trying to transfer the amount") ;
        // directly transfer funds to the borrower
        transfer(borrower, getLoan[borrower][timestamp].amount);

        // now we need to fill the gaps in the loan document
        loan memory p = getLoan[borrower][timestamp] ;

        p.lender = msg.sender ;
        p.lenderTimeStamp = block.timestamp ;

        // we are going to make the borrower address to 0x.. address inorder to not to loan on the UI
        borrowers[indexofBorrowers].borrower = address(0) ;
        // when the borrowers address is zero we will not load them on the front-end webpage

        // assigning the document to the current loans of lender
        currentLoans1[msg.sender].push(p) ;

        currentLoans2[borrower][p.index].lender = msg.sender ;
        currentLoans2[borrower][p.index].lenderTimeStamp = p.lenderTimeStamp ;
        currentLoans2[borrower][p.index].index = benficiaryIndex ;

        getLoan[borrower][p.loanTimeStamp].lender = msg.sender ;
        getLoan[borrower][p.loanTimeStamp].lenderTimeStamp = p.lenderTimeStamp ;
        getLoan[borrower][p.loanTimeStamp].index = benficiaryIndex ;


        // testing purpose 
        //console.log(currentLoans2[msg.sender][0].lender == msg.sender) ; // we should get printed true overhere

        // now in the time lock we will send all the funds just by taking the 6% of funds from the intreast rate
        // of the collateral Amount
        uint256 intreastAmount = p.collateralAmount / 3 ;
        uint256 commisionAmount = (intreastAmount * 6)/ 100 ;

        //console.log(intreastAmount) ;
        //console.log(commisionAmount) ;

        // we will call the time clock contract by adding the benficary by detecting the commissionAmount 
        // from the actual collateralAmount 
        p.index = benficiaryIndex ;
        //console.log("haa") ;
        
        lock.addBeneficiary{value: (p.collateralAmount-commisionAmount)}(payable(msg.sender), 
        (p.durationTime+p.lenderTimeStamp), (p.collateralAmount-commisionAmount));


        emit Loanassigned(msg.sender, borrower, p.lenderTimeStamp, p.loanTimeStamp, p.amount);


        benficiaryIndex += 1 ;
        //console.log("hey") ;
        return true ; // on successfully assigned loan
    }


    function repayLoan(uint256 timestamp) public payable repayLoanCheck(msg.sender, timestamp) returns(bool){

        // firstly transfer the amount to the lenders account and then remove the benficiary 
        loan memory document1 = getLoan[msg.sender][timestamp] ;

        //here we need to add extra statement 3% from the intreast is taken by the smart contract
        uint256 intreastAmount = document1.amount/4 ;
        uint256 commissionAmount = intreastAmount * 3 / 100 ;

        transfer(document1.lender, document1.amountTobePaid - commissionAmount);
        transfer(address(this), commissionAmount); 

        // Actually we are taking 6% intreast over from the colletral right, when borrower repays
        // we will resend 3% ether back to him

        uint256 intreastAmount2 = document1.amount / 4 ; // we will get the intreast amount
        // the intreast amount is 25% per year
        uint256 commisionAmount2 = (intreastAmount2 * 3) / 100 ;

        payable(msg.sender).transfer(commisionAmount2) ; // we are transferring the remaining 3% intreast


        lock.removeBenficiary(document1.index, msg.sender); // removed the benficiary and transfered funds
        // back to the borrower

        removeCurrentLoan(document1, timestamp) ;

        delete getLoan[msg.sender][timestamp] ;

        emit LoanRepayed(msg.sender, document1.lender, timestamp,  document1.amountTobePaid - commissionAmount,
        block.timestamp);

        return true ;
    }


    function removeLoan(uint256 timestamp) public removeLoanChecker(timestamp) returns(bool){
        
        delete getLoan[msg.sender][timestamp] ;

         bool b = false ;
        for(uint i = 0 ; i < currentLoans2[msg.sender].length ; i++){
            if(b){
                currentLoans2[msg.sender][i - 1] = currentLoans2[msg.sender][i] ;
            }
            if(currentLoans2[msg.sender][i].loanTimeStamp == timestamp){
                b = true ;
            }
        }
        currentLoans2[msg.sender].pop() ;

        emit LoanRemoved(msg.sender, timestamp, block.timestamp);

        return true ;
    } // deletes the loan before lender gives the loan


    function withdrawCollateral(address borrower, uint256 timestamp) public payable
    withdrawCollateralCheck(borrower,timestamp) returns(bool){// only this function is callebale of the lender

        loan memory document1 = getLoan[borrower][timestamp] ;

        // calling the timelock contract 
        lock.release(document1.index) ; // if the price drops by 25% intreast or he may not pay within the duration time
        // the whole funds can we withdrawn the lender

        // the amount is transfered to the lender

        removeCurrentLoan(document1, timestamp); // it will also add the payment to the cleared loan


        emit  withdrawColletaralAmount(msg.sender, borrower, timestamp, document1.collateralAmount,
        block.timestamp);

        return true ; // successfully withdrawed the funds
    } 


    function removeCurrentLoan(loan memory document1, uint256 timestamp) private {
                // we will iterate over the list of lender and borrowers account and delete them from the 
        // current loans
        bool b = false ;
        for(uint i = 0 ; i < currentLoans2[msg.sender].length ; i++){
            if(b){
                currentLoans2[msg.sender][i - 1] = currentLoans2[msg.sender][i] ;
            }
            if(currentLoans2[msg.sender][i].loanTimeStamp == timestamp){
                b = true ;
            }
        }
        currentLoans2[msg.sender].pop() ;

        // now we need to delete from the lender current loans as well
        b = false ;
        for(uint i = 0 ; i < currentLoans1[msg.sender].length ; i++){
            if(b){
                currentLoans1[document1.lender][i - 1] = currentLoans1[document1.lender][i] ;
            }if(currentLoans1[document1.lender][i].loanTimeStamp == timestamp) b = true ;
        }

        currentLoans1[document1.lender].pop() ;

        // adding to the completed loans list 

        document1.loanCleared = true ;
        
       // now add the document to the completedPayments list by removing it from the repayLoans
        clearedLoans1[document1.lender].push(document1) ;
        clearedLoans2[msg.sender].push(document1) ;

    }


        function pricedropedby(uint past_eth_price_in_rupees, uint current_eth_price) public pure  returns(int256){

        

        // past we will get the number of tokens for one eth rupees
        uint256 number_of_tokens_past = past_eth_price_in_rupees / 100 ; // we will get number of tokens

        // present we will get the number of tokens for one eth rupees
        uint256 number_of_tokens_present = current_eth_price/ 100 ; // we will get present number of tokens


        
        // we try to do current - past we should get the out-put greater than zero
        uint difference = number_of_tokens_present - number_of_tokens_past ;


        if(difference < 0){
            // we need to find the drop by percentage that the ether price droped
            int256 percentage_drop = int256(((int256(number_of_tokens_past) - int256(number_of_tokens_present)) * 100) 
            / int256(number_of_tokens_past));
            return percentage_drop ;
        }else{
            // we are gonna return zero if there is no change if positive we will return 1
            //which represents that there is some gain in the ether price
            if(difference == 0) return 0 ; else return 1 ;
        }
    }


            function collateralCalculator(uint256 _amount, uint currentEthPrice) public pure returns(uint256){
        // now we need to calculate the collateral
        uint oneRuppeWei = 1000000000000000000 / currentEthPrice ; // one rupee in wei

        return ((_amount*100)*oneRuppeWei)+(((_amount*100)*oneRuppeWei)/2) ; 
        // now we are gonna get total wei for n*n/2 number of tokens
    }

    

    function loanCalculator(uint256 _amount /* Amount in IRT */) public pure returns(uint256){
        // it will returns the loan amount to be cleared in IRT tokens
        return (_amount) + (_amount/4) ; // total amount+amount.5 should be the loan amount
    }


    function isdurationTimelessthatOneyear(uint256 durationtime) public pure returns(bool){
        if(durationtime <= 31536000) return true ; // 31,536,000 this represents one year time in unix time system
        else return false ;
    }



}




