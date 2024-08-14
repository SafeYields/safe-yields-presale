// /\*_
// _ @note
// _ Deposit to UI.
// _ Emma finds strats.
// _ Intermediary contracts.
// _ contract to place trades.
// \*/

### Deposit Smart Contract

Functionality:

Accept deposits from users and record their balances.
Handle multiple tokens (if applicable).

Withdraw Function:
Allow users to withdraw their deposits along with any earned returns.
Calculate the amount to be withdrawn based on the user's share in the strategy.

Balance Tracking:
Keep an accurate record of user balances and their share in each strategy.

### Intermediary Contracts

Functionality:

Strategy Interface:
Define an interface for strategy contracts that Emma can call to execute strategies.

Strategy Execution Preparation:
Prepare and validate data and parameters required by the execution contract.

Execute Strategy:
Invoke strategy execution based on Emma’s recommendations.
Ensure that strategies can handle partial withdrawals without disrupting the entire strategy.

### Execution Contract

Functionality:

Trade Execution:
Execute trades on decentralized exchanges (DEXs) or other platforms.
Integrate with DEXs like Uniswap, Sushiswap, etc.??
Token Approvals:
Approve tokens for trading.

Slippage Protection(If needed??):
Implement mechanisms to manage slippage and ensure trades are executed within acceptable bounds.

Transaction Limits:
Set limits on trade sizes to prevent market manipulation and large losses.??

### Withdrawal Management

Functionality:

Partial Strategy Closure:
Allow closing a user’s percentage allocation from the strategy without disrupting the rest of the strategy.
Calculate the user’s share of the returns and adjust their balance accordingly.

Emergency Fund:
Maintain a pool (e.g., in USDC) to handle immediate withdrawals without liquidating strategy positions.
Replenish the emergency fund regularly to manage liquidity.

Proportional Risk Allocation:
Allocate risk proportionally based on each user's contribution to the total pool.
Calculate the at-risk amount for each user based on their share in the strategy.


Closing a strategy;
1. Funds from exchange go back to respective handler
2. If pnl is positive, a performance fee charged on only the positive pnl, if not, nothing is charged
3. The controller then approves the fundManager to take the funds 
4. The handler approves the fundManager to the funds for that strategy.
5. The controller calls the fundManager to settle the strategy.
6. FundManager pulls the funds out of the resp. handler directly to itself, notes the pnl and accounts accordingly.

NB: For exchanges like GMX that require confirming orders in separate txs, no other withdrawals can be made
until the existing one has been finalized and it's funds moved out.


20k in pool
StrategyA requires 50% => 10k
All users in pool have 50% of their deposit being utilized.

At end of strategyA, we have a total of 11k, 1k as profit.

Assuming no one did anything, we should have 21k in the pool.

StrategyB takes 10k
