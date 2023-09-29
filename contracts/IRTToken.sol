// SPDX-License-Identifier: MIT

/* 

    If you want to deploy on the sepolia testnet, then uncomment the chainlink import statement
    and the functions i commented and also uncomment some part of the getETHPRiceINRupees function
    such that we will get the live ether price in rupees , so we can dynamically get the pricedrop
    percentage based on the ether price drop, but for working with local blockchain development, don't
    do that because the deployed address of the AggregatorV3Interface doesn't find that in the local
    ganache and also make sure uncomment the pricefeed state variable and also in constructor as well


*/


pragma solidity ^0.8.17;
//import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol" ;

contract IRTToken{
    string name = "Indian Rupee TechCoin" ;
    string symbol = "IRT" ;
    uint256 totalSupply = 100000000000 ; // Each token costs 100 INR where 1 Billion tokens are there so 100 Billion worth rupees
    uint8 public decimals = 0 ;
    mapping(address => uint256) public amount ;
    // address of user => address of spender => and the amount allowed to spend
    mapping(address => mapping(address => uint256)) approvedAmount ;
    // AggregatorV3Interface pricefeed ;
    address owner ;
    constructor() {
        owner = msg.sender ;
       // pricefeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    } 



    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function amountSufficient_(uint256 _amount) private view {
        require(amount[msg.sender] >= _amount, "In-Sufficient Account Balance") ;
    }

    modifier amountSufficient(uint256 _amount) {
        amountSufficient_(_amount);
        _;
    }

    function isAmountRecieved_(uint256 _amount) private view {
        uint256 price = getCurrentETHPriceInRupees() ;
        uint256 totalAmount = _amount * 100 ;
        uint256 EtherValueForOneRupee = 1000000000000000000/price ;
        uint256 RequiredAmount = totalAmount * EtherValueForOneRupee ; // gives the value in wei
        require(msg.value >= RequiredAmount, "Send Required Amount") ;
        // here we will check how much amount of ether should be transferred
    }
    modifier isAmountRecieved(uint256 _amount) {
        isAmountRecieved_(_amount);
        _;
    }


    function SufficientBalance_(uint256 _amount, address _spender) private view {
        uint256 value = approvedAmount[msg.sender][_spender] ;
        require((amount[msg.sender]+value) >= _amount, "Insufficient Balance") ;
    }

    modifier SufficientBalance(uint256 _amount, address _spender) {
        SufficientBalance_(_amount, _spender);
        _;
    }

    function isAllowed_(uint256 _amount, address _owner) private view {
        //console.log("The modifier is called") ;
        require(allowance(_owner, msg.sender) >= _amount, "That much amount is not possible to allowed") ;
    }

    modifier isAllowed(uint256 _amount, address _owner){
        isAllowed_(_amount, _owner);
        _;
    }

    function isOwner_() private view {
        require(msg.sender == owner , "Only owner can withdraw the funds") ;
    }
    modifier isOwner() {
        isOwner_() ;
        _;
    }


    function sufficientBalance_(uint256 _amount) private view {
        require(getBalance() > _amount , "Low Account Balance") ;
    }

    modifier sufficientBalance(uint256 _amount){
        sufficientBalance_(_amount);
        _;
    }

    function Name() public view returns (string memory) {
        return name ;
    }

    function Symbol() public view returns(string memory){
        return symbol ;
    }

    function TotalSupply() public view returns(uint256){
        return totalSupply ;
    }

    function transfer(address _to, uint256 _amount) public amountSufficient(_amount) returns(bool){ // used to transfer from his account to other
        amount[_to] += _amount ;
        amount[msg.sender] -= _amount ;
        totalSupply -= _amount ;
        emit Transfer(msg.sender, _to, _amount);
        return true ;
    }

    function _mint(uint256 _amount) public payable isAmountRecieved(_amount) {
        // here we will directly mint the amount of ethere into the user
        amount[msg.sender] += _amount ;
        totalSupply -= _amount ;
    }

    function getCurrentETHPriceInRupees() public pure returns(uint){
       // (, int price, , , ) = pricefeed.latestRoundData();
       // return (uint256(price/1e8) * 80);
       return 132800 ;
    }

   /* function getDescription() public view returns(string memory){
        return pricefeed.description() ;
    } */

    function transferFrom(address _from , address _to , uint256 _amount) public isAllowed(_amount, _from) returns(bool){
        //console.log("Hey function called") ;
        amount[_to] += _amount ;
        approvedAmount[_from][msg.sender] -= _amount ;
        return true ;
    }

    function approve(address _spender, uint256 _value) public SufficientBalance(_value, _spender) returns (bool success){
        // this function is used to allow the smartcontracts to spend the amount of money from the user
        if(approvedAmount[msg.sender][_spender] != 0){
            amount[msg.sender] += approvedAmount[msg.sender][_spender] ;
            approvedAmount[msg.sender][_spender] -= approvedAmount[msg.sender][_spender] ;
        }
        amount[msg.sender] -= _value ;
        approvedAmount[msg.sender][_spender] = _value ; // now the spender can use this much of amount
        emit Approval(msg.sender, _spender, _value);
        return true ;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining){
        require(msg.sender == _owner || _spender == msg.sender,"Here only owner or spender can access the function ") ;
        remaining = approvedAmount[_owner][_spender] ;
    }

    function withdraw(uint256 _amount) public isOwner() sufficientBalance(_amount) returns(bool success){
        success = payable (msg.sender).send(_amount);
        require(success, "Unable to transfer") ;
    }

    function getBalance() public isOwner() view returns(uint256){
        return address(this).balance ;
    }

    function balanceOf(address user) public view returns(uint256) {
        return amount[user] ;
    }

}
// 0x58702997c9ad73283e9DbDa08E1Da9A8890590A4,0xb21b58d830053167def917c99540c7ee2d4567f5,50