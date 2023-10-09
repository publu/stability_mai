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
    mapping(address => uint256) public withdrawalEpoch;

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
        if (!underlying.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        // Remove any existing withdrawal requests when user deposits
        withdrawalRequestEpoch[msg.sender] = 0;
        withdrawalAmount[msg.sender] = 0;
        
        uint256 totalShares = totalSupply();
        uint256 what = (amount * totalShares) / totalUnderlying;
        _mint(msg.sender, what);
        totalUnderlying += amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev This function is invoked by the liquidation contract.
     * The liquidation contract borrows MAI from SimpleStaker to liquidate vaults and subsequently sells the collateral.
     * Post liquidation, the MAI is returned to SimpleStaker via this function.
     * @param amount The quantity of MAI to be returned.
     */
    function donateAll() external {
        uint256 balance = underlying.balanceOf(msg.sender);
        underlying.transferFrom(msg.sender, address(this), balance);
        totalUnderlying += balance;
        emit EarnToken(msg.sender, balance);
    }

    /**
     * @dev Determines whether a user is eligible to withdraw their MAI
     * @param user The address of the user
     * @return A boolean indicating if the user can withdraw their MAI
     */
    function canWithdraw(address user) public view returns (bool) {
        // Compute the current epoch based on the current block timestamp and epoch length
        uint256 currentEpoch = block.timestamp / epochLength;
        // Compute the termination of the withdrawal window
        uint256 endOfWithdrawalWindow = withdrawalEpoch[user] + (withdrawalWindow / epochLength);
        // Verify if the current epoch falls within the user's withdrawal window
        return currentEpoch >= withdrawalEpoch[user] && currentEpoch < endOfWithdrawalWindow;
    }

    /**
     * @dev Allows users to request a withdrawal of their MAI
     * @param amount The amount of MAI to withdraw
     */
    function requestWithdrawal(uint256 amount) public {
        withdrawalRequestEpoch[msg.sender] = block.timestamp / epochLength;
        withdrawalAmount[msg.sender] = amount;
        uint256 totalBalance = underlying.balanceOf(address(this));
        if (totalBalance >= lowLiquidityThreshold + amount) {
            withdrawalEpoch[msg.sender] = withdrawalRequestEpoch[msg.sender] + 1;
        } else if (totalBalance >= midLiquidityThreshold + amount) {
            withdrawalEpoch[msg.sender] = withdrawalRequestEpoch[msg.sender] + 2;
        } else {
            withdrawalEpoch[msg.sender] = withdrawalRequestEpoch[msg.sender] + 3;
        }
        emit WithdrawalRequest(msg.sender, amount);
    }

    /**
     * @dev Allows users to withdraw their MAI if the conditions are met
     * The withdrawal amount must be the amount the user put in their request. Nothing more.
     */
    function withdraw() public {
        uint256 amount = withdrawalAmount[msg.sender];
        if (amount == 0) {
            revert NoWithdrawalRequested();
        }
        uint256 userShare = (amount * totalSupply()) / totalUnderlying;
        if (balanceOf(msg.sender) < userShare) {
            revert InsufficientUserBalance(balanceOf(msg.sender), userShare);
        }
        if (underlying.balanceOf(address(this)) < userShare) {
            revert InsufficientContractBalance(underlying.balanceOf(address(this)), userShare);
        }
        if (!canWithdraw(msg.sender)) {
            revert WithdrawalNotAllowedYet();
        }

        _burn(msg.sender, userShare);
        withdrawalAmount[msg.sender] = 0;
        totalUnderlying -= amount;
        if (!underlying.transfer(msg.sender, amount)) {
            revert TransferToUserFailed();
        }
        emit Withdraw(msg.sender, amount);
    }

    // Error functions
    error TransferFailed();
    error NoWithdrawalRequested();
    error InsufficientUserBalance(uint balance, uint withdrawAmount);
    error InsufficientContractBalance(uint balance, uint withdrawAmount);
    error WithdrawalNotAllowedYet();
    error TransferToUserFailed();

    // Event functions
    event Deposit(address indexed user, uint256 amount);
    event EarnToken(address indexed user, uint256 amount);
    event WithdrawalRequest(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
}