// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PriceOracle {
    // Latest price and timestamp
    uint256 public latestPrice;
    uint256 public lastUpdated;

    // For TWAP calculation
    uint256 public cumulativePrice;
    uint256 public cumulativeTime;
    uint256 public lastCumulativeTimestamp;

    address public owner;

    event PriceUpdated(uint256 price, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(uint256 initialPrice) {
        owner = msg.sender;
        latestPrice = initialPrice;
        lastUpdated = block.timestamp;
        lastCumulativeTimestamp = block.timestamp;
    }

    // Set price (should be called by a trusted off-chain process)
    function setPrice(uint256 price) external onlyOwner {
        // Update cumulative price for TWAP
        uint256 timeElapsed = block.timestamp - lastCumulativeTimestamp;
        if (timeElapsed > 0) {
            cumulativePrice += latestPrice * timeElapsed;
            cumulativeTime += timeElapsed;
        }
        latestPrice = price;
        lastUpdated = block.timestamp;
        lastCumulativeTimestamp = block.timestamp;
        emit PriceUpdated(price, block.timestamp);
    }

    // Get the latest price
    function getPrice() external view returns (uint256) {
        return latestPrice;
    }

    // Get the time-weighted average price (TWAP) since deployment or last reset
    function getTWAP() external view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastCumulativeTimestamp;
        uint256 _cumulativePrice = cumulativePrice + (latestPrice * timeElapsed);
        uint256 _cumulativeTime = cumulativeTime + timeElapsed;
        if (_cumulativeTime == 0) {
            return latestPrice;
        }
        return _cumulativePrice / _cumulativeTime;
    }

    // Optional: allow owner to transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
