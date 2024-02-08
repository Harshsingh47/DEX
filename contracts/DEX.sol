// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DEX is ReentrancyGuard {
    uint256 public feePercentage = 30; // Fee percentage 30 = 0.3% as per the uniswap.
    uint256 public intialLPBalane = 10000;

    /// @notice A struct representing the liquidity pool in a decentralized exchange (DEX).
    /// @dev The liquidity pool contains mappings for token balances, LP token balances, and the total LP token balance.
    struct LiquidityPool {
        // Mapping to track token balances contributed by liquidity providers.
        mapping(address => uint256) tokenBalance;
        // Mapping to track LP token balances issued to liquidity providers.
        mapping(address => uint256) lpTokenBalance;
        // Represents the total supply of LP tokens in the liquidity pool.
        uint256 totalLPBalance;
    }

     /// @dev Mapping to store Liquidity Pools, with bytes keys derived from specific parameters.
    /// Each Liquidity Pool is represented by a struct containing token balances and total LP tokens.
    mapping(bytes => LiquidityPool) public liquidityPool;

    // Modifiers
    modifier validAddress(address tokenA, address tokenB) {
        require(
            tokenA != address(0) && tokenB != address(0),
            "Invalid tokenAddress"
        );
        require(tokenA != tokenB, "Token address cannot be same");
        _;
    }

    modifier isPoolExists(address tokenA, address tokenB) {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        require(pool.tokenBalance[tokenA] != 0, "pool must exist");
        require(pool.tokenBalance[tokenB] != 0, "pool must exist");
        _;
    }

    modifier checkTokenBalanceandAllowance(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) {
        IERC20 contractA = IERC20(tokenA);
        IERC20 contractB = IERC20(tokenB);

        require(
            contractA.balanceOf(msg.sender) >= amountA &&
                contractB.balanceOf(msg.sender) >= amountB,
            "Insuffiecient Balance!!!"
        );

        require(
            contractA.allowance(msg.sender, address(this)) >= amountA &&
                contractB.allowance(msg.sender, address(this)) >= amountB,
            "Insuffiecient allowance"
        );

        _;
    }

    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @param amountA The initial amount of tokenA to be deposited into the pool.
    /// @param amountB The initial amount of tokenB to be deposited into the pool.
    /// @dev It initializes the pool with the provided amounts and stores it in the liquidityPool mapping.
    function createPair(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        public
        validAddress(tokenA, tokenB)
        checkTokenBalanceandAllowance(tokenA, tokenB, amountA, amountB)
        nonReentrant
    {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        require(pool.tokenBalance[tokenA] == 0, "Pair already exists");

        //deposit tokens into contract
        transferTokens(tokenA, tokenB, amountA, amountB);

        pool.tokenBalance[tokenA] = amountA;
        pool.tokenBalance[tokenB] = amountB;
        pool.lpTokenBalance[msg.sender] = intialLPBalane;
    }

    /// @notice Adds liquidity to an existing Liquidity Pool pair by depositing specified amounts of tokens.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @param amountA The amount of tokenA to be deposited into the pool.
    /// @param amountB The amount of tokenB to be deposited into the pool.
    /// @dev It updates the token balances and LP token supply accordingly.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    )
        public
        validAddress(tokenA, tokenB)
        checkTokenBalanceandAllowance(tokenA, tokenB, amountA, amountB)
        isPoolExists(tokenA, tokenB)
        nonReentrant
    {
        address contractA = tokenA;
        address contractB = tokenB;
        uint256 tokenAAmount = amountA;
        uint256 tokenBAmount = amountB;
        LiquidityPool storage pool = getPool(contractA, contractB);
        uint256 tokenAPrice = getSpotPrice(contractA, contractB);
        require(
            tokenAPrice * tokenAAmount == tokenBAmount * 1e18,
            "Invalid liquidity amount"
        );

        transferTokens(contractA, contractB, tokenAAmount, tokenBAmount);

        uint256 tokenABalance = pool.tokenBalance[contractA];
        uint256 lpToken = (tokenAAmount * intialLPBalane) / tokenABalance;

        pool.tokenBalance[contractA] = tokenAAmount;
        pool.tokenBalance[contractB] = tokenBAmount;
        pool.totalLPBalance += lpToken;
        pool.lpTokenBalance[msg.sender] = intialLPBalane;
    }

    /// @notice Removes liquidity from an existing Liquidity Pool pair by redeeming LP tokens.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @dev It then updates the token balances and LP token supply accordingly.
    function removeLiquidity(address tokenA, address tokenB)
        public
        validAddress(tokenA, tokenB)
        isPoolExists(tokenA, tokenB)
        nonReentrant
    {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        uint256 balance = pool.lpTokenBalance[msg.sender];
        require(balance > 0, "NO liquidity provided by user");

        // Amount to be transferred back to the user
        uint256 tokenAAmount = (balance * pool.tokenBalance[tokenA]) /
            pool.totalLPBalance;
        uint256 tokenBAmount = (balance * pool.tokenBalance[tokenB]) /
            pool.totalLPBalance;

        pool.lpTokenBalance[msg.sender] = 0;
        pool.tokenBalance[tokenA] -= tokenAAmount;
        pool.tokenBalance[tokenB] -= tokenBAmount;
        pool.totalLPBalance -= balance;

        // transfer token
        IERC20 contractA = IERC20(tokenA);
        IERC20 contractB = IERC20(tokenB);

        require(
            contractA.transfer(msg.sender, tokenAAmount),
            "Transfer failed"
        );
        require(
            contractB.transfer(msg.sender, tokenBAmount),
            "Transfer failed"
        );
    }

    /// @notice Initiates a token swap from one token to another within an existing Liquidity Pool pair.
    /// @param from The address of the token to swap from.
    /// @param to The address of the token to swap to.
    /// @param amount The amount of tokens to be swapped.
    /// @dev It executes the token swap, updating token balances accordingly.
    function swap(
        address from, // from token contract
        address to, // to token contract
        uint256 amount
    ) public validAddress(from, to) isPoolExists(from, to) nonReentrant {
        LiquidityPool storage pool = getPool(from, to);

        uint256 r = 10000 - feePercentage; // here 10000 = 100%
        uint256 rDeltaX = (r * amount) / 10000;

        uint256 outputTokens = (pool.tokenBalance[to] * rDeltaX) /
            (pool.tokenBalance[from] + rDeltaX);

        pool.tokenBalance[from] += amount;
        pool.tokenBalance[to] -= outputTokens;

        // send and receive tokens
        IERC20 contractFrom = IERC20(from);
        IERC20 contractTo = IERC20(to);

        require(
            contractFrom.transferFrom(msg.sender, address(this), amount),
            "transfer from user failed"
        );
        require(
            contractTo.transfer(msg.sender, outputTokens),
            "transfer to user failed"
        );
    }

    /// @notice Retrieves the current price of one token in terms of another from the Liquidity Pool.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return The current price of one tokenA in terms of tokenB.
    /// @dev It calculates and returns the price of one token in terms of another based on their respective balances.
    function getSpotPrice(address tokenA, address tokenB)
        public
        view
        returns (uint256)
    {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        require(
            pool.tokenBalance[tokenA] > 0 && pool.tokenBalance[tokenB] > 0,
            "Invlaid token amount"
        );
        uint256 price = (pool.tokenBalance[tokenB] * 1e18) /
            pool.tokenBalance[tokenA];
        return price;
    }   

    /// @notice Retrieves the current balances of both tokens within the specified Liquidity Pool.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return tokenABalance The balance of tokenA in the Liquidity Pool.
    /// @return tokenBBalance The balance of tokenB in the Liquidity Pool.
    function getBalances(address tokenA, address tokenB)
        external
        view
        returns (uint256 tokenABalance, uint256 tokenBBalance)
    {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        return (pool.tokenBalance[tokenA], pool.tokenBalance[tokenB]);
    }

    /// @notice Retrieves the current LP (Liquidity Provider) token balance for a specified Liquidity Pool pair.
    /// @param liquidityProvider The address of the LP token.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @return The current balance of LP tokens associated with the Liquidity Pool pair.
    function getLpBalance(
        address liquidityProvider,
        address tokenA,
        address tokenB
    ) external view returns (uint256) {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        return (pool.lpTokenBalance[liquidityProvider]);
    }

    /// @notice Retrieves the total supply of LP tokens for a specified Liquidity Pool pair.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @return The total supply of LP tokens associated with the Liquidity Pool pair.
    /// @dev The function retrieves the Liquidity Pool for the specified token pair and returns the total LP token supply.
    function getTotalLpTokens(address tokenA, address tokenB)
        external
        view
        returns (uint256)
    {
        LiquidityPool storage pool = getPool(tokenA, tokenB);
        return (pool.totalLPBalance);
    }

    // Internal functions

    /// @notice Retrieves the Liquidity Pool for the specified token pair.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @return pool The Liquidity Pool struct associated with the Liquidity Pool pair.
    /// @dev The function calculates the key for the specified Liquidity Pool pair based on token addresses and retrieves it from the mapping.
    function getPool(address tokenA, address tokenB)
        internal
        view
        returns (LiquidityPool storage pool)
    {
        bytes memory key;
        if (tokenA < tokenB) {
            key = abi.encodePacked(tokenA, tokenB);
        } else {
            key = abi.encodePacked(tokenB, tokenA);
        }
        return liquidityPool[key];
    }

    // @notice Transfers specified amounts of two tokens from the caller to the contract.
    /// @param tokenA The address of the first token to transfer.
    /// @param tokenB The address of the second token to transfer.
    /// @param amountA The amount of tokenA to transfer.
    /// @param amountB The amount of tokenB to transfer.
    /// @dev It transfer tokens and reverts if any transfer fails.
    function transferTokens(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        IERC20 contractA = IERC20(tokenA);
        IERC20 contractB = IERC20(tokenB);

        require(
            contractA.transferFrom(msg.sender, address(this), amountA),
            "Transfer failed"
        );
        require(
            contractB.transferFrom(msg.sender, address(this), amountB),
            "Transfer failed"
        );
    }
}
