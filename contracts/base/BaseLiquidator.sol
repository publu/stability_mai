pragma solidity 0.8.17;

import "../interfaces/IStableQiVault.sol";

interface ERC20Like {
  function balanceOf(address who) view external returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function decimals() external view returns (uint8);	
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
}

contract BaseLiquidator {
   ERC20Like mai;

   constructor(address _mai) {
       mai = ERC20Like(_mai);
   }

	/// @notice Splits liquidation gain between liquidator and protocol
	/// @dev If vault is just liquidatable, we liquidate it, getPaid, and get the collateral 
	///		 If vault is buy risky (aka under bonus) then we can just passthrough the liquidation
	/// @param _vault address of vault contract
	/// @param _vaultID vault being liquidated
	/// @param _front only used for V2 vaults where a front is needed during liquidation process
	function _liquidate(address _vault, uint256 _vaultID, int256 _front) internal returns (bool){
		IStableQiVault vault = IStableQiVault(_vault);

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
	
	/// @notice Router function for buying risky vaults
	/// @dev No splitting for fees is done here, all gains are provided to liquidator
	/// @param _vault address of vault contract
	/// @param _vaultID vault being liquidated
	function _buyrisky(address _vault, uint256 _vaultID) internal {
		IStableQiVault vault = IStableQiVault(_vault);
		uint256 newVaultID = vault.buyRiskDebtVault(_vaultID);
		vault.paybackTokenAll(_vaultID, vault.vaultDebt(_vaultID), 0);
		vault.withdrawCollateral(_vaultID, vault.vaultCollateral(_vaultID));
	}

	/// @notice Checks if a vault can be liquidated
	/// @param _vault address of vault contract
	/// @param _vaultID vault being checked
	/// @return A boolean indicating if the vault can be liquidated
	function _checkLiquidation(address _vault, uint256 _vaultID) internal view returns (bool) {
		return IStableQiVault(_vault).checkLiquidation(_vaultID);
	}

	/// @notice Checks the cost of liquidating a vault
	/// @param _vault address of vault contract
	/// @param _vaultID vault being checked
	/// @return The cost of liquidating the vault in MAI
	function _checkLiquidationCost(address _vault, uint256 _vaultID) internal view returns(uint256) {
		IStableQiVault vault = IStableQiVault(_vault);
		return vault.checkCost(_vaultID); // in MAI
	}

	/// @notice Checks the cost of buying a risky vault
	/// @param _vault address of vault contract
	/// @param _vaultID vault being checked
	/// @return The cost of buying the risky vault in MAI
	function _checkBuyRiskyCost(address _vault, uint256 _vaultID) internal view returns(uint256) {
		IStableQiVault vault = IStableQiVault(_vault);
		return vault.checkCost(_vaultID); // in MAI
	}
}