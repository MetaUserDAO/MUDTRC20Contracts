// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import "./TRC20.sol";
import "./TRC20Detailed.sol";

/**
 * @title SimpleToken
 * @dev Very simple TRC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `TRC20` functions.
 */
contract MudTestToken is TRC20, TRC20Detailed {
   
    
    //bool private icoFinished;
    //uint256 private icoLeftoverAmount = 300000000000000;
    address immutable private creator;
    
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor () public TRC20Detailed("Metaverse User DAO", "MUD", 6) {
        _frozen = false;
        creator = msg.sender;
        
        _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));
    }
    
    //freeze the token tranfer and get ready for main net mapping
    function mainNetMappingFreeze() external {
        require(msg.sender == creator, "Not token creator!");
        require(!_frozen, "Freezed for mainnet mapping !");
        
        _frozen = true;
    }
    
}
