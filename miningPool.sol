// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";
import "./Token.sol";
import "./SafeMath.sol";
import "./UtilityFunctions.sol";


contract MudMiningPool {
    using SafeMath for uint256;
    
    //mining DAPP address should be set at the contract deployment time to the correct one
    //this is the address that MUD Mining DAPP used to interact with the daily settlement function
    address constant miningDappAddress = address(0x4158255d3f5c3faba166fa4b9ccdf108b7f7cf128e);
    
    struct Transaction {
        uint startTime;
        uint endTime;
        uint256 amount;
     }
     
    
    MudTestToken token;
    address admin;
    uint lastHalvingTime;
    uint lastDailySettlementTime;
    uint256 dailyMiningLimit;
    
    uint256 private _totalFreeAmount;
    mapping (address => uint256) private _minedToken;
    
    constructor() public {
        admin = address(msg.sender);
        token = UtilityFunctions.getMudToken();
        dailyMiningLimit = 104166660000; //104166.66 MUD per day
    }
    
    function icoDeposit(uint256 amount) external returns (uint256) {
        require(msg.sender == admin, "only admin allowed!");
        require(amount == 450000000000000); //should be 45% of total coins, 450000000 MUD
        require(token.balanceOf(address(this)) == 0);//only deposit once after ICO
        
        token.transferFrom(msg.sender, address(this), amount);
        
        return token.balanceOf(address(this));
    }
    
    function miningStart() public returns (uint) {
        require(msg.sender == miningDappAddress, "only dapp admin allowed!"); //only dapp address could start miningDappAddress
        require(lastHalvingTime == 0, "only start once!");
        
        lastHalvingTime = now;
        
        return lastHalvingTime;
    }
    
    //dapp will call this once a day for settlement
    function dailySettlement(address[] calldata addressArray, uint256[] calldata balanceArray) external returns (uint256){
        require(msg.sender == miningDappAddress, "only dapp admin allowed!");
        require(lastHalvingTime > 0, "mining not started !");
        require(now > lastDailySettlementTime + 86400, "only settle once per day"); //86400
        require(addressArray.length == balanceArray.length, "arr length not match");
        
        lastDailySettlementTime = now;
        
        //update mining halving dailyMiningLimit every 4 years
        if (now > lastHalvingTime + 31536000) {
            dailyMiningLimit = dailyMiningLimit.div(2);
            lastHalvingTime = now;
        }
        
        //iterate through the array and update
        uint256 totalAmount = 0;
        
        for (uint i = 0; i < addressArray.length; i++) {
            require(balanceArray[i] > 0);
        
            totalAmount = totalAmount.add(balanceArray[i]);
            
            require(totalAmount <= dailyMiningLimit, "> daily limit!"); // > daily limit, trasaction failed.
            
            _minedToken[addressArray[i]] = _minedToken[addressArray[i]].add(balanceArray[i]);
        }
        
        _totalFreeAmount = _totalFreeAmount.add(totalAmount);
        
        assert(_totalFreeAmount <= token.balanceOf(address(this)));
        
        return totalAmount;
    }
    
    function checkBalance() public view returns (uint256) {
        require(msg.sender != admin && msg.sender != miningDappAddress,"admin and dapp not allowed!");
        
        return _minedToken[msg.sender];
    }
    
    //only the customers can withdraw from wallet
    function withdraw() public returns (uint256) {
        require(msg.sender != admin && msg.sender != miningDappAddress,"admin and dapp not allowed!");
        assert(_minedToken[msg.sender] > 0);
        
        uint256 amount = _minedToken[msg.sender];
        _minedToken[msg.sender] = 0; 
        _totalFreeAmount = _totalFreeAmount.sub(amount);
        token.transfer(msg.sender, amount);
        
        return amount;
    }
}