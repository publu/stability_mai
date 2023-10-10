```
  _____      _                     _        __         _                   
 |_   _|    (_)                   (_)      |  ]       / |_                 
   | |      __   .--. _  __   _   __   .--.| |  ,--. `| |-' .--.   _ .--.  
   | |   _ [  |/ /'`\' ][  | | | [  |/ /'`\' | `'_\ : | | / .'`\ \[ `/'`\] 
  _| |__/ | | || \__/ |  | \_/ |, | || \__/  | // | |,| |,| \__. | | |     
 |________|[___]\__.; |  '.__.'_/[___]'.__.;__]\'-;__/\__/ '.__.' [___]    
                    |__]                                                   
```

# Stability MAI Storefront (SMS)

The Stability MAI Storefront (SMS) is a smart contract system designed to prioritize the liquidation of any vaults that have MAI loans. Users can stake their MAI tokens in the contract, which then gets priority in the liquidation process.

## Overview

The SMS contract is divided into three main functions:

1. **Stability Pool:** Users can deposit MAI and own a share of the total value locked in the contract. They can later withdraw them after an epoch-based waiting period.

2. **Liquidation Functions:** These functions can be called by users or protocol bots to liquidate vaults. The liquidation process is done in batches and is only possible for vaults that have been authorized and added to the contract.

3. **Storefront Functions:** Arbitrage users can sell their MAI for collateral. The storefront values MAI at $1 which should provide upwards pressure for peg.

The contract also has ancillary functions that help operations and an owner role to manage operations like setting the split rate of earnings and authorizing vaults.

## Key Functions

- `liquidate(address _vault, uint256[] calldata _vaultIDs, int256 _front)`: This function is used to liquidate collateral from a vault and exchange it for a cost in MAI token.

- `sellCollateralForMAI(address _vault, uint256 amountMAI)`: This function allows users to sell collateral for a specific amount of MAI.

- `calculateUnderlying(uint256 _share)`: This function calculates the underlying assets of the provided share.

- `setLiqReward(uint256 _liqReward)`: This function allows the contract owner to set the liquidation reward.

## How to Use

To use the SMS contract, users can deposit their MAI tokens into the contract. Once the tokens are deposited, they will be used to liquidate vaults that have MAI loans. The liquidation process is done in batches and is only possible for vaults that have been authorized and added to the contract.

Users can also sell their collateral for MAI through the storefront functions. The storefront values MAI at $1 which should provide upwards pressure for peg.

## Conclusion

The Stability MAI Storefront (SMS) is a powerful tool for managing the liquidation of MAI loans. By staking MAI in the contract, users can help maintain the stability of the system while also potentially earning rewards.