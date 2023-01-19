//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Teams.sol";

abstract contract TimedDrop is Teams {
  bool public enforcePublicDropTime = true;
  uint256 public publicDropTime = 1668470400;
  
  /**
  * @dev Allow the contract owner to set the public time to mint.
  * @param _newDropTime timestamp since Epoch in seconds you want public drop to happen
  */
  function setPublicDropTime(uint256 _newDropTime) public onlyTeamOrOwner {
    require(_newDropTime > block.timestamp, "Drop date must be in future! Otherwise call disablePublicDropTime!");
    publicDropTime = _newDropTime;
  }

  function usePublicDropTime() public onlyTeamOrOwner {
    enforcePublicDropTime = true;
  }

  function disablePublicDropTime() public onlyTeamOrOwner {
    enforcePublicDropTime = false;
  }

  /**
  * @dev determine if the public droptime has passed.
  * if the feature is disabled then assume the time has passed.
  */
  function publicDropTimePassed() public view returns(bool) {
    if(enforcePublicDropTime == false) {
      return true;
    }
    return block.timestamp >= publicDropTime;
  }
  
  // Allowlist implementation of the Timed Drop feature
  bool public enforceAllowlistDropTime = true;
  uint256 public allowlistDropTime = 1668438000;

  /**
  * @dev Allow the contract owner to set the allowlist time to mint.
  * @param _newDropTime timestamp since Epoch in seconds you want public drop to happen
  */
  function setAllowlistDropTime(uint256 _newDropTime) public onlyTeamOrOwner {
    require(_newDropTime > block.timestamp, "Drop date must be in future! Otherwise call disableAllowlistDropTime!");
    allowlistDropTime = _newDropTime;
  }

  function useAllowlistDropTime() public onlyTeamOrOwner {
    enforceAllowlistDropTime = true;
  }

  function disableAllowlistDropTime() public onlyTeamOrOwner {
    enforceAllowlistDropTime = false;
  }

  function allowlistDropTimePassed() public view returns(bool) {
    if(enforceAllowlistDropTime == false) {
      return true;
    }

    return block.timestamp >= allowlistDropTime;
  }
}