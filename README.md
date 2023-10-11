```
  _____      _                     _        __         _                   
 |_   _|    (_)                   (_)      |  ]       / |_                 
   | |      __   .--. _  __   _   __   .--.| |  ,--. `| |-' .--.   _ .--.  
   | |   _ [  |/ /'`\' ][  | | | [  |/ /'`\' | `'_\ : | | / .'`\ \[ `/'`\] 
  _| |__/ | | || \__/ |  | \_/ |, | || \__/  | // | |,| |,| \__. | | |     
 |________|[___]\__.; |  '.__.'_/[___]'.__.;__]\'-;__/\__/ '.__.' [___]    
                    |__]                                                   
```

# SimpleStaker

The SimpleStaker is a smart contract system designed to manage the staking of MAI tokens and the liquidation of vaults that have MAI loans. Users can stake their MAI tokens in the contract, which then gets priority in the liquidation process.

## Overview

The SimpleStaker contract is divided into three main functions:

1. **Staking Pool:** Users can deposit MAI and own a share of the total value locked in the contract. They can later withdraw them after an epoch-based waiting period.

2. **Liquidation Functions:** These functions can be called by users or protocol bots to liquidate vaults. The liquidation process is done in batches and is only possible for vaults that have been authorized and added to the contract.

3. **Withdrawal Functions:** Users can request to withdraw their staked MAI. The withdrawal process is subject to an epoch-based waiting period.

The contract also has ancillary functions that help operations and an owner role to manage operations like setting the liquidity thresholds.

## Key Functions

- `deposit(uint256 amount)`: This function is used to deposit MAI into the contract.

- `requestWithdrawal(uint256 amount)`: This function allows users to request a withdrawal of their MAI.

- `withdraw(uint256 minAmount)`: This function allows users to withdraw their MAI if the conditions are met.

- `canWithdraw(address user)`: This function determines whether a user is eligible to withdraw their MAI.

## How to Use

To use the SimpleStaker contract, users can deposit their MAI tokens into the contract. Once the tokens are deposited, they will be used to liquidate vaults that have MAI loans. The liquidation process is done in batches and is only possible for vaults that have been authorized and added to the contract.

Users can also request to withdraw their staked MAI. However, the withdrawal process is subject to an epoch-based waiting period and the available liquidity in the contract. If the contract's liquidity is low at the time of withdrawal, users may end up withdrawing at a loss. This is because the withdrawal amount is calculated based on the user's share of the available balance, which could be less than the original deposit if the contract's total underlying asset has decreased due to liquidations.

Therefore, users should be aware of the contract's liquidity situation before initiating a withdrawal. If the contract's liquidity is high, users can withdraw without incurring a loss. On the other hand, if the liquidity is low, it might be more beneficial for users to wait until the liquidity improves to avoid potential losses.

## Conclusion

The SimpleStaker is a powerful tool for managing the staking of MAI and the liquidation of MAI loans. By staking MAI in the contract, users can help maintain the stability of the system while also potentially earning rewards.
```
