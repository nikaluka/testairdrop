//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Teams.sol";
abstract contract Feeable is Teams {
  uint256 public PRICE = 0.3 ether;

  function setPrice(uint256 _feeInWei) public onlyTeamOrOwner {
    PRICE = _feeInWei;
  }

  function getPrice(uint256 _count) public view returns (uint256) {
    return PRICE * _count;
  }
}