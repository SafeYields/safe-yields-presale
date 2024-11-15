// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../../src/trading/CEXVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CEXVaultTest is Test {
    CEXVault public vault;
    MockERC20 public asset;
    address public owner;
    address public controller;
    address public trader;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_DEPOSIT = 1000 * 10**18;
    uint256 public constant MAX_TOTAL_DEPOSIT = 10000 * 10**18;

    event StrategyFunded(address indexed strategy, uint256 amount);
    event StrategyReturned(address indexed strategy, uint256 amount, int256 pnl);

    function setUp() public {
        owner = address(this);
        controller = makeAddr("controller");
        trader = makeAddr("trader");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy mock token and vault
        asset = new MockERC20();
        vault = new CEXVault();
        
        // Initialize vault
        vault.initialize(
            IERC20(address(asset)),
            "Vault Token",
            "vTKN",
            MAX_TOTAL_DEPOSIT,
            controller,
            owner
        );

        // Setup roles
        bytes32 traderRole = vault.SAY_TRADER_ROLE();
        vault.grantRole(traderRole, trader);

        // Fund users
        asset.transfer(user1, 1000 * 10**18);
        asset.transfer(user2, 1000 * 10**18);
        asset.transfer(user3, 1000 * 10**18);
    }

    // ======== Basic Functionality Tests ========

    function test_initialization() public {
        assertEq(address(vault.asset()), address(asset));
        assertEq(vault.name(), "Vault Token");
        assertEq(vault.symbol(), "vTKN");
        assertEq(vault.maxTotalDeposit(), MAX_TOTAL_DEPOSIT);
        assertEq(vault.controller(), controller);
    }

    function test_deposit() public {
        uint256 depositAmount = 100 * 10**18;
        _depositAsUser(user1, depositAmount);
        
        assertEq(vault.balanceOf(user1), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
    }

    function test_withdraw() public {
        uint256 depositAmount = 100 * 10**18;
        _depositAsUser(user1, depositAmount);
        
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        vault.withdraw(depositAmount, user1, user1);
        vm.stopPrank();

        assertEq(vault.balanceOf(user1), 0);
        assertEq(vault.totalAssets(), 0);
    }

    
    function test_strategyFunding() public {
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);

        vm.startPrank(trader);
        vm.expectEmit(true, true, true, true);
        emit StrategyFunded(trader, depositAmount);
        vault.fundStrategy(trader, depositAmount);
        vm.stopPrank();

        assertEq(vault.fundsInTrading(), depositAmount);
    }

    function test_strategyReturn_withProfit() public {
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);
        uint256 maxWithdrawBefore= vault.maxWithdraw(user1);

        // Fund strategy
        vm.startPrank(trader);
        vault.fundStrategy(trader, depositAmount);
        
        // Return with profit
        uint256 profit = 100 * 10**18;
        asset.mint(trader, profit);
        asset.approve(address(vault), depositAmount + profit);
        
        vm.expectEmit(true, true, true, true);
        emit StrategyReturned(trader, depositAmount, int256(profit));
        vault.returnStrategyFunds(trader, depositAmount, int256(profit));
        vm.stopPrank();
        uint256 maxWithdrawAfter =vault.maxWithdraw(user1);

        assertEq(vault.totalAssets(), depositAmount + profit);
        assertGt(maxWithdrawAfter,maxWithdrawBefore);
    }

    function test_strategyReturn_withLoss() public {
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);
        uint256 maxWithdrawBefore= vault.maxWithdraw(user1);

        // Fund strategy
        vm.startPrank(trader);
        vault.fundStrategy(trader, depositAmount);
        
        // Return with loss
        uint256 loss = 100 * 10**18;
        asset.mint(trader, loss);
        asset.approve(address(vault), depositAmount - loss);
        
        vm.expectEmit(true, true, true, true);
        emit StrategyReturned(trader, depositAmount, -int256(loss));
        vault.returnStrategyFunds(trader, depositAmount, -int256(loss));
        vm.stopPrank();
        uint256 maxWithdrawAfter =vault.maxWithdraw(user1);

        assertEq(vault.totalAssets(), depositAmount - loss);
        assertLt(maxWithdrawAfter,maxWithdrawBefore);
    }

    function test_maxTotalDeposit() public {
        uint256 overLimit = MAX_TOTAL_DEPOSIT + 1;
        
        vm.startPrank(user1);
        asset.approve(address(vault), overLimit);
        vm.expectRevert(CEXVault.MaxTotalDepositExceeded.selector);
        vault.deposit(overLimit, user1);
        vm.stopPrank();
    }

    function test_pausedDeposits() public {
        vault.setDepositsPaused(true);
        
        vm.startPrank(user1);
        asset.approve(address(vault), INITIAL_DEPOSIT);
        vm.expectRevert(CEXVault.DepositsArePaused.selector);
        vault.deposit(INITIAL_DEPOSIT, user1);
        vm.stopPrank();
    }

    function test_pausedWithdrawals() public {
        // First deposit
        uint256 depositAmount = 100 * 10**18;
        _depositAsUser(user1, depositAmount);
        
        // Pause withdrawals
        vault.setWithdrawalsPaused(true);
        
        vm.startPrank(user1);
        vm.expectRevert(CEXVault.WithdrawalsArePaused.selector);
        vault.withdraw(depositAmount, user1, user1);
        vm.stopPrank();
    }

    function test_zeroStrategyReturn() public {
        vm.startPrank(trader);
        vm.expectRevert(CEXVault.InvalidAmount.selector);
        vault.returnStrategyFunds(trader, 0, 0);
        vm.stopPrank();
    }

    function test_multipleUsersWithProfitDistribution() public {
        // User 1 deposits
        uint256 user1Deposit = 600 * 10**18;
        _depositAsUser(user1, user1Deposit);
        
        // User 2 deposits
        uint256 user2Deposit = 400 * 10**18;
        _depositAsUser(user2, user2Deposit);
        
        // Fund strategy with total amount
        uint256 totalDeposit = user1Deposit + user2Deposit;
        vm.startPrank(trader);
        vault.fundStrategy(trader, totalDeposit);
        
        // Return with profit
        uint256 profit = 100 * 10**18;
        asset.mint(trader, profit); // Mint extra tokens for profit
        asset.approve(address(vault), totalDeposit + profit);
        vault.returnStrategyFunds(trader, totalDeposit, int256(profit));
        vm.stopPrank();

        // Check proportional profit distribution
        uint256 user1Shares = vault.balanceOf(user1);
        uint256 user2Shares = vault.balanceOf(user2);
        
        assertApproxEqRel(
            vault.convertToAssets(user1Shares),
            user1Deposit + (profit * 600 / 1000),
            1e16 // 1% tolerance
        );
        
        assertApproxEqRel(
            vault.convertToAssets(user2Shares),
            user2Deposit + (profit * 400 / 1000),
            1e16 // 1% tolerance
        );
    }

    function test_strategyLoss() public {
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);

        vm.startPrank(trader);
        vault.fundStrategy(trader, depositAmount);
        
        // Return with loss
        uint256 loss = 100 * 10**18;
        uint256 returnAmount = depositAmount - loss;
        asset.approve(address(vault), returnAmount);
        
        vault.returnStrategyFunds(trader, depositAmount, -int256(loss));
        vm.stopPrank();

        assertEq(vault.totalAssets(), returnAmount);
    }

    function test_multipleUsersSequentialPnL() public {
        // User1 deposits 1000 tokens
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);
        
        // Trader makes 50% profit with user1's funds
        vm.startPrank(trader);
        vault.fundStrategy(trader, depositAmount);
        uint256 profit1 = depositAmount * 50 / 100; // 500 tokens profit
        asset.mint(trader, profit1);
        asset.approve(address(vault), depositAmount + profit1);
        vault.returnStrategyFunds(trader, depositAmount, int256(profit1));
        vm.stopPrank();

        // User2 deposits their full 1000 tokens after profit
        _depositAsUser(user2, depositAmount);
        
        // At this point:
        // - Total assets = 2500 (1000 + 500 from user1, 1000 from user2)
        // - User1 shares = 1000
        // - User2 shares ≈ 666.67 (since shares are worth more now)
        
        // Trader takes all funds and incurs 20% loss
        uint256 totalAssets = vault.totalAssets();
        vm.startPrank(trader);
        vault.fundStrategy(trader, totalAssets);
        uint256 loss = totalAssets * 20 / 100;
        asset.approve(address(vault), totalAssets - loss);
        vault.returnStrategyFunds(trader, totalAssets, -int256(loss));
        vm.stopPrank();

        // Check final withdrawable amounts
        uint256 user1Withdrawable = vault.convertToAssets(vault.balanceOf(user1));
        uint256 user2Withdrawable = vault.convertToAssets(vault.balanceOf(user2));
        
        // User1's final value should be: (1000 + 500) * 0.8 = 1200
        assertApproxEqRel(user1Withdrawable, 1200 * 10**18, 1e16);
        
        // User2's final value should be: 1000 * 0.8 = 800
        assertApproxEqRel(user2Withdrawable, 800 * 10**18, 1e16);
    }
    function test_zeroProfitScenario() public {
        uint256 depositAmount = 1000 * 10**18;
        _depositAsUser(user1, depositAmount);
        
        vm.startPrank(trader);
        vault.fundStrategy(trader, depositAmount);
        asset.approve(address(vault), depositAmount);
        vault.returnStrategyFunds(trader, depositAmount, 0); // 0 PnL
        vm.stopPrank();

        uint256 withdrawableAmount = vault.convertToAssets(vault.balanceOf(user1));
        assertEq(withdrawableAmount, depositAmount);
    }

    function test_depositWhileFundsInTrading() public {
    // Initial deposit
    uint256 initialDeposit = 1000 * 10**18;
    _depositAsUser(user1, initialDeposit);
    
    // Trader takes all funds for trading
    vm.startPrank(trader);
    vault.fundStrategy(trader, initialDeposit);
    vm.stopPrank();
    
    // User2 attempts to deposit while funds are in trading
    uint256 newDeposit = 500 * 10**18;
    _depositAsUser(user2, newDeposit);
    
    // Check that deposit succeeded and accounting is correct
    assertEq(vault.totalAssets(), initialDeposit + newDeposit);
    assertEq(vault.fundsInTrading(), initialDeposit);
    
    // When trader returns funds with profit
    uint256 profit = 100 * 10**18;
    vm.startPrank(trader);
    asset.mint(trader, profit);
    asset.approve(address(vault), initialDeposit + profit);
    vault.returnStrategyFunds(trader, initialDeposit, int256(profit));
    vm.stopPrank();
    
    // Verify both users get proportional profit
    uint256 user1Shares = vault.balanceOf(user1);
    uint256 user2Shares = vault.balanceOf(user2);
    
    assertApproxEqRel(
        vault.convertToAssets(user1Shares),
        initialDeposit + (profit * initialDeposit / (initialDeposit + newDeposit)),
        1e16
    );
    
    assertApproxEqRel(
        vault.convertToAssets(user2Shares),
        newDeposit + (profit * newDeposit / (initialDeposit + newDeposit)),
        1e16
    );
}

function test_simultaneousDepositWithdrawAndTrading() public {
    // Initial deposits
    uint256 initialDeposit = 1000 * 10**18;
    _depositAsUser(user1, initialDeposit);
    _depositAsUser(user2, initialDeposit);
    
    // Trader takes half of funds
    uint256 tradingAmount = initialDeposit;
    vm.startPrank(trader);
    vault.fundStrategy(trader, tradingAmount);
    vm.stopPrank();
    
    // User3 deposits while User1 withdraws partial amount and funds are in trading
    uint256 user3Deposit = 500 * 10**18;
    uint256 user1WithdrawAmount = 400 * 10**18;
    
    _depositAsUser(user3, user3Deposit);
    
    vm.startPrank(user1);
    vault.withdraw(user1WithdrawAmount, user1, user1);
    vm.stopPrank();
    
    // Verify intermediate state
    assertEq(vault.totalAssets(), (2 * initialDeposit) - user1WithdrawAmount + user3Deposit);
    assertEq(vault.fundsInTrading(), tradingAmount);
    
    // Trader returns with loss
    uint256 loss = 200 * 10**18;
    vm.startPrank(trader);
    asset.approve(address(vault), tradingAmount - loss);
    vault.returnStrategyFunds(trader, tradingAmount, -int256(loss));
    vm.stopPrank();
    
    // Verify final balances reflect proportional losses
    uint256 expectedTotalAssets = (2 * initialDeposit) - user1WithdrawAmount + user3Deposit - loss;
    assertEq(vault.totalAssets(), expectedTotalAssets);
}

function test_withdrawalRequestExceedingAvailableFunds() public {
    // Initial deposit
    uint256 initialDeposit = 1000 * 10**18;
    _depositAsUser(user1, initialDeposit);
    
    // Trader takes 90% of funds
    uint256 tradingAmount = initialDeposit * 90 / 100;
    vm.startPrank(trader);
    vault.fundStrategy(trader, tradingAmount);
    vm.stopPrank();
    
    // User tries to withdraw full amount while most funds are in trading but transfer will revert due to insufficient funds
    vm.startPrank(user1);
    vm.expectRevert();
    vault.withdraw(initialDeposit, user1, user1);
    vm.stopPrank();
    
}

function test_multipleStrategiesWithDifferentPnL() public {
    // Initial deposits
    uint256 depositAmount = 1000 * 10**18;
    _depositAsUser(user1, depositAmount);
    _depositAsUser(user2, depositAmount);
    
    // Trader takes funds in two portions
    uint256 firstTrade = 800 * 10**18;
    uint256 secondTrade = 700 * 10**18;
    
    vm.startPrank(trader);
    // First trade
    vault.fundStrategy(trader, firstTrade);
    
    // Second trade
    vault.fundStrategy(trader, secondTrade);
    
    // Return first trade with profit
    uint256 profit = 100 * 10**18;
    asset.mint(trader, profit);
    asset.approve(address(vault), firstTrade + profit);
    vault.returnStrategyFunds(trader, firstTrade, int256(profit));
    
    // Return second trade with loss
    uint256 loss = 200 * 10**18;
    asset.approve(address(vault), secondTrade - loss);
    vault.returnStrategyFunds(trader, secondTrade, -int256(loss));
    vm.stopPrank();
    
    // Verify final total assets
    uint256 expectedTotal = (2 * depositAmount) + profit - loss;
    assertEq(vault.totalAssets(), expectedTotal);
}

function test_tradingWhileDepositsPaused() public {
    // Initial deposit
    uint256 depositAmount = 1000 * 10**18;
    _depositAsUser(user1, depositAmount);
    
    // Pause deposits but not withdrawals
    vault.setDepositsPaused(true);
    
    // Trader takes funds
    vm.startPrank(trader);
    vault.fundStrategy(trader, depositAmount);
    
    // Try deposit while paused (should fail)
    vm.stopPrank();
    vm.startPrank(user2);
    asset.approve(address(vault), depositAmount);
    vm.expectRevert(CEXVault.DepositsArePaused.selector);
    vault.deposit(depositAmount, user2);
    vm.stopPrank();
    
    // Return funds with profit while deposits still paused
    vm.startPrank(trader);
    uint256 profit = 100 * 10**18;
    asset.mint(trader, profit);
    asset.approve(address(vault), depositAmount + profit);
    vault.returnStrategyFunds(trader, depositAmount, int256(profit));
    vm.stopPrank();
    
    // Verify user1 gets all profit
    assertEq(vault.totalAssets(), depositAmount + profit);
    assertApproxEqRel(
        vault.convertToAssets(vault.balanceOf(user1)),
        depositAmount + profit,
        1e12
    );
}

    function test_pauseAll() public {
    // Initial setup
    uint256 depositAmount = 1000 * 10**18;
    _depositAsUser(user1, depositAmount);
    _depositAsUser(user2, depositAmount);
    
    // Trader takes portion of funds
    uint256 tradingAmount = 1500 * 10**18;
    vm.startPrank(trader);
    vault.fundStrategy(trader, tradingAmount);
    vm.stopPrank();
    
    vault.pauseAll();
    
    // Verify no new deposits or withdrawals possible
    vm.startPrank(user3);
    asset.approve(address(vault), depositAmount);
    vm.expectRevert(CEXVault.DepositsArePaused.selector);
    vault.deposit(depositAmount, user3);
    vm.stopPrank();
    
    vm.startPrank(user1);
    vm.expectRevert(CEXVault.WithdrawalsArePaused.selector);
    vault.withdraw(100 * 10**18, user1, user1);
    vm.stopPrank();
    
    // Trader should still be able to return funds
    vm.startPrank(trader);
    uint256 profit = 100 * 10**18;
    asset.mint(trader, profit);
    asset.approve(address(vault), tradingAmount + profit);
    vault.returnStrategyFunds(trader, tradingAmount, int256(profit));
    vm.stopPrank();
    
    // Unpause and verify users can withdraw with profit
    vault.unpauseAll();
    
    vm.startPrank(user1);
    uint256 user1Balance = vault.convertToAssets(vault.balanceOf(user1));
    vault.withdraw(user1Balance, user1, user1);
    vm.stopPrank();
    
    assertApproxEqRel(
        asset.balanceOf(user1),
        depositAmount + (profit / 2),
        1e16
    );
    }

    // ======== Helper Functions ========

    function _depositAsUser(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}