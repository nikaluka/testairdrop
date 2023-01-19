//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Teams.sol";
import "./ERC721ARedemption.sol";
import "./WithdrawableV2.sol";
import "./ReentrancyGuard.sol";
import "./isFeeable.sol";
import "./Allowlist.sol";
import "./TimedDrop.sol";

abstract contract RamppERC721A is 
    Ownable,
    Teams,
    ERC721ARedemption,
    WithdrawableV2,
    ReentrancyGuard 
    , Feeable 
    , Allowlist 
    , TimedDrop
{
  constructor(
    string memory tokenName,
    string memory tokenSymbol
  ) ERC721A(tokenName, tokenSymbol, 4, 3000) { }
    uint8 public CONTRACT_VERSION = 2;
    string public _baseTokenURI = "ipfs://QmWohpH896KvdnbBjJ6S8pkYvfmYVf2oUcSaTgsb3W4RKv/";
    string public _baseTokenExtension = ".json";

    bool public mintingOpen = false;
    bool public isRevealed = false;
    
    uint256 public MAX_WALLET_MINTS = 4;

  
    /////////////// Admin Mint Functions
    /**
     * @dev Mints a token to an address with a tokenURI.
     * This is owner only and allows a fee-free drop
     * @param _to address of the future owner of the token
     * @param _qty amount of tokens to drop the owner
     */
     function mintToAdminV2(address _to, uint256 _qty) public onlyTeamOrOwner{
         require(_qty > 0, "Must mint at least 1 token.");
         require(currentTokenId() + _qty <= collectionSize, "Cannot mint over supply cap of 3000");
         _safeMint(_to, _qty, true);
     }

  
    /////////////// PUBLIC MINT FUNCTIONS
    /**
    * @dev Mints tokens to an address in batch.
    * fee may or may not be required*
    * @param _to address of the future owner of the token
    * @param _amount number of tokens to mint
    */
    function mintToMultiple(address _to, uint256 _amount) public payable {
        require(onlyERC20MintingMode == false, "Only minting with ERC-20 tokens is enabled.");
        require(_amount >= 1, "Must mint at least 1 token");
        require(_amount <= maxBatchSize, "Cannot mint more than max mint per transaction");
        require(mintingOpen == true && onlyAllowlistMode == false, "Public minting is not open right now!");
        require(publicDropTimePassed() == true, "Public drop time has not passed!");
        require(canMintAmount(_to, _amount), "Wallet address is over the maximum allowed mints");
        require(currentTokenId() + _amount <= collectionSize, "Cannot mint over supply cap of 3000");
        require(msg.value == getPrice(_amount), "Value below required mint fee for amount");

        _safeMint(_to, _amount, false);
    }

    /**
     * @dev Mints tokens to an address in batch using an ERC-20 token for payment
     * fee may or may not be required*
     * @param _to address of the future owner of the token
     * @param _amount number of tokens to mint
     * @param _erc20TokenContract erc-20 token contract to mint with
     */
    function mintToMultipleERC20(address _to, uint256 _amount, address _erc20TokenContract) public payable {
      require(_amount >= 1, "Must mint at least 1 token");
      require(_amount <= maxBatchSize, "Cannot mint more than max mint per transaction");
      require(getNextTokenId() <= collectionSize, "Cannot mint over supply cap of 3000");
      require(mintingOpen == true && onlyAllowlistMode == false, "Public minting is not open right now!");
      require(publicDropTimePassed() == true, "Public drop time has not passed!");
      require(canMintAmount(_to, 1), "Wallet address is over the maximum allowed mints");

      // ERC-20 Specific pre-flight checks
      require(isApprovedForERC20Payments(_erc20TokenContract), "ERC-20 Token is not approved for minting!");
      uint256 tokensQtyToTransfer = chargeAmountForERC20(_erc20TokenContract) * _amount;
      IERC20 payableToken = IERC20(_erc20TokenContract);

      require(payableToken.balanceOf(_to) >= tokensQtyToTransfer, "Buyer does not own enough of token to complete purchase");
      require(payableToken.allowance(_to, address(this)) >= tokensQtyToTransfer, "Buyer did not approve enough of ERC-20 token to complete purchase");

      bool transferComplete = payableToken.transferFrom(_to, address(this), tokensQtyToTransfer);
      require(transferComplete, "ERC-20 token was unable to be transferred");
      
      _safeMint(_to, _amount, false);
    }

    function openMinting() public onlyTeamOrOwner {
        mintingOpen = true;
    }

    function stopMinting() public onlyTeamOrOwner {
        mintingOpen = false;
    }

  
    ///////////// ALLOWLIST MINTING FUNCTIONS
    /**
    * @dev Mints tokens to an address using an allowlist.
    * fee may or may not be required*
    * @param _to address of the future owner of the token
    * @param _amount number of tokens to mint
    * @param _merkleProof merkle proof array
    */
    function mintToMultipleAL(address _to, uint256 _amount, bytes32[] calldata _merkleProof) public payable {
        require(onlyERC20MintingMode == false, "Only minting with ERC-20 tokens is enabled.");
        require(onlyAllowlistMode == true && mintingOpen == true, "Allowlist minting is closed");
        require(isAllowlisted(_to, _merkleProof), "Address is not in Allowlist!");
        require(_amount >= 1, "Must mint at least 1 token");
        require(_amount <= maxBatchSize, "Cannot mint more than max mint per transaction");

        require(canMintAmount(_to, _amount), "Wallet address is over the maximum allowed mints");
        require(currentTokenId() + _amount <= collectionSize, "Cannot mint over supply cap of 3000");
        require(msg.value == getPrice(_amount), "Value below required mint fee for amount");
        require(allowlistDropTimePassed() == true, "Allowlist drop time has not passed!");

        _safeMint(_to, _amount, false);
    }

    /**
    * @dev Mints tokens to an address using an allowlist.
    * fee may or may not be required*
    * @param _to address of the future owner of the token
    * @param _amount number of tokens to mint
    * @param _merkleProof merkle proof array
    * @param _erc20TokenContract erc-20 token contract to mint with
    */
    function mintToMultipleERC20AL(address _to, uint256 _amount, bytes32[] calldata _merkleProof, address _erc20TokenContract) public payable {
      require(onlyAllowlistMode == true && mintingOpen == true, "Allowlist minting is closed");
      require(isAllowlisted(_to, _merkleProof), "Address is not in Allowlist!");
      require(_amount >= 1, "Must mint at least 1 token");
      require(_amount <= maxBatchSize, "Cannot mint more than max mint per transaction");
      require(canMintAmount(_to, _amount), "Wallet address is over the maximum allowed mints");
      require(currentTokenId() + _amount <= collectionSize, "Cannot mint over supply cap of 3000");
      require(allowlistDropTimePassed() == true, "Allowlist drop time has not passed!");
    
      // ERC-20 Specific pre-flight checks
      require(isApprovedForERC20Payments(_erc20TokenContract), "ERC-20 Token is not approved for minting!");
      uint256 tokensQtyToTransfer = chargeAmountForERC20(_erc20TokenContract) * _amount;
      IERC20 payableToken = IERC20(_erc20TokenContract);
    
      require(payableToken.balanceOf(_to) >= tokensQtyToTransfer, "Buyer does not own enough of token to complete purchase");
      require(payableToken.allowance(_to, address(this)) >= tokensQtyToTransfer, "Buyer did not approve enough of ERC-20 token to complete purchase");
      
      bool transferComplete = payableToken.transferFrom(_to, address(this), tokensQtyToTransfer);
      require(transferComplete, "ERC-20 token was unable to be transferred");
      
      _safeMint(_to, _amount, false);
    }

    /**
     * @dev Enable allowlist minting fully by enabling both flags
     * This is a convenience function for the Rampp user
     */
    function openAllowlistMint() public onlyTeamOrOwner {
        enableAllowlistOnlyMode();
        mintingOpen = true;
    }

    /**
     * @dev Close allowlist minting fully by disabling both flags
     * This is a convenience function for the Rampp user
     */
    function closeAllowlistMint() public onlyTeamOrOwner {
        disableAllowlistOnlyMode();
        mintingOpen = false;
    }


  
    /**
    * @dev Check if wallet over MAX_WALLET_MINTS
    * @param _address address in question to check if minted count exceeds max
    */
    function canMintAmount(address _address, uint256 _amount) public view returns(bool) {
        require(_amount >= 1, "Amount must be greater than or equal to 1");
        return (_numberMinted(_address) + _amount) <= MAX_WALLET_MINTS;
    }

    /**
    * @dev Update the maximum amount of tokens that can be minted by a unique wallet
    * @param _newWalletMax the new max of tokens a wallet can mint. Must be >= 1
    */
    function setWalletMax(uint256 _newWalletMax) public onlyTeamOrOwner {
        require(_newWalletMax >= 1, "Max mints per wallet must be at least 1");
        MAX_WALLET_MINTS = _newWalletMax;
    }
    

  
    /**
     * @dev Allows owner to set Max mints per tx
     * @param _newMaxMint maximum amount of tokens allowed to mint per tx. Must be >= 1
     */
     function setMaxMint(uint256 _newMaxMint) public onlyTeamOrOwner {
         require(_newMaxMint >= 1, "Max mint must be at least 1");
         maxBatchSize = _newMaxMint;
     }
    

  
    function unveil(string memory _updatedTokenURI) public onlyTeamOrOwner {
        require(isRevealed == false, "Tokens are already unveiled");
        _baseTokenURI = _updatedTokenURI;
        isRevealed = true;
    }
    

  function _baseURI() internal view virtual override returns(string memory) {
    return _baseTokenURI;
  }

  function _baseURIExtension() internal view virtual override returns(string memory) {
    return _baseTokenExtension;
  }

  function baseTokenURI() public view returns(string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyTeamOrOwner {
    _baseTokenURI = baseURI;
  }

  function setBaseTokenExtension(string calldata baseExtension) external onlyTeamOrOwner {
    _baseTokenExtension = baseExtension;
  }

  function getOwnershipData(uint256 tokenId) external view returns(TokenOwnership memory) {
    return ownershipOf(tokenId);
  }
}
