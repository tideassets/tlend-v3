// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract ReservConfig {
  // export const rateStrategyVolatileOne: IInterestRateStrategyParams = {
  //   name: "rateStrategyVolatileOne",
  //   optimalUsageRatio: parseUnits("0.45", 27).toString(),
  //   baseVariableBorrowRate: "0",
  //   variableRateSlope1: parseUnits("0.07", 27).toString(),
  //   variableRateSlope2: parseUnits("3", 27).toString(),
  //   stableRateSlope1: parseUnits("0.07", 27).toString(),
  //   stableRateSlope2: parseUnits("3", 27).toString(),
  //   baseStableRateOffset: parseUnits("0.02", 27).toString(),
  //   stableRateExcessOffset: parseUnits("0.05", 27).toString(),
  //   optimalStableToTotalDebtRatio: parseUnits("0.2", 27).toString(),
  // };

  // export const rateStrategyStableOne: IInterestRateStrategyParams = {
  //   name: "rateStrategyStableOne",
  //   optimalUsageRatio: parseUnits("0.9", 27).toString(),
  //   baseVariableBorrowRate: parseUnits("0", 27).toString(),
  //   variableRateSlope1: parseUnits("0.04", 27).toString(),
  //   variableRateSlope2: parseUnits("0.6", 27).toString(),
  //   stableRateSlope1: parseUnits("0.005", 27).toString(),
  //   stableRateSlope2: parseUnits("0.6", 27).toString(),
  //   baseStableRateOffset: parseUnits("0.01", 27).toString(),
  //   stableRateExcessOffset: parseUnits("0.08", 27).toString(),
  //   optimalStableToTotalDebtRatio: parseUnits("0.2", 27).toString(),
  // };

  // export const rateStrategyStableTwo: IInterestRateStrategyParams = {
  //   name: "rateStrategyStableTwo",
  //   optimalUsageRatio: parseUnits("0.8", 27).toString(),
  //   baseVariableBorrowRate: parseUnits("0", 27).toString(),
  //   variableRateSlope1: parseUnits("0.04", 27).toString(),
  //   variableRateSlope2: parseUnits("0.75", 27).toString(),
  //   stableRateSlope1: parseUnits("0.005", 27).toString(),
  //   stableRateSlope2: parseUnits("0.75", 27).toString(),
  //   baseStableRateOffset: parseUnits("0.01", 27).toString(),
  //   stableRateExcessOffset: parseUnits("0.08", 27).toString(),
  //   optimalStableToTotalDebtRatio: parseUnits("0.2", 27).toString(),
  // };

  struct InterestRateStrategyParams {
    bytes32 name;
    uint optimalUsageRatio;
    uint baseVariableBorrowRate;
    uint variableRateSlope1;
    uint variableRateSlope2;
    uint stableRateSlope1;
    uint stableRateSlope2;
    uint baseStableRateOffset;
    uint stableRateExcessOffset;
    uint optimalStableToTotalDebtRatio;
  }

  InterestRateStrategyParams public rateStrategyVolatileOne;
  InterestRateStrategyParams public rateStrategyStableOne;
  InterestRateStrategyParams public rateStrategyStableTwo;

  struct ReserveParams {
    InterestRateStrategyParams strategy;
    uint baseLTVAsCollateral;
    uint liquidationThreshold;
    uint liquidationBonus;
    uint liquidationProtocolFee;
    bool borrowingEnabled;
    bool stableBorrowRateEnabled;
    bool flashLoanEnabled;
    uint reserveDecimals;
    bytes32 aTokenImpl;
    uint reserveFactor;
    uint supplyCap;
    uint borrowCap;
    uint debtCeiling;
    bool borrowableIsolation;
  }

  ReserveParams public strategyDAI;
  ReserveParams public strategyUSDC;
  ReserveParams public strategyAAVE;
  ReserveParams public strategyWETH;
  ReserveParams public strategyLINK;
  ReserveParams public strategyWBTC;
  ReserveParams public strategyUSDT;
  ReserveParams public strategyEURS;

  string[] public reserveSymbols = ["DAI", "USDC", "AAVE", "WETH", "LINK", "WBTC", "USDT", "EURS"];
  mapping(string => ReserveParams) public reserveParams;
  mapping(string => mapping(string => address)) public reserveAddresses;
  mapping(string => uint) public reservePrices;
  mapping(string => mapping(string => address)) public reserveOracles;

  // export const MOCK_CHAINLINK_AGGREGATORS_PRICES: { [key: string]: string } = {
  //   AAVE: parseUnits("300", 8).toString(),
  //   WETH: parseUnits("4000", 8).toString(),
  //   ETH: parseUnits("4000", 8).toString(),
  //   DAI: parseUnits("1", 8).toString(),
  //   USDC: parseUnits("1", 8).toString(),
  //   USDT: parseUnits("1", 8).toString(),
  //   WBTC: parseUnits("60000", 8).toString(),
  //   USD: parseUnits("1", 8).toString(),
  //   LINK: parseUnits("30", 8).toString(),
  //   CRV: parseUnits("6", 8).toString(),
  //   BAL: parseUnits("19.70", 8).toString(),
  //   REW: parseUnits("1", 8).toString(),
  //   EURS: parseUnits("1.126", 8).toString(),
  //   ONE: parseUnits("0.28", 8).toString(),
  //   WONE: parseUnits("0.28", 8).toString(),
  //   WAVAX: parseUnits("86.59", 8).toString(),
  //   WFTM: parseUnits("2.42", 8).toString(),
  //   WMATIC: parseUnits("1.40", 8).toString(),
  //   SUSD: parseUnits("1", 8).toString(),
  //   SUSHI: parseUnits("2.95", 8).toString(),
  //   GHST: parseUnits("2.95", 8).toString(),
  //   AGEUR: parseUnits("1.126", 8).toString(),
  //   JEUR: parseUnits("1.126", 8).toString(),
  //   DPI: parseUnits("149", 8).toString(),
  // };

  //   [eEthereumNetwork.main]: {
  //   DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
  //   LINK: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  //   USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  //   WBTC: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
  //   WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  //   USDT: "0xdac17f958d2ee523a2206206994597c13d831ec7",
  //   AAVE: "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
  //   EURS: "0xdb25f211ab05b1c97d595516f45794528a807ad8",
  // },
  //   [eArbitrumNetwork.arbitrum]: {
  //   DAI: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
  //   LINK: "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4",
  //   USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  //   WBTC: "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f",
  //   WETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  //   USDT: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
  //   AAVE: "0xba5DdD1f9d7F570dc94a51479a000E3BCE967196",
  //   EURS: "0xD22a58f79e9481D1a88e00c343885A588b34b68B",
  // },
  //   [eOptimismNetwork.main]: {
  //   DAI: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
  //   LINK: "0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6",
  //   USDC: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
  //   WBTC: "0x68f180fcCe6836688e9084f035309E29Bf0A2095",
  //   WETH: "0x4200000000000000000000000000000000000006",
  //   USDT: "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58",
  //   AAVE: "0x76FB31fb4af56892A25e32cFC43De717950c9278",
  //   SUSD: "0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9",
  // },

  function _init() internal {
    reserveAddresses["DAI"]["main"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    reserveAddresses["LINK"]["main"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    reserveAddresses["USDC"]["main"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    reserveAddresses["WBTC"]["main"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    reserveAddresses["WETH"]["main"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    reserveAddresses["USDT"]["main"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    reserveAddresses["AAVE"]["main"] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    reserveAddresses["EURS"]["main"] = 0xdB25f211AB05b1c97D595516F45794528a807ad8;
    reserveAddresses["DAI"]["arbitrum"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    reserveAddresses["LINK"]["arbitrum"] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    reserveAddresses["USDC"]["arbitrum"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    reserveAddresses["WBTC"]["arbitrum"] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    reserveAddresses["WETH"]["arbitrum"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    reserveAddresses["USDT"]["arbitrum"] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    reserveAddresses["AAVE"]["arbitrum"] = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
    reserveAddresses["EURS"]["arbitrum"] = 0xD22a58f79e9481D1a88e00c343885A588b34b68B;
    reserveAddresses["DAI"]["optimism"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    reserveAddresses["LINK"]["optimism"] = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    reserveAddresses["USDC"]["optimism"] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    reserveAddresses["WBTC"]["optimism"] = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    reserveAddresses["WETH"]["optimism"] = 0x4200000000000000000000000000000000000006;
    reserveAddresses["USDT"]["optimism"] = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    reserveAddresses["AAVE"]["optimism"] = 0x76FB31fb4af56892A25e32cFC43De717950c9278;
    reserveAddresses["EURS"]["optimism"] = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;

    reservePrices["DAI"] = 1e8;
    reservePrices["LINK"] = 30e8;
    reservePrices["USDC"] = 1e8;
    reservePrices["WBTC"] = 40000e8;
    reservePrices["WETH"] = 2000e8;
    reservePrices["USDT"] = 1e8;
    reservePrices["AAVE"] = 100e8;
    reservePrices["EURS"] = 1e8;

    rateStrategyStableOne = InterestRateStrategyParams({
      name: "rateStrategyStableOne",
      optimalUsageRatio: 0.9e27,
      baseVariableBorrowRate: 0,
      variableRateSlope1: 0.04e27,
      variableRateSlope2: 0.6e27,
      stableRateSlope1: 0.005e27,
      stableRateSlope2: 0.6e27,
      baseStableRateOffset: 0.01e27,
      stableRateExcessOffset: 0.08e27,
      optimalStableToTotalDebtRatio: 0.2e27
    });
    rateStrategyStableTwo = InterestRateStrategyParams({
      name: "rateStrategyStableTwo",
      optimalUsageRatio: 0.8e27,
      baseVariableBorrowRate: 0,
      variableRateSlope1: 0.04e27,
      variableRateSlope2: 0.75e27,
      stableRateSlope1: 0.005e27,
      stableRateSlope2: 0.75e27,
      baseStableRateOffset: 0.01e27,
      stableRateExcessOffset: 0.08e27,
      optimalStableToTotalDebtRatio: 0.2e27
    });
    rateStrategyVolatileOne = InterestRateStrategyParams({
      name: "rateStrategyVolatileOne",
      optimalUsageRatio: 0.45e27,
      baseVariableBorrowRate: 0,
      variableRateSlope1: 0.07e27,
      variableRateSlope2: 3e27,
      stableRateSlope1: 0.07e27,
      stableRateSlope2: 3e27,
      baseStableRateOffset: 0.02e27,
      stableRateExcessOffset: 0.05e27,
      optimalStableToTotalDebtRatio: 0.2e27
    });
    strategyDAI = ReserveParams({
      strategy: rateStrategyStableTwo,
      baseLTVAsCollateral: 7500,
      liquidationThreshold: 8000,
      liquidationBonus: 10500,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: true,
      flashLoanEnabled: true,
      reserveDecimals: 18,
      aTokenImpl: "AToken",
      reserveFactor: 1000,
      supplyCap: 2000000000,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: true
    });
    strategyUSDC = ReserveParams({
      strategy: rateStrategyStableOne,
      baseLTVAsCollateral: 8000,
      liquidationThreshold: 8500,
      liquidationBonus: 10500,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: true,
      flashLoanEnabled: true,
      reserveDecimals: 6,
      aTokenImpl: "AToken",
      reserveFactor: 1000,
      supplyCap: 2000000000,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: true
    });
    strategyAAVE = ReserveParams({
      strategy: rateStrategyVolatileOne,
      baseLTVAsCollateral: 5000,
      liquidationThreshold: 6500,
      liquidationBonus: 11000,
      liquidationProtocolFee: 1000,
      borrowingEnabled: false,
      stableBorrowRateEnabled: false,
      flashLoanEnabled: true,
      reserveDecimals: 18,
      aTokenImpl: "AToken",
      reserveFactor: 0,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: false
    });
    strategyWETH = ReserveParams({
      strategy: rateStrategyVolatileOne,
      baseLTVAsCollateral: 8000,
      liquidationThreshold: 8250,
      liquidationBonus: 10500,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: false,
      flashLoanEnabled: true,
      reserveDecimals: 18,
      aTokenImpl: "AToken",
      reserveFactor: 1000,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: false
    });
    strategyLINK = ReserveParams({
      strategy: rateStrategyVolatileOne,
      baseLTVAsCollateral: 7000,
      liquidationThreshold: 7500,
      liquidationBonus: 11000,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: false,
      flashLoanEnabled: true,
      reserveDecimals: 18,
      aTokenImpl: "AToken",
      reserveFactor: 2000,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: false
    });
    strategyWBTC = ReserveParams({
      strategy: rateStrategyVolatileOne,
      baseLTVAsCollateral: 7000,
      liquidationThreshold: 7500,
      liquidationBonus: 11000,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: false,
      flashLoanEnabled: true,
      reserveDecimals: 8,
      aTokenImpl: "AToken",
      reserveFactor: 2000,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      borrowableIsolation: false
    });
    strategyUSDT = ReserveParams({
      strategy: rateStrategyStableOne,
      baseLTVAsCollateral: 7500,
      liquidationThreshold: 8000,
      liquidationBonus: 10500,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: true,
      flashLoanEnabled: true,
      reserveDecimals: 6,
      aTokenImpl: "AToken",
      reserveFactor: 1000,
      supplyCap: 2000000000,
      borrowCap: 0,
      debtCeiling: 500000000,
      borrowableIsolation: true
    });
    strategyEURS = ReserveParams({
      strategy: rateStrategyStableOne,
      baseLTVAsCollateral: 6500,
      liquidationThreshold: 7000,
      liquidationBonus: 10750,
      liquidationProtocolFee: 1000,
      borrowingEnabled: true,
      stableBorrowRateEnabled: true,
      flashLoanEnabled: true,
      reserveDecimals: 2,
      aTokenImpl: "AToken",
      reserveFactor: 1000,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 500000000,
      borrowableIsolation: false
    });
    reserveParams["DAI"] = strategyDAI;
    reserveParams["USDC"] = strategyUSDC;
    reserveParams["AAVE"] = strategyAAVE;
    reserveParams["WETH"] = strategyWETH;
    reserveParams["LINK"] = strategyLINK;
    reserveParams["WBTC"] = strategyWBTC;
    reserveParams["USDT"] = strategyUSDT;
    reserveParams["EURS"] = strategyEURS;
  }

  // export const strategyDAI: IReserveParams = {
  //   strategy: rateStrategyStableTwo,
  //   baseLTVAsCollateral: "7500",
  //   liquidationThreshold: "8000",
  //   liquidationBonus: "10500",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: true,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "18",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "1000",
  //   supplyCap: "2000000000",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: true,
  // };

  // export const strategyUSDC: IReserveParams = {
  //   strategy: rateStrategyStableOne,
  //   baseLTVAsCollateral: "8000",
  //   liquidationThreshold: "8500",
  //   liquidationBonus: "10500",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: true,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "6",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "1000",
  //   supplyCap: "2000000000",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: true,
  // };

  // export const strategyAAVE: IReserveParams = {
  //   strategy: rateStrategyVolatileOne,
  //   baseLTVAsCollateral: "5000",
  //   liquidationThreshold: "6500",
  //   liquidationBonus: "11000",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: false,
  //   stableBorrowRateEnabled: false,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "18",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "0",
  //   supplyCap: "0",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: false,
  // };

  // export const strategyWETH: IReserveParams = {
  //   strategy: rateStrategyVolatileOne,
  //   baseLTVAsCollateral: "8000",
  //   liquidationThreshold: "8250",
  //   liquidationBonus: "10500",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: false,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "18",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "1000",
  //   supplyCap: "0",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: false,
  // };

  // export const strategyLINK: IReserveParams = {
  //   strategy: rateStrategyVolatileOne,
  //   baseLTVAsCollateral: "7000",
  //   liquidationThreshold: "7500",
  //   liquidationBonus: "11000",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: false,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "18",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "2000",
  //   supplyCap: "0",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: false,
  // };

  // export const strategyWBTC: IReserveParams = {
  //   strategy: rateStrategyVolatileOne,
  //   baseLTVAsCollateral: "7000",
  //   liquidationThreshold: "7500",
  //   liquidationBonus: "11000",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: false,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "8",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "2000",
  //   supplyCap: "0",
  //   borrowCap: "0",
  //   debtCeiling: "0",
  //   borrowableIsolation: false,
  // };

  // export const strategyUSDT: IReserveParams = {
  //   strategy: rateStrategyStableOne,
  //   baseLTVAsCollateral: "7500",
  //   liquidationThreshold: "8000",
  //   liquidationBonus: "10500",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: true,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "6",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "1000",
  //   supplyCap: "2000000000",
  //   borrowCap: "0",
  //   debtCeiling: "500000000",
  //   borrowableIsolation: true,
  // };

  // export const strategyEURS: IReserveParams = {
  //   strategy: rateStrategyStableOne,
  //   baseLTVAsCollateral: "6500",
  //   liquidationThreshold: "7000",
  //   liquidationBonus: "10750",
  //   liquidationProtocolFee: "1000",
  //   borrowingEnabled: true,
  //   stableBorrowRateEnabled: true,
  //   flashLoanEnabled: true,
  //   reserveDecimals: "2",
  //   aTokenImpl: eContractid.AToken,
  //   reserveFactor: "1000",
  //   supplyCap: "0",
  //   borrowCap: "0",
  //   debtCeiling: "500000000",
  //   borrowableIsolation: false,
  // }
}
