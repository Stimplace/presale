// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DeFIRELaunchPool is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    // ------------------------------------------------------------------------------- whitelisting

    // enable disable whitelisting functions
    bool public enabledWhitelisting;
    // number of addresses sent to whitelist (might not be unique)
    uint256 public whitelisted = 0;
    // whitelist address map
    mapping(address => bool) public whitelist;

    // ------------------------------------------------------------------------------- investor

    // investor info
    struct InvestorStats {
        uint256 amountInvested; // total amount invested on all transactions
        uint256 pSaleTokens;
        uint256 pSaleDegenTokens;
    }
    // investor matrix
    mapping(address => InvestorStats) public investorMatrix;

    // number of investors
    uint256 public numInvestors = 0;

    // ------------------------------------------------------------------------------- time

    //contract created
    uint256 public createTime;
    // start of the sale
    uint256 public pStartTime;
    // total duration
    uint256 public pDuration;
    // length of each epoch
    uint256 public epochTime;
    // end of the sale
    uint256 public pEndTime;

    // ------------------------------------------------------------------------------- tokens

    // presale token address
    address public immutable pSaleToken;

    // presale degen token address
    address public immutable pSaleTokenDegen;

    // invest token address (stable?18)
    address public immutable investToken;

    // ------------------------------------------------------------------------------- tokenomics

    // presale token sale ratio to invest token
    uint256 public immutable pTokenPrice;
    uint256 public immutable dTokenPrice;

    // investor minimum investment ammount in investTokens
    uint256 public minimumInvestment = 100;
    // investor initial buy allowance in investTokens
    uint256 public initialBuyAllowance = 2500;
    // investor max buy allowance in investTokens
    uint256 public maxBuyAllowance = 5000;

    //max psaleToken per investor
    uint256 public maxCapacityRegular = 100 * (10**18);
    //max psaleTokenDegen per investor
    uint256 public maxCapacityDegen = 45 * (10**18);

    // ------------------------------------------------------------------------------- treasury

    // treasury address for investToken withdrawals
    address public immutable treasuryPDeFIRE;

    // ------------------------------------------------------------------------------- events

    event addressWhitelisted(address sender);
    event addressBulkWhitelisted(address[] bulk);
    event addressRemoved(address sender);

    event pFAIRPurchased(
        address sender,
        uint256 investamount,
        uint256 pdefireamount
    );
    event dFAIRPurchased(
        address sender,
        uint256 investamount,
        uint256 ddefireamount
    );

    event withdrawInvestment(uint256 investmentTotal);
    event withdrawUnclaimed(uint256 pDeFIRELeft, uint256 dDeFIRELeft);

    // -----------------------------------------CONTRUCTOR-----------------------------------------------
    constructor(
        address _pSaleToken,
        address _pSaleTokenDegen,
        address _treasuryPDeFIRE,
        address _investToken,
        uint256 _startTime,
        uint256 _epochTime,
        uint256 _duration,
        uint256 _pTokenPrice,
        uint256 _dTokenPrice
    ) {
        // integrity checks
        require(_epochTime > 0, "epochTime must be greater than 0");
        require(_duration > 0, "duration must be greater than 0");
        require(_pSaleToken != address(0), "pSaleToken address cannot be 0x");
        require(
            _pSaleTokenDegen != address(0),
            "pSaleTokenDegen address cannot be 0x"
        );
        require(
            _treasuryPDeFIRE != address(0),
            "treasuryPDeFIRE address cannot be 0x"
        );
        require(_investToken != address(0), "investToken address cannot be 0x");
        require(_pTokenPrice > 0, "pTokenPrice must be greater than 0");
        require(_dTokenPrice > 0, "dTokenPrice must be greater than 0");

        // --------------------------------------------------- time
        createTime = block.timestamp;
        epochTime = _epochTime;
        pStartTime = _startTime;
        pDuration = _duration.mul(epochTime);
        pEndTime = pStartTime.add(pDuration);

        require(pEndTime > block.timestamp, "End Time must be in the future");

        // --------------------------------------------------- tokens

        investToken = _investToken;

        pSaleToken = _pSaleToken;

        pSaleTokenDegen = _pSaleTokenDegen;

        treasuryPDeFIRE = _treasuryPDeFIRE;

        // --------------------------------------------------- tokenomics

        pTokenPrice = _pTokenPrice;
        dTokenPrice = _dTokenPrice;
    }

    // ---------------------------------------------------------------------------------------- presale token

    function PreSaleTokenRegularAvailable()
        public
        view
        onlyOwner
        returns (uint256)
    {
        uint256 deposits = ERC20(pSaleToken).balanceOf(address(this));
        return deposits;
    }

    function PreSaleTokenDegenAvailable()
        public
        view
        onlyOwner
        returns (uint256)
    {
        uint256 deposits = ERC20(pSaleTokenDegen).balanceOf(address(this));
        return deposits;
    }

    // ---------------------------------------------------------------------------------------- whitelist ops

    //enable whitelist
    function enableWhitelist(bool _switch) external onlyOwner {
        enabledWhitelisting = _switch;
    }

    // whitelist an address
    function addWhitelist(address _address) external onlyOwner {
        require(enabledWhitelisting, "whitelisting not enabled");
        whitelist[_address] = true;
        whitelisted += 1;

        emit addressWhitelisted(_address);
    }

    // whitelist multiple addresses
    function addMultipleWhitelist(address[] calldata _addresses)
        external
        onlyOwner
    {
        require(enabledWhitelisting, "whitelisting not enabled");
        require(_addresses.length <= 5000, "jesus, too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
            whitelisted += 1;
        }
        emit addressBulkWhitelisted(_addresses);
    }

    // removes a single address from the whitelist
    function removeWhitelist(address _address) external onlyOwner {
        require(enabledWhitelisting, "whitelisting not enabled");
        whitelist[_address] = false;
        whitelisted -= 1;
        emit addressRemoved(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    // ---------------------------------------------------------------------------------------- investor stats

    function currentEpoch() public view returns (uint256) {
        if (block.timestamp < pStartTime) return 0;
        return (block.timestamp.sub(pStartTime)).div(epochTime);
    }

    function investorCurrentBuyAllowance() public view returns (uint256) {
        uint256 epochs = currentEpoch();
        uint256 currentBuyAllowance = initialBuyAllowance * (2**epochs);
        if (currentBuyAllowance > maxBuyAllowance) {
            return maxBuyAllowance * 10**ERC20(investToken).decimals();
        } else {
            return currentBuyAllowance * 10**ERC20(investToken).decimals();
        }
    }

    function checkInvestorDetails(address _investor)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        InvestorStats storage investor = investorMatrix[_investor];

        return (
            investor.pSaleTokens,
            investor.pSaleDegenTokens,
            investor.amountInvested
        );
    }

    // ---------------------------------------------------------------------------------------- investor ops

    function buyPDeFIRE(uint256 _investAmount) external nonReentrant {
        uint256 pDeFIRELeft = ERC20(pSaleToken).balanceOf(address(this));

        uint256 currentBuyAllowance = investorCurrentBuyAllowance();

        InvestorStats storage investor = investorMatrix[msg.sender];

        require(
            msg.sender != treasuryPDeFIRE,
            "Treasury address cannot partake in presale"
        );
        require(
            block.timestamp >= pStartTime,
            "Presale hasn't started yet, good things come to those who wait"
        );
        require(
            block.timestamp < pEndTime,
            "Presale has ended! Thank you for your support!"
        );
        require(pDeFIRELeft > 0, "No more pFAIR left !");
        require(
            ERC20(investToken).balanceOf(msg.sender) >= _investAmount,
            "Not enough balance to invest"
        );

        require(
            investor.pSaleTokens <= maxCapacityRegular,
            "You have reached your max capacity for this token"
        );

        require(
            _investAmount < currentBuyAllowance,
            "reached buy allowance limit for now"
        );
        require(
            investor.amountInvested < currentBuyAllowance,
            "reached buy allowance limit for now"
        );

        require(_investAmount > minimumInvestment, "below minimum investment");

        require(whitelist[msg.sender], "investor not in the whitelist!");

        assert(ERC20(pSaleToken).decimals() == ERC20(investToken).decimals());

        uint256 pDeFIREAmount = _investAmount.div(pTokenPrice);

        if (pDeFIREAmount > pDeFIRELeft) {
            pDeFIREAmount = pDeFIRELeft;
            _investAmount = pDeFIREAmount.mul(pTokenPrice);
        }

        ERC20(investToken).safeTransferFrom(
            msg.sender,
            address(this),
            _investAmount
        );
        ERC20(pSaleToken).safeTransfer(msg.sender, pDeFIREAmount);

        if (investor.amountInvested == 0) {
            numInvestors += 1;
        }

        investor.amountInvested += _investAmount;
        investor.pSaleTokens += pDeFIREAmount;

        emit pFAIRPurchased(msg.sender, _investAmount, pDeFIREAmount);
    }

    function buyDDeFIRE(uint256 _investAmount) external nonReentrant {
        uint256 dDeFIRELeft = ERC20(pSaleTokenDegen).balanceOf(address(this));

        uint256 currentBuyAllowance = investorCurrentBuyAllowance();

        InvestorStats storage investor = investorMatrix[msg.sender];

        require(
            msg.sender != treasuryPDeFIRE,
            "Treasury address cannot partake in presale"
        );
        require(
            block.timestamp >= pStartTime,
            "Presale hasn't started yet, good things come to those who wait"
        );
        require(
            block.timestamp < pEndTime,
            "Presale has ended! Thank you for your support!"
        );
        require(dDeFIRELeft > 0, "No more dFAIR left !");
        require(
            ERC20(investToken).balanceOf(msg.sender) >= _investAmount,
            "Not enough balance to invest"
        );

        require(
            investor.pSaleDegenTokens <= maxCapacityDegen,
            "You have reached your max capacity for this token"
        );

        require(
            _investAmount < currentBuyAllowance,
            "reached buy allowance limit for now"
        );
        require(_investAmount > minimumInvestment, "below minimum investment");

        require(whitelist[msg.sender], "investor not in the whitelist!");

        assert(
            ERC20(pSaleTokenDegen).decimals() == ERC20(investToken).decimals()
        );

        uint256 dDeFIREAmount = _investAmount.div(dTokenPrice);

        if (dDeFIREAmount > dDeFIRELeft) {
            dDeFIREAmount = dDeFIRELeft;
            _investAmount = dDeFIREAmount.mul(dTokenPrice);
        }

        ERC20(investToken).safeTransferFrom(
            msg.sender,
            address(this),
            _investAmount
        );
        ERC20(pSaleTokenDegen).safeTransfer(msg.sender, dDeFIREAmount);

        if (investor.amountInvested == 0) {
            numInvestors += 1;
        }

        investor.amountInvested += _investAmount;
        investor.pSaleDegenTokens += dDeFIREAmount;

        emit dFAIRPurchased(msg.sender, _investAmount, dDeFIREAmount);
    }

    // ---------------------------------------------------------------------------------------- contract ops

    function withdrawInvestmentToTreasury() public onlyOwner {
        require(block.timestamp > pEndTime, "Presale hasn't ended yet!");

        uint256 preSaleInvestment = ERC20(investToken).balanceOf(address(this));

        ERC20(investToken).safeTransfer(treasuryPDeFIRE, preSaleInvestment);

        emit withdrawInvestment(preSaleInvestment);
    }

    function withdrawUnclaimedToTreasury() external onlyOwner {
        require(block.timestamp > pEndTime, "Presale hasn't ended yet!");

        uint256 pRemaining = ERC20(pSaleToken).balanceOf(address(this));
        uint256 dRemaining = ERC20(pSaleTokenDegen).balanceOf(address(this));

        require(
            pRemaining.add(dRemaining) > 0,
            "No unclaimed tokens, nice job"
        );

        if (pRemaining > 0) {
            ERC20(pSaleToken).safeTransfer(treasuryPDeFIRE, pRemaining);
        }
        if (dRemaining > 0) {
            ERC20(pSaleTokenDegen).safeTransfer(treasuryPDeFIRE, dRemaining);
        }

        emit withdrawUnclaimed(pRemaining, dRemaining);
    }
}
