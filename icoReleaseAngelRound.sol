// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";
import "./Token.sol";
import "./SafeMath.sol";
import "./UtilityFunctions.sol";


contract MudAngelRoundReleaseBank {
    using SafeMath for uint256;
     
    address admin;//contract creator
    uint256 constant angelRoundLimit = 50000000000000; //angel round total limit 50000000 MUD
    uint256 constant dailyRate = 79365; //0.00079365 angel round daily release percentage 0.079365%
    uint constant secPerDay = 86400;
    //address mudtTokenContractAddr; 
    MudTestToken token;
                                               
    struct Transaction {
        bool locked;
        uint lastTime;
        uint256 balance;
        uint256 dailyReleaseAmount;
    }
    
    mapping(address => Transaction) bank;
    
    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin can deposit.");
        _;
    }
    
    constructor() public {
        admin = msg.sender;
        token = UtilityFunctions.getMudToken();//MudTestToken(mudtTokenContractAddr);
    }
    
    
    /*only the contractor creator could deposit ico to investor
    * lock the ico coins to the angelround daily release contract 
    * parameters:
    *     investorAddress: angel round investor address 
    *     amount: amount of MUD coin received from angel round 
    * return:  total coins locked in the contract
    */
    function icoDeposit(address investorAddress, uint256 amount) onlyAdmin public returns (uint256) {
        require(bank[investorAddress].balance == 0, "balance is not 0.");
        require(amount > 0, "amount should > 0");
        address contractorAddr = address(this);
        require(amount + token.balanceOf(contractorAddr) <= angelRoundLimit, "amount overflow!");
        require(!bank[investorAddress].locked, "already locked.");
         
        bank[investorAddress].lastTime = now;
        bank[investorAddress].balance = amount;
        bank[investorAddress].dailyReleaseAmount = amount.mul(dailyRate).div(100000000); //amount * dailyRate / 100000000;
        bank[investorAddress].locked = true;
        token.icoTransferFrom(msg.sender, contractorAddr, amount);
        
        return token.balanceOf(contractorAddr);
    }
    
    
    /* investor call this function from the dapp to check the amount of their coins in the angel round locked contract
     * parameters: adressIn: for admin account it can be any investor address, for investor the adressIn is not used 
     * returns: 
     *         (free MUD coins ready for withdraw, total MUD coins of the investor in the contract)
     */
    
    function checkBalance(address addressIn) public view returns  (uint256 , uint256 ) {
        require(addressIn != address(0));
        
        address addressToCheck = msg.sender;
        
        if (msg.sender == admin) {
            addressToCheck = addressIn;
        }

        require(now > bank[addressToCheck].lastTime, "now < last release time");
        
        if (bank[addressToCheck].balance <= 0) {
            return (0, 0);
        }
        
        uint256 freeAmount = (now - bank[addressToCheck].lastTime) / secPerDay * bank[addressToCheck].dailyReleaseAmount;
        
        if (freeAmount > bank[addressToCheck].balance) {
            freeAmount = bank[addressToCheck].balance;
        }

        return (freeAmount, bank[addressToCheck].balance);
    }
    
    /* release the free tokens to the investor's wallet address
     * parameters: NONE 
     * returns:  (released amount, amount still locked in the contract)
     */
    
    function releaseToken() public returns  (uint256, uint256) {
        require(msg.sender != admin, "msg.send == admin");
        require(bank[msg.sender].balance > 0, "balance <= 0");
        require(now > bank[msg.sender].lastTime + secPerDay, "now < lastTime");
        
        //calculate free amount
        uint256 freeAmount = (now - bank[msg.sender].lastTime) / secPerDay * bank[msg.sender].dailyReleaseAmount;
        
        if (freeAmount > bank[msg.sender].balance) {
            freeAmount = bank[msg.sender].balance;
        }
        
        bank[msg.sender].lastTime = now;
        bank[msg.sender].balance = bank[msg.sender].balance.sub(freeAmount);
        token.transfer(msg.sender, freeAmount);

        
        return (freeAmount, bank[msg.sender].balance);
    }
    
}