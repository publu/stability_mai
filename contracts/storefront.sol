pragma solidity 0.8.17;

import "../interfaces/internal/IStableQiVault.sol";
import "./base/BaseLiquidator.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// This contract is a test idea on how the process of socializing liquidations could work

/*
    Ideas:
        Separate liquidation system into delegateCall

        Separate storefront system into delegateCall

        Separate withdrawal system into delegateCall

        entry can be direct?

        What if this is on gnosis safe?      
*/

/*
This contract serves as a storefront for liquidating collateral and exchanging it for a cost in MAI.
The contract is split into three main functions:
 - stability pool
    - Users can deposit MAI and own a share of the total value locked in the contract
    - and can later withdraw them after 2 weeks waiting period. 
 - liquidation functions that can be called by users or protocol bots to liquidate vaults.
    - buy risky which is a passthrough to buy risky debt
    - The liquidation process is done in batches and is only possible for vaults that have been authorized and added to the contract.
 - storefront functions 
    - arbitrage users can sell their MAI for collateral
    - the storefront values mai at $1 which should provide upwards pressure for peg

There are also ancilliary functions that help operations
 - The contract also has an owner role to manage operations like setting the split rate of earnings and authorizing vaults
*/

interface AggregatorV3InterfaceLike {
    function decimals() external view returns (uint8);
}
/**
	@title 	A Storefront contract to offer liquidated collateral for mai
	@notice Storefront is resposible for liquidating collateral from a vault and 
			offering it a cost of Mai. Effectively, price MAI at one dollar.
	@dev	The contract is split up between liquidation functions and functions called 
			by a user/protocol wanting to reap MAI Staking awards.
 */

 /*
    CHECK
    Reentrancy (erc721)
 */
contract Storefront is ERC20, BaseLiquidator, ReentrancyGuard {


    error Storefront__VaultNotAddedError();
    error Storefront__PermissionsError();
    error Storefront__MoreThanEarned();
    error Storefront__NotEnoughMAI();
    error Storefront__MinAmountMAI();
    error Storefront__StabilityPoolShouldLiquidate();

    uint256 public liqReward;
    uint256 public minMAI;
    uint256 public minDeposit;
    uint256 public split;
    uint256 public earnedPending;
    uint256 public earnedWithdrawn;
    uint256 public constant TWO_WEEKS = 1_210_000;
    uint256 public constant TEN_THOUSAND = 10_000;

    address[] private allVaults;

    struct Vault { // any immutable vault variables should go here.
        address collateral;
        bool added;
        bool disabled;
        uint256 decimalDifferenceRaisedToTen;
    }

    mapping(address => Vault) private added;
    address public mai;

    /**
        @dev Event emitted when a collateral is liquidated from a vault
        @param vault address of the vault that is liquidated
        @param vaultID id of the vault that is liquidated
        @param cost cost of the mai token in exchange of the collateral
    */
    event Liquidate(address vault, uint256[] vaultID, uint256 cost);

    /**
        @dev AddedVault
        @notice This event is emitted when a vault is added to the list of authorized vaults.
        @param sender The address of the message sender (the account adding the vault)
        @param vault The address of the vault that has been added.
    */
    event AddedVault(address sender, address vault);

    /**
        @dev Event emitted when contract owner withdraws earned funds
        @param sender address of the contract owner who withdraw the funds
        @param amount amount of earned funds withdrawn
    */
    event WithdrawEarned(address sender, uint256 amount);

    /**
        @dev StorefrontSale
        @dev Emits when a user sells collateral for MAI in the Storefront contract.
        @param vault The address of the vault that the collateral is being sold from
        @param amountMAI The amount of MAI received in the sale
        @param collateral The amount of collateral being sold
        @param collateralValue The value of the collateral in the underlying asset
    */
    event StorefrontSale(address vault, uint256 amountMAI, uint256 collateral, uint256 collateralValue);

    /**
        @dev Event emitted when the split value (in basis points) between earned funds and protocol funds is set
        @param _split The new split value represented in basis points
    */
    event SetSplit(uint256 _split);

    /**
         * @dev SetMinMai
         * @notice emitted when the minimum amount of MAI required to buy from contract is changed by an owner
         * @param _minMAI the new minimum amount of MAI required to enter the contract
     */
    event SetMinMai(uint256 _minMAI);

    /**
         * @dev SetMinDeposit
         * @notice emitted when the minimum amount of MAI required to deposit in the contract is changed by an owner
         * @param _minDeposit the new minimum amount of MAI required to deposit
     */
    event SetMinDeposit(uint256 _minDeposit);

    /**
         * @dev Event emitted when the liquidation reward percentage is updated
         * @param _liqReward The new liquidation reward percentage
     */
    event SetLiqReward(uint256 _liqReward);

    /**
         * @dev Event emitted when the a vault is disabled/enabled
         * @param _vault Vault being distabled
         * @param _disabled disable status of _vault
     */
    event SetVaultDisabled(address _vault, bool _disabled);


    /**
        @dev StorefrontEnter
        @notice Event emitted when a user enters the Storefront by depositing MAI
        @param sender The address of the user making the deposit
        @param shareAmount The number of shares the user receives for their deposit
        @param amount The amount of MAI the user deposited
    */
    event StorefrontEnter(address sender, uint256 shareAmount, uint256 amount);

    /**
        @dev StorefrontLeave
        @notice This event is emitted when a user leaves the Storefront contract by calling the leave() function
        @param sender address of the user who is leaving the contract
        @param _share the number of share tokens the user is selling back to the contract
        @param _mai the number of MAI tokens the user will receive as a result of selling back their share tokens
    */
    event StorefrontLeave(address sender, uint256 _share, uint256 _mai);


    constructor() AdminERC20("Stability Mai Stablecoin", "SMS") {
    	split = 6000; // percent in basis points, 10k max
        minDeposit = 1e18;
    }

    /**
        @dev internal function to check if the vault was added to the list of authorized vaults
        @param _vault address of the vault to validate
    */
    function _validateVault(address _vault) internal view {
        if (!added[_vault].added || added[_vault].disabled) revert Storefront__VaultNotAddedError();
    }

    /**
        @dev internal function to check if the vault has not been added to the list of authorized vaults
        @param _vault address of the vault to invalidate
    */
    function _invalidateVault(address _vault) internal view {
        if (added[_vault].added) revert Storefront__PermissionsError();
    }

    /**
        @dev modifier to check permission of the given vault address
        @param _vault address of the vault 
    */
    modifier assertAdded(address _vault) {
        _validateVault(_vault);
        _;
    }

    /**
        @dev modifier to check permission of the given vault address
        @param _vault address of the vault 
    */
    modifier assertNotAdded(address _vault) {
        _invalidateVault(_vault);
        _;
    }

    /**
        @dev Function to liquidate collateral from a vault and exchange it for a cost in MAI token
        @param _vault address of the vault to liquidate
        @param _vaultIDs ids of the vault to liquidate
        @param _front front end that receives the fee
    */
    function liquidate(
    	address _vault,
    	uint256[] calldata _vaultIDs,
    	int256 _front
    	) 
        public 
        assertAdded(_vault) {

        uint256 gain = _gainRatio(_vault)-1000; // ex: 1100-1000=100 which is 10% in the ten_thousands (bp)

        ERC20Like _mai = ERC20Like(mai);
        uint256 before = _mai.balanceOf(address(this));

        uint256 count;
		for (uint i=0; i<_vaultIDs.length; i++) {
            if(_liquidate(_vault, _vaultIDs[i], _front)){
                count++;
            }           
		}
        uint256 despues = _mai.balanceOf(address(this));
        uint256 protocolFee = (before-despues) * gain * split / TEN_THOUSAND;
        earnedPending+=protocolFee;

        if(liqReward !=0){
            // on average the reward value will be lower than expected
            // ex: minting 1 mai, would mean minting 0.98 or less. 
            // to be expected bc we need to reduce the gas costs associated with liquidating.

            // could base the liqReward on tx.gasprice but that's gameable
            // doesn't reward good behavior.

            // 20c sMAI sounds good

            _mint(msg.sender, (count) * liqReward);
        }

        emit Liquidate(_vault, _vaultIDs, ((before-despues)));
    }

    /**
        @dev Function to retrieve liquidated collateral from a vault
        @param _vault address of the vault from which to retrieve the collateral
        @notice Only authorized vaults can have their collateral retrieved
        @notice Call the `getPaid()` function on the vault to retrieve the collateral into the storefront
        @notice This function can be called periodically to save gas
    */
    function getPaid(address _vault) 
        public 
        assertAdded(_vault) {
        // after liquidation we gotta call getPaid to retrieve the collateral.
        // this doesnt need to be done each time, so to save gas we can just do it at some point
        IStableQiVault(_vault).getPaid();
        // for v2 vaults we don't need to worry having a call for this, since anyone could call getPaid(address) for us,
        // and then we get the tokens
    }

    /**
        @dev Function to buy risky token
        @param _vault address of the vault
        @param _vaultID id of the risky vault
        @notice Can only execute buy risky on authorized vaults
        @notice call the _buyrisky(_vault, _vaultID) internal function
    */
    function buyrisky(address _vault, uint256 _vaultID) 
        public 
        nonReentrant
        assertAdded(_vault)
        {
        _buyrisky(_vault, _vaultID);
    }

    /**
         * @dev This function is used to handle a liquidation scenario where the storefront contract does not have enough MAI locked to cover the cost of the liquidation. 
         * It first checks the cost of the liquidation and reverts if the cost is lesser than the amount of MAI available
         * @param _vault Address of the vault being liquidated
         * @param _vaultID ID of the vault being liquidated
         * @param _front The amount of collateral being liquidated
     */
    function passthroughLiquidate(
        address _vault, 
        uint256 _vaultID,
        int256 _front)
        public
        assertAdded(_vault) {
        /*
            CHECK
            that gain must be accounted for liq bonus splitting
        */
        uint256 gain = _gainRatio(_vault)-1000; // ex: 1100-1000=100 which is 10% in the ten_thousands

        uint256 cost = _checkLiquidationCost(_vault, _vaultID);
        //uint256 totalCost = (cost*split/TEN_THOUSAND) + cost;
        if(cost < getMaiLocked()) revert Storefront__StabilityPoolShouldLiquidate();

        ERC20Like(mai).transferFrom(msg.sender, address(this), cost);

        _liquidate(_vault, _vaultID, _front);

        /*  
            CHECK
            Send mai from user "cost"
        */
        IStableQiVault vault = IStableQiVault(_vault);
        ERC20Like collat = ERC20Like(vault.collateral());
        uint256 before = collat.balanceOf(address(this)); // 1k
        vault.getPaid();
        uint256 despues = collat.balanceOf(address(this));  // 800
        uint256 earned = despues - before;

        collat.transfer(msg.sender, earned);
    }

    /**
        @dev Function to add a vault to the list of authorized vaults
        @param _vault address of the vault to add
        @notice _collateral address of the collateral token used by the vault
        @notice _decimalDifferenceRaisedToTen decimal difference raised to ten for the vault
    */
    function addVault(address _vault) 
        external 
        assertNotAdded(_vault) 
        onlyOwner {
        
        IStableQiVault vault = IStableQiVault(_vault);
        if (mai == address(0)) {
            mai = vault.mai();
        }

        added[_vault] = Vault(
            vault.collateral(),
            true,
            false,
            vault.decimalDifferenceRaisedToTen()
        );
        allVaults.push(_vault);
        ERC20Like(mai).approve(_vault, type(uint256).max);
        emit AddedVault(msg.sender, _vault);
    }
    
    /**
        @dev Function to withdraw earned funds.
        @param amount amount of earned funds to withdraw
        @notice only contract owner can execute the function 
        @notice require the sufficient balance of mai token
        @notice require the sufficient earned pending
        @notice emit the event WithdrawEarned on successfull withdraw
    */
    function withdrawEarned(uint256 amount) 
        external 
        onlyOwner {
        ERC20Like _mai = ERC20Like(mai);
        uint256 currentBalance = _mai.balanceOf(address(this));

        if(currentBalance < amount) revert Storefront__NotEnoughMAI();
        if(earnedPending < amount) revert Storefront__MoreThanEarned();

        earnedPending-=amount;
        earnedWithdrawn+=amount;
        _mai.transfer(msg.sender, amount);
        emit WithdrawEarned(msg.sender, amount);
    }

    /**
        @dev Function to get the total amount of locked collateral from an authorized vault
        @param _vault address of the authorized vault to get the locked collateral amount from
        @return the total amount of locked collateral 
        @notice Only authorized vaults can be used 
        @notice Using the balance of the collateral stored and liquidation debt to calculate the total amount of locked collateral 
        @notice Return total amount of locked collateral by multiplying addition by oracle price then divide by the price of MAI as set in the vault ($1)
    */
    function getLockedFromVaultAddress(address _vault)
        public
        view
        assertAdded(_vault)
        returns (uint256)
    {
        uint256 addition = ERC20Like(added[_vault].collateral).balanceOf(
            address(this)
        ); // how much collateral of a _vault are we holding?
        
        IStableQiVault vault = IStableQiVault(_vault);

        addition += vault.maticDebt(address(this));
        // this is all the collateral held by us.
        // then we multiply
        return
            (addition * vault.getEthPriceSource() * added[_vault].decimalDifferenceRaisedToTen) /
            vault.getTokenPriceSource(); // collat * price / decimals
    }

    /**
        @dev Function to get the total amount of locked MAI
        @return the total amount of locked MAI 
        @notice Using the balanceOf of mai contract to get the total amount of locked MAI
    */
    function getMaiLocked()
        public 
        view 
        returns (uint256){
        ERC20Like _mai = ERC20Like(mai);
        return _mai.balanceOf(address(this));
    }
    /**
        @dev Function to get the total value of locked collateral
        @return the total value of locked in storefront
        @notice Using the getLockedFromVaultAddress and getMaiLocked functions to calculate the total value of locked collateral
        @notice Subtracting earnedPending from the total value to return the current total value of locked collateral
    */
    function totalValueLocked() 
        public 
        view 
        returns (uint256) {
        uint256 addition = getLockedFromVaultAddress(allVaults[0]);
        for (uint16 j = 1; j < allVaults.length; j++) {
            addition += getLockedFromVaultAddress(allVaults[j]);
        }

        // mai stored + every vault we add to this.
        return (addition + getMaiLocked()) - earnedPending;
    }

    /**
        @dev Function to get the amount of available collateral from a specific vault
        @param _vault address of the vault to check the available collateral from
        @return the amount of available collateral
        @notice Using the balanceOf of collateral contract to get the amount of available collateral held by this contract for a specific vault
        @notice The function first asserts if the vault is an added vault and then return the balance of collateral of the vault
    */
    function getAvailableCollateral(address _vault) 
        external 
        view
        assertAdded(_vault)
        returns (uint256) {
        ERC20Like collateral = ERC20Like(added[_vault].collateral);
        return collateral.balanceOf(address(this));
    }

    /**
        @dev Function to sell collateral for a specific amount of MAI
        @param _vault address of the vault that the collateral type
        @param amountMAI amount of MAI token to be received in exchange for the collateral
        @notice This function uses the _mai contract to transfer the amount of MAI from msg.sender to the contract
        @notice The function also uses the collateral contract to transfer an equivalent amount of collateral to the msg.sender
        @notice It performs a conversion of the amount of MAI to a corresponding amount of collateral by performing mathematical operations with the getEthPriceSource, decimalDifferenceRaisedToTen
        @notice The function first asserts if the vault is an added vault and then checks for enough collateral held by the contract for the sale before proceeding
    */
    function sellCollateralForMAI(address _vault, uint256 amountMAI) 
        external
        assertAdded(_vault)
        {
        if(amountMAI<minMAI) revert Storefront__MinAmountMAI();

        if(IStableQiVault(_vault).maticDebt(address(this)) != 0)  {
            IStableQiVault(_vault).getPaid();
        }

        // CHECK - https://github.com/publu/maistables/commit/b6fac566ab3b644cfe79b428740937f4dfa2d299
        ERC20Like _mai = ERC20Like(mai);
        ERC20Like collateral = ERC20Like(added[_vault].collateral);
        uint256 available = collateral.balanceOf(address(this));
        uint256 collateralValue = IStableQiVault(_vault).getEthPriceSource();
        
        // lets say steth 1702.00000168, period is me putting in decimals

        /*
            CHECK
            Oracle doesn't need to be instantiated here IF we assume that 1e8 is always the decimals for the price
            reduce gas
        */
        uint256 decimalDifferenceWithOracleRaisedToTen = 10 ** 10;//(_mai.decimals() - AggregatorV3InterfaceLike(IStableQiVault(_vault).ethPriceSource()).decimals());
        // 10 ** (18 - 8) = 10 ** 10

        uint256 collateralDecimalsRaisedToTen = (10 ** collateral.decimals()); // 10 ** 18

        uint256 denominator = collateralValue * decimalDifferenceWithOracleRaisedToTen; // 170200000168(techncially 1e8) * 10 ** 10 = 1e19

        uint256 toGive = (amountMAI * collateralDecimalsRaisedToTen)  / denominator; // 1e18 * 1e19 / 1e19 = 1e18

        if(available < toGive){
            // update selling parameters
            amountMAI = (available * denominator) / collateralDecimalsRaisedToTen; // 1e18 * 1e19 / e19 = 1e18 (good cause mai is 1e18)
            toGive = available;
        }
        
        _mai.transferFrom(msg.sender, address(this), amountMAI);
        collateral.transfer(msg.sender, toGive);

        emit StorefrontSale(_vault, amountMAI, toGive, collateralValue);
    }

    /**
        * @dev Allows a user to deposit MAI to the contract in exchange for SMS tokens.
        * The number of SMS tokens minted for the user is calculated proportionately to the current total locked value of the contract.
        * @notice Deposited MAI is locked for 2 weeks from the time of deposit
        * @param _amount The amount of MAI the user wants to deposit
    */
    function depositMAI(uint256 _amount) 
        public {
        
        if(_amount < minDeposit) {
            revert Storefront__MinAmountMAI();
        }
        /* CHECK -  possible reentrancy here so changed up the code a bit */
        ERC20Like _mai = ERC20Like(mai);

        uint256 totalValue = totalValueLocked();
        uint256 totalShares = totalSupply();

         _mai.transferFrom(msg.sender, address(this), _amount);

        uint256 what = _amount;
        if (totalShares != 0 && totalValue != 0) {
            what = (_amount * totalShares) / totalValue;
        }

        // ensures no first depositor is frontrunned - v unlikely however
        // require(what !=, "0");

        _mint(msg.sender, what);

        emit StorefrontEnter(msg.sender, _amount, what);
    }

    /**
        @dev Calculates the underlying assets of the provided share.
        @param _share the number of shares to calculate the underlying assets for
        @return the underlying assets represented by the provided share
    */
    function calculateUnderlying(uint256 _share) 
        public 
        view 
        returns (uint256) {
        uint256 totalValue = totalValueLocked();
        uint256 what = (_share * totalValue) / totalSupply(); // is that a fair calculation?
        return what;
    }

    /**
        @dev Function to allow a user to leave the contract and retrieve their underlying assets (MAI)
        @param _share the amount of share the user wants to redeem
        @notice The user must wait 2 weeks after the last deposit before being able to leave.
        @notice _share is converted to underlying assets (MAI) by proportionally dividing the _share by the totalSupply and multiplying by totalValueLocked.
    */
    function leave(uint256 _share) external {
        uint256 what = calculateUnderlying(_share);
        _burn(msg.sender, _share);
        ERC20Like _mai = ERC20Like(mai);
        _mai.transfer(msg.sender, what);
        emit StorefrontLeave(msg.sender, _share, what);
    }

    /**
        @dev Function to set the split percentage for earned funds
        @param _split split percentage (0-10000)
    */
    function setSplit(uint256 _split) external onlyOwner {
        split = _split;
        emit SetSplit(_split);
    }

    /**
         * @dev Allows the contract owner to set the minimum amount of MAI required to buy collateral from contract
         * @param _minMAI The minimum amount of MAI required to buy collateral from contract
     */
    function setMinMAI(uint256 _minMAI) external onlyOwner {
        minMAI = _minMAI;
        emit SetMinMai(_minMAI);
    }

    /**
         * @dev Allows the contract owner to set the minimum amount of MAI required to deposit in contract
         * @param _minDeposit The minimum amount of MAI required to participate in staking
     */
    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        minDeposit = _minDeposit;
        emit SetMinDeposit(_minDeposit);
    }

    /**
         * @dev Allows the contract owner to set the liquidation reward amount
         * @param _liqReward The new liquidation reward amount
     */
    function setLiqReward(uint256 _liqReward) external onlyOwner {
        liqReward = _liqReward;
        emit SetLiqReward(_liqReward);
    }


   /**
         * @dev Allows to enable or disable a vault
         * @param _vault Vault being distabled
         * @param _disabled disable status of _vault
     */
    function setVaultDisabled(address _vault, bool _disabled) external onlyOwner {
        added[_vault].disabled = _disabled;
        emit SetVaultDisabled(_vault,_disabled);
    }

    /**
        @dev returns the stored information of a vault by its position in the allVaults array
        @param _pos position of the vault in the allVaults array
        @return returns a struct of type Vault containing information about the vault such as address and its added status
    */
    function getVaultByPos(uint256 _pos) external view returns (Vault memory) {
        return added[allVaults[_pos]];
    }

    /**
        @notice getAddedVaultCount returns the number of vaults that were added to the contract
        @dev This function can be used to iterate over the added vaults and access their variables or call their functions
        @return returns the number of vaults added to the contract
    */
    function getAddedVaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    /**
     * @dev onERC721Received is a function that implements the ERC721Received interface.
     * It handles the receipt of ERC721 tokens by the contract and returns a `bytes4` value.
     * @param operator The address of the operator that is calling the function
     * @param from The address of the sender of the ERC721 token
     * @param tokenId The unique identifier of the ERC721 token being received
     * @param data Additional data, if any, that was sent along with the token
     * @return bytes4 The function selector of the ERC721Received interface
     */
    function onERC721Received( address operator, address from, uint256 tokenId, bytes calldata data ) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}