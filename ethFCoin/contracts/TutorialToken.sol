pragma solidity ^0.4.24;
// import 'node_modules/zeppelin-solidity/contracts/token/StandardToken.sol';

import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';


contract TutorialToken is StandardToken {
  string public name = "TutorialToken";
  string public symbol = "TT";
  uint8 public decimals = 2;
  uint public INITIAL_SUPPLY = 12000;
  constructor() public {
    totalSupply_ = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }
}

