// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SensparkPolygon is ERC20 {
    constructor() ERC20("Senspark", "SEN") {
        _mint(msg.sender, 10000000000*10**uint256(decimals()));
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}