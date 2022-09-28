// 0.5.1-c8a2
// Enable optimization
pragma solidity ^0.5.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";

/**
 * @title SimpleToken
 * @dev Very simple TRC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `TRC20` functions.
 */
contract MudTestToken is TRC20, TRC20Detailed {
   
    
    bool private icoFinished;
    uint256 private icoLeftoverAmount = 300000000000000;
    address private creator;
    
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor () public TRC20Detailed("Metaverse User DAO", "MUD", 6) {
        _frozen = false;
        icoFinished = false;
        creator = msg.sender;
        
        _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));
    }
    
    //freeze the token tranfer and get ready for main net mapping
    function mainNetMappingFreeze() public {
        require(!_frozen);
        
        _frozen = true;
    }
    
    
    //ICO fina and burn the leftover amount
    function icoFinalised() public returns (bool) {
        require(msg.sender == creator, "not contractor owner!");
        require(!icoFinished, "ico alreay finished");
        //burn ico round A and round B leftover
        if (icoLeftoverAmount > 0) {
            icoLeftoverAmount = 0;
            _burn(msg.sender, icoLeftoverAmount);
        }
        
        icoFinished = true;
        return true;
    }
    
    /* ico transferFrom, make sure the ICO not exceed the limit
     * parameters: 
     *   sender: sender address
     *   recipient: ICO customer address
     *   amount: amount of coins 
     * return:
     *   bool: true -- succeed
     *         false -- failed
     */
    function icoTransferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(tx.origin == creator, "not contract creator!");//only onwer can call this function
        require(!icoFinished, "ico finished!");
        require(amount > 0, "amount should > 0");
        require(amount <= icoLeftoverAmount, "amount > icoLeftoverAmount");
        bool succ = transferFrom(sender, recipient, amount);
        
        icoLeftoverAmount = icoLeftoverAmount.sub(amount);
        return succ;
    }
    
}
