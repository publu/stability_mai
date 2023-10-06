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
     * @dev This function gets called by the liquidation contract
     * The liquidation contract takes MAI from SimpleStaker and uses it to liquidate vaults, then that contract sells the collateral.
     * After that, it sends the MAI back to SimpleStaker, using this function
     * @param amount The amount of MAI to earn
     */
    function earnToken(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);
        totalUnderlying += amount;
    }

    /**
     * @dev Checks if a user can withdraw their MAI
     * @param user The address of the user
     * @return true if the user can withdraw their MAI, false otherwise
     */
    function canWithdraw(address user) public view returns (bool) {
        uint256 currentEpoch = block.timestamp / epochLength;
        uint256 timeIntoEpoch = block.timestamp % epochLength;
        if (timeIntoEpoch <= withdrawalWindow) {
            uint256 totalBalance = underlying.balanceOf(address(this));
            if (totalBalance >= lowLiquidityThreshold + withdrawalAmount[user]) {
                return true;
            }
            else if (totalBalance >= midLiquidityThreshold + withdrawalAmount[user]) {
                return currentEpoch > withdrawalRequestEpoch[user] + 1;
            }
            else {
                return currentEpoch > withdrawalRequestEpoch[user] + 2;
            }
        }
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


