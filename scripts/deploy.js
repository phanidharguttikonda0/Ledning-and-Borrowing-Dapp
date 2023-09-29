// scripts/deploy.js
async function main() {
  // const MyContract1 = await ethers.getContractFactory("IRTToken");
  // const MyContract2 = await ethers.getContractFactory("Timelock") ;
  // const myContract1 = await MyContract1.deploy();
  // const myContract2 = await MyContract2.deploy();

  // console.log(myContract1) ;
  // console.log(myContract2) ;
  // console.log("IRT token Contract address", myContract1.address);
  // console.log("Time Lock Contract address",myContract2.address) ;
  const LendingandBorrowingContract = await ethers.getContractFactory("LendingandBorrowing") ;
  const myContract3 = await LendingandBorrowingContract.deploy("0xcfc39E56621E9618b5973995EF2f558d39493E80") ;
  console.log(myContract3) ;
  console.log(myContract3.address) ;
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// IRTToken address -> 0x4624E126698e8A218A627a7cDAFAf02B5E96b694
// Time lock Contract address -> 0xb9a9E33686b0C8fd57445e968aA015fe1107c117
// Lending and Borrowing Smart contract - > 0x850F3B5150c41B5f30bCcfAA2543A0d9C348c996
// Deployed on the ganache local blockchain

// npx hardhat run scripts/deploy.js --network development
