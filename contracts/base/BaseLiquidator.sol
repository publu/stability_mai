pragma solidity 0.8.17;

import "../interfaces/IStableQiVault.sol";

interface ERC20Like {

  function balanceOf(address who) view external returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function decimals() external view returns (uint8);	
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
}

/// @title 	A liquidation router for splitting liquidation fees
/// @notice This contracts acts as an intermmediary between liquidators 
///			and vaults and splits bonus between them
/// @dev 	All functions are called by liquidators, contract will then call
///			vault contract and liquidate the vault
contract BaseLiquidator {
	error BaseLiquidator__MathIssue();

	/// @notice splits liquidation gain between liquidator and protocol
	/// @dev IF vault is just liquidatable, we liquidate it, getPaid, and get the collateral 
	///		 IF vault is buy risky (aka under bonus) then we can just passthrough the liquidation
	/// @param _vault address of vault contract
	/// @param _vaultID vault being liquidated
	/// @param _front only used for V2 vaults where a front is needed during liquidation process
	function _liquidate(address _vault, uint256 _vaultID, int256 _front) internal returns (bool){
		// transfer mai from msg.sender to contract
		// liquidate vault
		IStableQiVault vault = IStableQiVault(_vault);
		/*
			CHECK 
			Unsure if this is the correct form
		*/
		if(_front<0){
				try vault.liquidateVault(_vaultID) // if not a v2 vault, no front/different interface
					{
						return true;
					} catch{
						return false;
					}
		} else{
			try vault.liquidateVault(_vaultID, uint256(_front)) {
					return true;
				} catch {
					return false;
				}
		}
	}
	
	/// @notice router function of for buying risky vaults
	/// @dev no splitting for fees is done here, all gains are provided to liquidator
	/// @param _vault address of vault contract
	/// @param _vaultID vault being liquidated
	function _buyrisky(address _vault, uint256 _vaultID) internal {

		//CHECK - can we remove all the math and only add the maiDebtToBePaid as a paramter

		ERC20Like mai = ERC20Like(IStableQiVault(_vault).mai());

		IStableQiVault vault = IStableQiVault(_vault);
		
 		uint256 _minimumCollateralPercentage = vault._minimumCollateralPercentage();
 		uint256 getEthPriceSource = vault.getEthPriceSource();
 		uint256 _collateral = vault.vaultCollateral(_vaultID);
 		uint256 decimalDifferenceRaisedToTen = vault.decimalDifferenceRaisedToTen();

		uint256 collateralValueTimes100 = _collateral *
		            getEthPriceSource *
		            decimalDifferenceRaisedToTen * 100;

		uint256 priceSourceDecimals = vault.priceSourceDecimals();
		uint256 debtValue = vault.vaultDebt(_vaultID) * vault.getTokenPriceSource();

	  	uint256 maiDebtTobePaid = (debtValue / (10**priceSourceDecimals)) - 
	                        (collateralValueTimes100 / 
	                        ( _minimumCollateralPercentage * (10**priceSourceDecimals)));

		mai.transferFrom(msg.sender, address(this), maiDebtTobePaid);
		mai.approve(_vault, maiDebtTobePaid);

		uint256 before = mai.balanceOf(address(this));
		uint256 newVaultID = vault.buyRiskDebtVault(_vaultID);
		uint256 despues = mai.balanceOf(address(this));

		// CHECK 
		if(maiDebtTobePaid<(before-despues)){
			revert BaseLiquidator__MathIssue();
			//mai.transferFrom(msg.sender, address(this), maiDebtTobePaid);
		}
		
		vault.transferFrom(address(this), msg.sender, newVaultID);
	}

	function _checkLiquidation(address _vault, uint256 _vaultID) internal view returns (bool) {
		return IStableQiVault(_vault).checkLiquidation(_vaultID);
	}

	function _gainRatio(address _vault) internal view returns (uint256) {
		return IStableQiVault(_vault).gainRatio();
	}

	function _checkLiquidationCost(address _vault, uint256 _vaultID) internal view returns(uint256) {
		// transfer mai from msg.sender to contract
		// liquidate vault
		IStableQiVault vault = IStableQiVault(_vault);
		return vault.checkCost(_vaultID); // in MAI
	}
}