//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC721A.sol";

abstract contract ERC721ARedemption is ERC721A {
  // @dev Emitted when someone exchanges an NFT for this contracts NFT via token redemption swap
  event Redeemed(address indexed from, uint256 indexed tokenId, address indexed contractAddress);

  // @dev Emitted when someone proves ownership of an NFT for this contracts NFT via token redemption swap
  event VerifiedClaim(address indexed from, uint256 indexed tokenId, address indexed contractAddress);
  
  uint256 public redemptionSurcharge = 0 ether;
  bool public redemptionModeEnabled;
  bool public verifiedClaimModeEnabled;
  address public redemptionAddress = 0x000000000000000000000000000000000000dEaD; // address burned tokens are sent, default is dEaD.
  mapping(address => bool) public redemptionContracts;
  mapping(address => mapping(uint256 => bool)) public tokenRedemptions;

  // @dev Allow owner/team to set the contract as eligable for redemption for this contract
  function setRedeemableContract(address _contractAddress, bool _status) public onlyTeamOrOwner {
    redemptionContracts[_contractAddress] = _status;
  }

  // @dev Allow owner/team to determine if contract is accepting redemption mints
  function setRedemptionMode(bool _newStatus) public onlyTeamOrOwner {
    redemptionModeEnabled = _newStatus;
  }

  // @dev Allow owner/team to determine if contract is accepting verified claim mints
  function setVerifiedClaimMode(bool _newStatus) public onlyTeamOrOwner {
    verifiedClaimModeEnabled = _newStatus;
  }

  // @dev Set the fee that it would cost a minter to be able to burn/validtion mint a token on this contract. 
  function setRedemptionSurcharge(uint256 _newSurchargeInWei) public onlyTeamOrOwner {
    redemptionSurcharge = _newSurchargeInWei;
  }

  // @dev Set the redemption address where redeemed NFTs will be transferred when "burned". 
  // @notice Must be a wallet address or implement IERC721Receiver.
  // Cannot be null address as this will break any ERC-721A implementation without a proper
  // burn mechanic as ownershipOf cannot handle 0x00 holdings mid batch.
  function setRedemptionAddress(address _newRedemptionAddress) public onlyTeamOrOwner {
    require(_newRedemptionAddress != address(0), "New redemption address cannot be null address.");
    redemptionAddress = _newRedemptionAddress;
  }

  /**
  * @dev allows redemption or "burning" of a single tokenID. Must be owned by the owner
  * @notice this does not impact the total supply of the burned token and the transfer destination address may be set by
  * the contract owner or Team => redemptionAddress. 
  * @param tokenId the token to be redeemed.
  * Emits a {Redeemed} event.
  **/
  function redeem(address redemptionContract, uint256 tokenId) public payable {
    require(getNextTokenId() <= collectionSize, "Cannot mint over supply cap of 5000");
    require(redemptionModeEnabled, "ERC721 Redeemable: Redemption mode is not enabled currently");
    require(redemptionContract != address(0), "ERC721 Redeemable: Redemption contract cannot be null.");
    require(redemptionContracts[redemptionContract], "ERC721 Redeemable: Redemption contract is not eligable for redeeming.");
    require(msg.value == redemptionSurcharge, "ERC721 Redeemable: Redemption fee not sent by redeemer.");
    require(tokenRedemptions[redemptionContract][tokenId] == false, "ERC721 Redeemable: Token has already been redeemed.");
    
    IERC721 _targetContract = IERC721(redemptionContract);
    require(_targetContract.ownerOf(tokenId) == _msgSender(), "ERC721 Redeemable: Redeemer not owner of token to be claimed against.");
    require(_targetContract.getApproved(tokenId) == address(this), "ERC721 Redeemable: This contract is not approved for specific token on redempetion contract.");
    
    // Warning: Since there is no standarized return value for transfers of ERC-721
    // It is possible this function silently fails and a mint still occurs. The owner of the contract is
    // responsible for ensuring that the redemption contract does not lock or have staked controls preventing
    // movement of the token. As an added measure we keep a mapping of tokens redeemed to prevent multiple single-token redemptions, 
    // but the NFT may not have been sent to the redemptionAddress.
    _targetContract.safeTransferFrom(_msgSender(), redemptionAddress, tokenId);
    tokenRedemptions[redemptionContract][tokenId] = true;

    emit Redeemed(_msgSender(), tokenId, redemptionContract);
    _safeMint(_msgSender(), 1, false);
  }

  /**
  * @dev allows for verified claim mint against a single tokenID. Must be owned by the owner
  * @notice this mint action allows the original NFT to remain in the holders wallet, but its claim is logged.
  * @param tokenId the token to be redeemed.
  * Emits a {VerifiedClaim} event.
  **/
  function verifedClaim(address redemptionContract, uint256 tokenId) public payable {
    require(getNextTokenId() <= collectionSize, "Cannot mint over supply cap of 5000");
    require(verifiedClaimModeEnabled, "ERC721 Redeemable: Verified claim mode is not enabled currently");
    require(redemptionContract != address(0), "ERC721 Redeemable: Redemption contract cannot be null.");
    require(redemptionContracts[redemptionContract], "ERC721 Redeemable: Redemption contract is not eligable for redeeming.");
    require(msg.value == redemptionSurcharge, "ERC721 Redeemable: Redemption fee not sent by redeemer.");
    require(tokenRedemptions[redemptionContract][tokenId] == false, "ERC721 Redeemable: Token has already been redeemed.");
    
    tokenRedemptions[redemptionContract][tokenId] = true;
    emit VerifiedClaim(_msgSender(), tokenId, redemptionContract);
    _safeMint(_msgSender(), 1, false);
  }
}