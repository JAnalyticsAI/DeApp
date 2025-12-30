pragma solidity ^0.8.0;

import "@chainlink/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AmpCollateralLending is Ownable {

    IEC20 public ampToken;
    IEC20 public stablecoinToken; // Any stablecoin (e.g., USDC);
    AggregatorV3Interface internal priceFeed; // AMP/USD pricefeed

    struct Position {

        uint256 ampCollateral; // Amt of AMP locked as collateral
        uint256 usdcDebt; // Amt of USDC used as debt
        uint256 stablecoinToken; // Amt of stablecoin borrowed

    }

    mapping(address => Position) public positions;
    uint256 public collateralFactor = 25 // 25% collateral factor

    constructor (
        address _ampToken,
        address _stablecoinToken,
        address _priceFeed
    ) {
        ampToken = IEC20(_ampToken);
        stablecoinToken = IEC20(_stablecoinToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // Deposit AMP
    function depositAmp(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        ampToken.transferFrom(msg.sender, address(this), _amount);
        positions[msg.sender].ampCollateral += _amount;
    }


    // Get latest AMP price from Chainlink
    function getLatestAmpPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    // Borrow Stablecoin against AMP

    function borrowStablecoin(uint256 _amount) external {
        Position storage userPosition = positions[msg.sender];
        require(userPosition.ampCollateral > 0, "No AMP collateral deposited");

        uint256 ampPrice = getLatestAmpPrice();
        uint256 maxBorrowable = (userPosition.ampCollateral * ampPrice * collateralFactor) / 10000;

        require(_amount <= maxBorrowable - userPosition.stablecoinToken, "Exceeds borrow limit");

        userPosition.stablecoinToken += _amount;
        stablecoinToken.transfer(msg.sender, _amount);
    }

    // Repay loan
    function repayLoan(uint256 _amount) external {

        stablecoinToken.transferFrom(msg.sender, address(this), _amount);
        Position storage userPosition = positions[msg.sender];

    }

    function getCollateralValue(address _user) public view returns (uint256) {
        Position storage userPosition = positions[_user];
        uint256 ampPrice = getLatestAmpPrice();
        return (userPosition.ampCollateral * ampPrice) / 1e8; // Adjusting for price feed decimals
    }
    

}