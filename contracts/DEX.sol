// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX  {
    address public owner;
    uint256 public feePercentage; // Fee percentage

    struct Liquidity {
        uint256 token1Amount;
        uint256 token2Amount;
    }

    mapping(address => Liquidity) public liquidityPools;

    event LiquidityAdded(address indexed user, uint256 token1Amount, uint256 token2Amount);

    function createPair(address token1, address token2, uint amount1, uint amount2) public {

    }

    function addLiquidity(address token1, address token2, uint amount1, uint amount2) public {

    }

    function removeLiquidity(address tokenA, address tokenB) public {

    }

    function swap(address from, address to, uint amount) public {
        
    }
    
}