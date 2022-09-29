// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";
import "./Token.sol";
import "./SafeMath.sol";
import "./UtilityFunctions.sol";


contract MudTeamReleaseBank {
    using SafeMath for uint256;
    uint immutable teamLockingStart; 
    address immutable admin;
    uint256 constant teamMemberBalance = 1.6e14;//160000000000000; //160000000 MUD
    uint256 constant dailyRate = 92590; //0.0009259 daily release rate 0.09259%
    uint constant secPerYear = 31536000;
    uint constant secPerDay = 86400;
    uint256 private _icoDepositTotal;
    bool private _icoFinished;

    event icodeposit(address indexed investorAddress, uint256 amount, uint256 balance);

    MudTestToken token;
                                               
    struct Transaction {
        bool locked;
        uint lastTime;
        uint256 balance;
        uint256 dailyReleaseAmount;
    }
    
    mapping(address => Transaction) bank;  
  
    constructor() public {
        teamLockingStart = now;
        admin = msg.sender;//set contract owner, which is the MetaUserDAO team administrator account with multisig transaction setup.
        token = UtilityFunctions.getMudToken();
    }
    
    
    //only the contractor creator could 
    /* lock the team MUD coins to the contract and start to release after 365 days in daily release rate
     * parameters: 
     *    teamMemberAddress : team member wallet address
     *    amount: amount of MUD to be locked
     *    
     */
    function teamMemberDeposit(address teamMemberAddress, uint256 amount) external returns (uint256) {
        require(msg.sender == admin, "Only admin can deposit.");
        require(!_icoFinished, "ICO already finished!");
        require(amount > 0, "amount should > 0");
        address contractorAddr = address(this);
        require(amount.add(_icoDepositTotal) <= teamMemberBalance, "amount overflow!");
        require(!bank[teamMemberAddress].locked && bank[teamMemberAddress].balance == 0, "already locked or balance is not 0.");
         
        bank[teamMemberAddress].lastTime = teamLockingStart + secPerYear + 1;
        bank[teamMemberAddress].balance = amount;
        bank[teamMemberAddress].dailyReleaseAmount = amount.mul(dailyRate).div(1e8); //amount * dailyRate / 100000000;
        bank[teamMemberAddress].locked = true;
        _icoDepositTotal = _icoDepositTotal.add(amount);

        require(token.transferFrom(msg.sender, contractorAddr, amount), "transferFrom faied!"); //check the return value, it should be true
        emit icodeposit(teamMemberAddress, amount, token.balanceOf(contractorAddr));
        return token.balanceOf(contractorAddr);
    }
    
     /* investor call this function from the dapp to check the amount of their coins in the  locked contract
     * parameters: adressIn: for admin account it can be any team member address, for team member the adressIn is not used
     * returns: 
     *         (free MUD coins ready for withdraw, total MUD coins of the team member in the contract)
     */
    function checkBalance(address addressIn) external view returns  (uint256 , uint256 ) {
        require(addressIn != address(0), "Blackhole address not allowed!");
        
        address addressToCheck = msg.sender;
        
        if (msg.sender == admin) {
            addressToCheck = addressIn;
        }

        require(now > bank[addressToCheck].lastTime, "Time not ready yet!");
        
        if (bank[addressToCheck].balance <= 0) {
            return (0, 0);
        }
        
        //ensure it is locked
        require(bank[addressToCheck].locked, "token not locked!"); 
        
        //The freeAmount should be matured based on exact times of the 24 hours.
        //Thus we should calculate the matured days. The leftover time which is not a whole 24 hours
        //should wait for the next mature time spot.
        uint256 maturedDays = now.sub(bank[addressToCheck].lastTime).div(secPerDay);
        uint256 freeAmount = bank[addressToCheck].dailyReleaseAmount.mul(maturedDays);//even 0 matured days will work
        
        
        if (freeAmount > bank[addressToCheck].balance) {
            freeAmount = bank[addressToCheck].balance;
        }

        return (freeAmount, bank[addressToCheck].balance);
    }
    
    
    function releaseToken() external returns  (uint256, uint256) {
        require(msg.sender != admin, "Admin not allowed !");
        require(bank[msg.sender].balance > 0, "No token available !"); //ensure this is an valid address or there is token balance
        require(bank[msg.sender].locked, "not locked!");
        require(bank[msg.sender].lastTime > teamLockingStart + secPerYear, "locking time incorrect!");
        require(now > bank[msg.sender].lastTime + secPerDay, "Only release once per day!");
        
        //The freeAmount should be matured based on exact times of the 24 hours.
        //Thus we should calculate the matured days. The leftover time which is not a whole 24 hours
        //should wait for the next mature time spot.
        uint256 maturedDays = now.sub(bank[msg.sender].lastTime).div(secPerDay);
        uint256 freeAmount = bank[msg.sender].dailyReleaseAmount.mul(maturedDays);
        
        if (freeAmount > bank[msg.sender].balance) {
            freeAmount = bank[msg.sender].balance;
        }
        
        bank[msg.sender].lastTime = bank[msg.sender].lastTime.add(maturedDays.mul(secPerDay));//should set to the exact spot based on 24 hours
        bank[msg.sender].balance = bank[msg.sender].balance.sub(freeAmount);
        require(token.transfer(msg.sender, freeAmount), "Token transfer failed!");
        
        return (freeAmount, bank[msg.sender].balance);
    }
    
    //mark the ICO finished flag, stop icoDeposit any more and return the icoDepositTotal.
    //The leftover amount will be bunt by team admininstrators by token owner account with multisig setup.
    function icoFinalised() external returns (uint256) {
        require(msg.sender == admin, "Not contractor owner!");
        require(!_icoFinished, "ICO finished already!");
        
        _icoFinished = true;
        return _icoDepositTotal;
    }
}