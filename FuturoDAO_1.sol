// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ==============================
// OpenZeppelin Contracts
// ==============================
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ==============================
// Price Oracle (Mock for Testing)
// ==============================
contract PriceOracle is Ownable {
    uint256 public currentPrice;
    uint256 public lastUpdateTime;

    constructor(uint256 initialPrice, address _owner) Ownable(_owner) {
        currentPrice = initialPrice;
        lastUpdateTime = block.timestamp;
    }

    function updatePrice(uint256 newPrice) external onlyOwner {
        currentPrice = newPrice;
        lastUpdateTime = block.timestamp;
    }

    function getTWAP() external view returns (uint256) {
        // Simplified TWAP (use Chainlink in production)
        return currentPrice;
    }
}

// ==============================
// Binary Options Contract
// ==============================
contract BinaryOption is ERC20 {
    using SafeERC20 for IERC20;

    // Core parameters
    IERC20 public immutable paymentToken; // USDC
    address public immutable governance;
    uint256 public immutable strikePrice;
    uint256 public immutable expiryTime;
    PriceOracle public oracle;
    bool public exercised;

    constructor(
        address _paymentToken,
        address _oracle,
        address _governance,
        uint256 _strikePrice,
        uint256 _expiryTime,
        uint256 _totalOptions
    ) ERC20("FuturoDAO Option", "FDAO-OPT") {
        paymentToken = IERC20(_paymentToken);
        oracle = PriceOracle(_oracle);
        governance = _governance;
        strikePrice = _strikePrice;
        expiryTime = _expiryTime;
        
        _mint(_governance, _totalOptions);
    }

    // Exercise options if price is above strike
    function exercise() external {
        require(block.timestamp > expiryTime, "Not expired");
        require(!exercised, "Already exercised");
        
        uint256 currentPrice = oracle.getTWAP();
        require(currentPrice > strikePrice, "Not in-the-money");

        exercised = true;
        uint256 paymentAmount = totalSupply();
        paymentToken.safeTransfer(governance, paymentAmount);
    }

    // Governance distributes options to voters
    function distribute(address voter, uint256 amount) external {
        require(msg.sender == governance, "Unauthorized");
        _transfer(governance, voter, amount);
    }
}
