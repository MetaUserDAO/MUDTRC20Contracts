// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";
import "./Token.sol";
import "./SafeMath.sol";
import "./UtilityFunctions.sol";


contract MudTeamReleaseBank {
    using SafeMath for uint256;
    uint teamLockingStart; 
    address admin;
    uint256 constant teamMemberBalance = 160000000000000; //160000000 MUD
    uint256 constant dailyRate = 9259; //0.0009259
    uint constant secPerYear = 31536000;
    uint constant secPerDay = 86400;
    
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
        teamLockingStart = now;
        admin = msg.sender;
        token = UtilityFunctions.getMudToken();
    }
    
    
    //only the contractor creator could 
    /* lock the team MUD coins to the contract and start to release after 365 days in daily release rate
     * parameters: 
     *    teamMemberAddress : team member wallet address
     *    amount: amount of MUD to be locked
     *    
     */
    function teamMemberDeposit(address teamMemberAddress, uint256 amount) onlyAdmin public returns (uint256) {
        require(amount > 0, "amount should > 0");
        address contractorAddr = address(this);
        require(amount + token.balanceOf(contractorAddr) <= teamMemberBalance, "amount overflow!");
        require(!bank[teamMemberAddress].locked && bank[teamMemberAddress].balance == 0, "already locked or balance is not 0.");
         
        bank[teamMemberAddress].lastTime = teamLockingStart + secPerYear + 1;
        bank[teamMemberAddress].balance = amount;
        bank[teamMemberAddress].dailyReleaseAmount = amount.mul(dailyRate).div(10000000); //amount * dailyRate / 10000;
        bank[teamMemberAddress].locked = true;
        
        token.transferFrom(msg.sender, contractorAddr, amount);

        return token.balanceOf(contractorAddr);
    }
    
     /* investor call this function from the dapp to check the amount of their coins in the  locked contract
     * parameters: adressIn: for admin account it can be any team member address, for team member the adressIn is not used
     * returns: 
     *         (free MUD coins ready for withdraw, total MUD coins of the team member in the contract)
     */
    function checkBalance(address addressIn) public view returns  (uint256 , uint256 ) {
        require(addressIn != address(0));
        
        address addressToCheck = msg.sender;
        
        if (msg.sender == admin) {
            addressToCheck = addressIn;
        }

        require(now > bank[addressToCheck].lastTime, "now < lastTime");
        
        if (bank[addressToCheck].balance <= 0) {
            return (0, 0);
        }
        
        //ensure it is locked
        require(bank[addressToCheck].locked, "not locked!"); 
        
        if (now < teamLockingStart + secPerYear) {
            return (0, bank[addressToCheck].balance);
        }
        
        require(bank[addressToCheck].lastTime > teamLockingStart + secPerYear, "locking time incorrect!");
        require(now > bank[addressToCheck].lastTime, "now < lastTime");
        
        uint256 freeAmount = SafeMath.div(now - bank[addressToCheck].lastTime, secPerDay).mul(bank[addressToCheck].dailyReleaseAmount);
        
        if (freeAmount > bank[addressToCheck].balance) {
            freeAmount = bank[addressToCheck].balance;
        }

        return (freeAmount, bank[addressToCheck].balance);
    }
    
    
    function releaseToken() public returns  (uint256, uint256) {
        require(msg.sender != admin, "msg.send == admin");
        require(bank[msg.sender].balance > 0, "balance <= 0"); //ensure this is an valid address or there is token balance
        require(bank[msg.sender].locked, "not locked!");
        require(now > teamLockingStart + secPerYear, "in locking period!");
        require(bank[msg.sender].lastTime > teamLockingStart + secPerYear, "locking time incorrect!");
        require(now > bank[msg.sender].lastTime + secPerDay, "now < lastTime + secPerDay");
        
        //calculate free amount
        uint256 freeAmount = SafeMath.div(now - bank[msg.sender].lastTime, secPerDay).mul(bank[msg.sender].dailyReleaseAmount); 
        if (freeAmount > bank[msg.sender].balance) {
            freeAmount = bank[msg.sender].balance;
        }
        
        bank[msg.sender].lastTime = now;
        bank[msg.sender].balance = bank[msg.sender].balance.sub(freeAmount);
        token.transfer(msg.sender, freeAmount);
        
        return (freeAmount, bank[msg.sender].balance);
    }
    
}