import hre from "hardhat";
import { BigNumber } from "ethers";

export const EXCLUDED_CONFIG_KEYS = {
  ACCOUNT_DEPOSIT_LIST: true,
  ACCOUNT_ORDER_LIST: true,
  ACCOUNT_POSITION_LIST: true,
  ACCOUNT_SHIFT_LIST: true,
  ACCOUNT_WITHDRAWAL_LIST: true,
  AFFILIATE_REWARD: true,
  AUTO_CANCEL_ORDER_LIST: true,
  CLAIMABLE_COLLATERAL_AMOUNT: true,
  CLAIMABLE_COLLATERAL_TIME_DIVISOR: true,
  CLAIMABLE_FEE_AMOUNT: true,
  CLAIMABLE_FUNDING_AMOUNT: true,
  CLAIMABLE_UI_FEE_AMOUNT: true,
  CLAIMED_COLLATERAL_AMOUNT: true,
  CLAIMABLE_COLLATERAL_FACTOR: true,
  COLLATERAL_SUM: true,
  CUMULATIVE_BORROWING_FACTOR: true,
  CUMULATIVE_BORROWING_FACTOR_UPDATED_AT: true,
  DATA_STREAM_ID: true,
  DATA_STREAM_MULTIPLIER: true,
  DEPOSIT_FEE_TYPE: true,
  DEPOSIT_LIST: true,
  FEE_RECEIVER: true,
  FEE_BATCH_LIST: true,
  FEE_DISTRIBUTOR_SWAP_TOKEN_INDEX: true,
  FEE_DISTRIBUTOR_SWAP_FEE_BATCH: true,
  FUNDING_FEE_AMOUNT_PER_SIZE: true,
  CLAIMABLE_FUNDING_AMOUNT_PER_SIZE: true,
  FUNDING_UPDATED_AT: true,
  GLV_DEPOSIT_LIST: true,
  ACCOUNT_GLV_DEPOSIT_LIST: true,
  IS_ADL_ENABLED: true,
  IS_ORACLE_PROVIDER_ENABLED: true,
  IS_ATOMIC_ORACLE_PROVIDER: true,
  LATEST_ADL_AT: true,
  MARKET_LIST: true,
  MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT: true,
  MAX_PNL_FACTOR_FOR_TRADERS: true,
  MAX_PNL_FACTOR_FOR_ADL: true,
  MAX_PNL_FACTOR_FOR_DEPOSITS: true,
  MAX_PNL_FACTOR_FOR_WITHDRAWALS: true,
  MIN_ORACLE_SIGNERS: true,
  MIN_POSITION_IMPACT_POOL_AMOUNT: true,
  NONCE: true,
  OPEN_INTEREST: true,
  OPEN_INTEREST_IN_TOKENS: true,
  ORACLE_TIMESTAMP_ADJUSTMENT: true,
  ORDER_LIST: true,
  POOL_AMOUNT: true,
  POSITION_FEE_TYPE: true,
  POSITION_IMPACT_POOL_AMOUNT: true,
  POSITION_IMPACT_POOL_DISTRIBUTED_AT: true,
  POSITION_IMPACT_POOL_DISTRIBUTION_RATE: true,
  POSITION_LIST: true,
  PRICE_FEED: true,
  PRICE_FEED_MULTIPLIER: true,
  REENTRANCY_GUARD_STATUS: true,
  SAVED_CALLBACK_CONTRACT: true,
  SAVED_FUNDING_FACTOR_PER_SECOND: true,
  SHIFT_LIST: true,
  STABLE_PRICE: true,
  SUBACCOUNT_ACTION_COUNT: true,
  SUBACCOUNT_AUTO_TOP_UP_AMOUNT: true,
  SUBACCOUNT_ORDER_ACTION: true,
  SUBACCOUNT_LIST: true,
  SWAP_FEE_TYPE: true,
  SWAP_IMPACT_POOL_AMOUNT: true,
  SWAP_PATH_MARKET_FLAG: true,
  TOTAL_BORROWING: true,
  UI_DEPOSIT_FEE_TYPE: true,
  UI_FEE_FACTOR: true,
  UI_POSITION_FEE_TYPE: true,
  UI_SWAP_FEE_TYPE: true,
  UI_WITHDRAWAL_FEE_TYPE: true,
  USER_INITIATED_CANCEL: true,
  WITHDRAWAL_FEE_TYPE: true,
  WITHDRAWAL_LIST: true,
  WNT: true,
  GLV_LIST: true,
  GLV_PENDING_SHIFT: true,
  GLV_PENDING_SHIFT_BACKREF: true,
  GLV_SUPPORTED_MARKET_LIST: true,
};

export async function appendUintConfigIfDifferent(
  list: Array,
  dataCache: Map,
  baseKey: string,
  keyData: string,
  value: BigNumber | string | number,
  label?: string
) {
  await appendConfigIfDifferent(list, dataCache, "uint", baseKey, keyData, value, {
    compare: (a, b) => a.eq(b),
    label,
  });
}

export async function appendIntConfigIfDifferent(
  list: Array,
  dataCache: Map,
  baseKey: string,
  keyData: string,
  value: BigNumber | string | number,
  label?: string
) {
  await appendConfigIfDifferent(list, dataCache, "int", baseKey, keyData, value, {
    compare: (a, b) => a.eq(b),
    label,
  });
}

export async function appendAddressConfigIfDifferent(
  list: Array,
  dataCache: Map,
  baseKey: string,
  keyData: string,
  value: string,
  label?: string
) {
  await appendConfigIfDifferent(list, dataCache, "address", baseKey, keyData, value, {
    compare: (a, b) => a.toLowerCase() == b.toLowerCase(),
    label,
  });
}

export async function appendBytes32ConfigIfDifferent(
  list: Array,
  dataCache: Map,
  baseKey: string,
  keyData: string,
  value: string,
  label?: string
) {
  await appendConfigIfDifferent(list, dataCache, "bytes32", baseKey, keyData, value, { label });
}

export async function appendBoolConfigIfDifferent(
  list: Array,
  dataCache: Map,
  baseKey: string,
  keyData: string,
  value: boolean,
  label?: string
) {
  await appendConfigIfDifferent(list, dataCache, "bool", baseKey, keyData, value, { label });
}

async function appendConfigIfDifferent(
  list: Array,
  dataCache: Map,
  type: "uint" | "int" | "address" | "data" | "bool" | "bytes32",
  baseKey: string,
  keyData: string,
  value: any,
  { compare, label }: { compare?: (a: any, b: any) => boolean; label?: string } = {}
) {
  if (value === undefined) {
    throw new Error(`Value for ${label || key} of type ${type} is undefined`);
  }

  const config = await hre.ethers.getContract("Config");

  const key = getFullKey(baseKey, keyData);

  const setMethod = `set${type[0].toUpperCase()}${type.slice(1)}`;

  const currentValue: string = dataCache[key];
  if (currentValue === undefined) {
    throw new Error(`currentValue is undefined for ${label}`);
  }

  if (compare ? !compare(currentValue, value) : currentValue != value) {
    console.info(
      "appending config %s %s (%s) to %s, prev: %s (change %sx)",
      type,
      label,
      key,
      value.toString(),
      currentValue.toString(),
      (Number(value.toString()) / Number(currentValue.toString())).toFixed(4)
    );
    list.push(config.interface.encodeFunctionData(setMethod, [baseKey, keyData, value]));
  } else {
    console.info("skipping config %s %s (%s) as it is already set to %s", type, label, key, value.toString());
  }
}

export function getFullKey(baseKey: string, keyData: string) {
  if (keyData === "0x") {
    return baseKey;
  }

  const keyArray = ethers.utils.concat([ethers.utils.arrayify(baseKey), ethers.utils.arrayify(keyData)]);

  return ethers.utils.keccak256(keyArray);
}
