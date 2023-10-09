// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IStableQiVault {
  function _minimumCollateralPercentage() external view returns ( uint256 );
  function approve ( address to, uint256 tokenId ) external;
  function balanceOf ( address owner ) external view returns ( uint256 );
  function borrowToken ( uint256 vaultID, uint256 amount, uint256 _front ) external;
  function buyRiskDebtVault ( uint256 vaultID ) external returns ( uint256 );
  function checkCollateralPercentage ( uint256 vaultID ) external view returns ( uint256 );
  function checkCost ( uint256 vaultID ) external view returns ( uint256 );
  function checkExtract ( uint256 vaultID ) external view returns ( uint256 );
  function collateral() external view returns ( address );
  function decimalDifferenceRaisedToTen() external view returns ( uint256 );
  function paybackTokenAll(uint256 vaultID, uint256 deadline, uint256 _front) external;

  function ethPriceSource() external view returns ( address );
  function getTokenPriceSource() external view returns ( uint256 );
  
  function gainRatio() external view returns ( uint256 );
  function getEthPriceSource() external view returns ( uint256 );
  function getPaid() external;
  function liquidateVault ( uint256 vaultID, uint256 _front ) external;
  function liquidateVault ( uint256 vaultID) external;

  function refFee () external returns ( uint256 );

  function mai() external view returns ( address );
  function maiDebt() external view returns ( uint256 );
  function maticDebt(address owner) external view returns ( uint256 );
  function priceSourceDecimals() external view returns ( uint256 );
  function safeTransferFrom ( address from, address to, uint256 tokenId ) external;
  function transferFrom ( address from, address to, uint256 tokenId ) external;

  function vaultCollateral ( uint256 ) external view returns ( uint256 );
  function vaultCount() external view returns ( uint256 );
  function vaultDebt ( uint256 vaultID ) external view returns ( uint256 );
  function depositCollateral(uint256 vaultID, uint256 amount) external;
  function ownerOf(uint256 tokenId) external view returns (address);
  function getApproved(uint256 tokenId) external view returns (address operator);
  function withdrawCollateral(uint256 vaultID, uint256 amount) external;

  function checkLiquidation( uint256 vaultID ) external view returns (bool);
}
