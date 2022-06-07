const ethers = require('ethers');

// Create a wallet to sign the message with
let privateKey = '0x5b46f6c240550a849944a506bdf6963ba76d8fbdd39bcb4b938463684ea6f72e';
let wallet = new ethers.Wallet(privateKey);

console.log(wallet.address);
//0x26eBDE1A03545d03AC1B33BF52BE1C604F19cC14


let message = "Hello World";

// Sign the string message
const aaa=async() =>{
    let flatSig = await wallet.signMessage(message);
    let sig = ethers.utils.splitSignature(flatSig);

    console.log(sig.v);
    console.log(sig.r);
    console.log(sig.s); 

}
aaa()
// For Solidity, we need the expanded-format of a signature


