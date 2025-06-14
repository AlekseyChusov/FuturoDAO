// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentToken is ERC20, Ownable {
    constructor(address initialOwner) ERC20("PaymentToken", "PAY") Ownable(initialOwner) {
        // Mint 1,000,000 tokens to the owner
        _mint(initialOwner, 1_000_000 * 10 ** decimals());
    }

    // Owner can mint more tokens if needed
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Anyone can burn their tokens
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
