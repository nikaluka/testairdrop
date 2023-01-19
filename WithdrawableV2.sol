//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Teams.sol";
import "./IERC20.sol";
abstract contract WithdrawableV2 is Teams {
  struct acceptedERC20 {
    bool isActive;
    uint256 chargeAmount;
  }

  
  mapping(address => acceptedERC20) private allowedTokenContracts;
  address[] public payableAddresses = [0x7d3F268Cd3fC5c6BF271B7F400C5fE68416Df2A0];
  address public erc20Payable = 0x7d3F268Cd3fC5c6BF271B7F400C5fE68416Df2A0;
  uint256[] public payableFees = [100];
  uint256 public payableAddressCount = 1;
  bool public onlyERC20MintingMode = false;
  

  /**
  * @dev Calculates the true payable balance of the contract
  */
  function calcAvailableBalance() public view returns(uint256) {
    return address(this).balance;
  }

  function withdrawAll() public onlyTeamOrOwner {
      require(calcAvailableBalance() > 0);
      _withdrawAll();
  }

  function _withdrawAll() private {
      uint256 balance = calcAvailableBalance();
      
      for(uint i=0; i < payableAddressCount; i++ ) {
          _widthdraw(
              payableAddresses[i],
              (balance * payableFees[i]) / 100
          );
      }
  }
  
  function _widthdraw(address _address, uint256 _amount) private {
      (bool success, ) = _address.call{value: _amount}("");
      require(success, "Transfer failed.");
  }

  /**
  * @dev Allow contract owner to withdraw ERC-20 balance from contract
  * in the event ERC-20 tokens are paid to the contract for mints.
  * @param _tokenContract contract of ERC-20 token to withdraw
  * @param _amountToWithdraw balance to withdraw according to balanceOf of ERC-20 token in wei
  */
  function withdrawERC20(address _tokenContract, uint256 _amountToWithdraw) public onlyTeamOrOwner {
    require(_amountToWithdraw > 0);
    IERC20 tokenContract = IERC20(_tokenContract);
    require(tokenContract.balanceOf(address(this)) >= _amountToWithdraw, "WithdrawV2: Contract does not own enough tokens");
    tokenContract.transfer(erc20Payable, _amountToWithdraw); // Payout ERC-20 tokens to recipient
  }

  /**
  * @dev check if an ERC-20 contract is a valid payable contract for executing a mint.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function isApprovedForERC20Payments(address _erc20TokenContract) public view returns(bool) {
    return allowedTokenContracts[_erc20TokenContract].isActive == true;
  }

  /**
  * @dev get the value of tokens to transfer for user of an ERC-20
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function chargeAmountForERC20(address _erc20TokenContract) public view returns(uint256) {
    require(isApprovedForERC20Payments(_erc20TokenContract), "This ERC-20 contract is not approved to make payments on this contract!");
    return allowedTokenContracts[_erc20TokenContract].chargeAmount;
  }

  /**
  * @dev Explicity sets and ERC-20 contract as an allowed payment method for minting
  * @param _erc20TokenContract address of ERC-20 contract in question
  * @param _isActive default status of if contract should be allowed to accept payments
  * @param _chargeAmountInTokens fee (in tokens) to charge for mints for this specific ERC-20 token
  */
  function addOrUpdateERC20ContractAsPayment(address _erc20TokenContract, bool _isActive, uint256 _chargeAmountInTokens) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = _isActive;
    allowedTokenContracts[_erc20TokenContract].chargeAmount = _chargeAmountInTokens;
  }

  /**
  * @dev Add an ERC-20 contract as being a valid payment method. If passed a contract which has not been added
  * it will assume the default value of zero. This should not be used to create new payment tokens.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function enableERC20ContractAsPayment(address _erc20TokenContract) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = true;
  }

  /**
  * @dev Disable an ERC-20 contract as being a valid payment method. If passed a contract which has not been added
  * it will assume the default value of zero. This should not be used to create new payment tokens.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function disableERC20ContractAsPayment(address _erc20TokenContract) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = false;
  }

  /**
  * @dev Enable only ERC-20 payments for minting on this contract
  */
  function enableERC20OnlyMinting() public onlyTeamOrOwner {
    onlyERC20MintingMode = true;
  }

  /**
  * @dev Disable only ERC-20 payments for minting on this contract
  */
  function disableERC20OnlyMinting() public onlyTeamOrOwner {
    onlyERC20MintingMode = false;
  }

  /**
  * @dev Set the payout of the ERC-20 token payout to a specific address
  * @param _newErc20Payable new payout addresses of ERC-20 tokens
  */
  function setERC20PayableAddress(address _newErc20Payable) public onlyTeamOrOwner {
    require(_newErc20Payable != address(0), "WithdrawableV2: new ERC-20 payout cannot be the zero address");
    require(_newErc20Payable != erc20Payable, "WithdrawableV2: new ERC-20 payout is same as current payout");
    erc20Payable = _newErc20Payable;
  }
}