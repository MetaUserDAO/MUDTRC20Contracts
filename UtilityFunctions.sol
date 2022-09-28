// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./Token.sol";

library UtilityFunctions {

    address constant mudtTokenContractAddr = address(0x4159f06ddde85a8b9836236067a9a13c38452da322);//contrct address of the MUD token, should deploy the token contract first and set the contract address here
    
    function getMudToken() internal pure returns(MudTestToken){
        MudTestToken token = MudTestToken(mudtTokenContractAddr);
        
        return token;
    }
}