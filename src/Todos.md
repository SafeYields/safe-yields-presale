1- Vest presale buyers to 5 months, unlocking 20% each month while being auto-staked
2- allow to airdrop users into the current presale pool with the same rules as 1
3- after IDO, allow users to stake SAY and unstake any time

SAY Staking
Allow protocol approved addresses to stake for anyone.
Integrate with token distributor contract(s), using callback hooks to update these contracts of stake and unstake operations.
UnStaking should not be possible while presale / IDO is live.

SAY is staked
sSAY is vested.

vest sSAY to unstake your SAY

Check for when IDO has begun.

User buys say tokens:

1. tokens gets staked and vested

After 
## Airdrop flow:

In Airdrop contract:
claimSayToken-> vest tokens -> stake tokens

Claim tokens:
In vesting contract:
claimAndUnstakeSayTokens -> unlock vest Amount -> unstake amount

## Presale Flow:

buy tokens -> vest tokens -> stake tokens

claim tokens :

unlock amount -> unstake amount