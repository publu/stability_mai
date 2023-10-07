pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WrappedERC20
 * @dev This contract serves as a storage for the stablecoin MAI.
 * Users have the ability to deposit at any given time.
 * In order to withdraw, users must first submit a withdrawal request.
 */
contract WrappedERC20 is ERC20 {
    ERC20 public underlying;
    uint256 public epochLength = 72 hours;
    uint256 public withdrawalWindow = 48 hours;
    uint256 public lowLiquidityThreshold;
    uint256 public midLiquidityThreshold;

    /**
     * @dev This state variable keeps track of the total underlying asset
     */
    uint256 public totalUnderlying;

    uint256 public totalHeld;

    mapping(address => uint256) public withdrawalRequestEpoch;
    mapping(address => uint256) public withdrawalAmount;

    /**
     * @dev The constructor sets the underlying asset and liquidity thresholds
     * @param _underlying The address of the underlying asset
     * @param _lowliquidityThreshold The low liquidity threshold
     * @param _midLiquidityThreshold The mid liquidity threshold
     */
    constructor(address _underlying, uint256 _lowliquidityThreshold, uint256 _midLiquidityThreshold) ERC20("Wrapped", "W") {
        underlying = ERC20(_underlying);
        lowLiquidityThreshold = _lowliquidityThreshold;
        midLiquidityThreshold = _midLiquidityThreshold;
    }

    /**
     * @dev Allows users to deposit MAI into the contract
     * @param amount The amount of MAI to deposit
     */
    function deposit(uint256 amount) public {
        require(underlying.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        uint256 totalShares = totalSupply();
        uint256 what = (amount * totalShares) / totalUnderlying;
        _mint(msg.sender, what);
        totalUnderlying += amount;
    }

    /**
     * @dev This function is invoked by the liquidation contract.
     * The liquidation contract borrows MAI from SimpleStaker to liquidate vaults and subsequently sells the collateral.
     * Post liquidation, the MAI is returned to SimpleStaker via this function.
     * @param amount The quantity of MAI to be returned.
     */
    function earnToken(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), underlying.balanceOf(msg.sender));
        totalUnderlying += amount;
    }

    /**
     * @dev Checks if a user can withdraw their MAI
     * @param user The address of the user
     * @return true if the user can withdraw their MAI, false otherwise
     */
    function canWithdraw(address user) public view returns (bool) {
        // Calculate the current epoch based on the current block timestamp and epoch length
        uint256 currentEpoch = block.timestamp / epochLength;
        // Calculate the time into the current epoch
        uint256 timeIntoEpoch = block.timestamp % epochLength;
        // Check if the time into the current epoch is within the withdrawal window
        if (timeIntoEpoch <= withdrawalWindow) {
            // Get the total balance of the underlying asset in the contract
            uint256 totalBalance = underlying.balanceOf(address(this));
            // Check if the total balance is greater than or equal to the low liquidity threshold plus the withdrawal amount of the user
            if (totalBalance >= lowLiquidityThreshold + withdrawalAmount[user]) {
                // If so, the user can withdraw
                return true;
            }
            // If not, check if the total balance is greater than or equal to the mid liquidity threshold plus the withdrawal amount of the user
            else if (totalBalance >= midLiquidityThreshold + withdrawalAmount[user]) {
                // If so, the user can withdraw if the current epoch is greater than the withdrawal request epoch of the user plus 1
                return currentEpoch > withdrawalRequestEpoch[user] + 1;
            }
            // If not, the user can withdraw if the current epoch is greater than the withdrawal request epoch of the user plus 2
            else {
                return currentEpoch > withdrawalRequestEpoch[user] + 2;
            }
        }
        // If the time into the current epoch is not within the withdrawal window, the user cannot withdraw
        return false;
    }

    /**
     * @dev Allows users to request a withdrawal of their MAI
     * @param amount The amount of MAI to withdraw
     */
    function requestWithdrawal(uint256 amount) public {
        withdrawalRequestEpoch[msg.sender] = block.timestamp / epochLength;
        withdrawalAmount[msg.sender] = amount;
    }

    /**
     * @dev Allows users to withdraw their MAI if the conditions are met
     */
    function withdraw() public {
        uint256 amount = withdrawalAmount[msg.sender];
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(underlying.balanceOf(address(this)) >= amount, "Insufficient contract balance");

        _burn(msg.sender, amount);
        require(underlying.transfer(msg.sender, amount), "Transfer failed");
        withdrawalAmount[msg.sender] = 0;
        totalUnderlying -= amount;
    }
}


