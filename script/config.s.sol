// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract ReservConfig {
  struct InterestRateStrategyParams {
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

  string[] public reserveSymbols;
  mapping(string => ReserveParams) public reserveParams;
  mapping(string => mapping(string => address)) public reserveAddresses;
  mapping(string => uint) public reservePrices;
  mapping(string => mapping(string => address)) public reserveOracles;

  function _init_symbols() internal {
    reserveSymbols.push("DAI");
    reserveSymbols.push("USDC");
    reserveSymbols.push("AAVE");
    reserveSymbols.push("WETH");
    reserveSymbols.push("LINK");
    reserveSymbols.push("WBTC");
    reserveSymbols.push("USDT");
    reserveSymbols.push("EURS");
  }

  function _init_reserve_addresses() internal {
    {
      reserveAddresses["DAI"]["main"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
      reserveAddresses["LINK"]["main"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
      reserveAddresses["USDC"]["main"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
      reserveAddresses["WBTC"]["main"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
      reserveAddresses["WETH"]["main"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
      reserveAddresses["USDT"]["main"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
      reserveAddresses["AAVE"]["main"] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
      reserveAddresses["EURS"]["main"] = 0xdB25f211AB05b1c97D595516F45794528a807ad8;
    }

    {
      reserveAddresses["DAI"]["arbitrum"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
      reserveAddresses["LINK"]["arbitrum"] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
      reserveAddresses["USDC"]["arbitrum"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
      reserveAddresses["WBTC"]["arbitrum"] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
      reserveAddresses["WETH"]["arbitrum"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
      reserveAddresses["USDT"]["arbitrum"] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
      reserveAddresses["AAVE"]["arbitrum"] = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
      reserveAddresses["EURS"]["arbitrum"] = 0xD22a58f79e9481D1a88e00c343885A588b34b68B;
    }

    {
      reserveAddresses["DAI"]["optimism"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
      reserveAddresses["LINK"]["optimism"] = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
      reserveAddresses["USDC"]["optimism"] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
      reserveAddresses["WBTC"]["optimism"] = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
      reserveAddresses["WETH"]["optimism"] = 0x4200000000000000000000000000000000000006;
      reserveAddresses["USDT"]["optimism"] = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
      reserveAddresses["AAVE"]["optimism"] = 0x76FB31fb4af56892A25e32cFC43De717950c9278;
      reserveAddresses["EURS"]["optimism"] = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    }
    {
      reserveAddresses["DAI"]["arbitrum-sepolia"] = 0x9714e454274dC66BE57FA8361233221a376f4C2e;
      reserveAddresses["LINK"]["arbitrum-sepolia"] = 0xaB7A6599C1804443C04c998D2be87Dc00A8c07bA;
      reserveAddresses["USDC"]["arbitrum-sepolia"] = 0x39E618D761fdD06bF65065d2974128aAeC7b3Fed;
      reserveAddresses["WBTC"]["arbitrum-sepolia"] = 0x4Ac0ED77C4375D48B51D56cc49b7710c3640b9c2;
      reserveAddresses["WETH"]["arbitrum-sepolia"] = 0xceBD1a3E9aaD7E60eDD509809e7f9cFF449b7851;
      reserveAddresses["USDT"]["arbitrum-sepolia"] = 0x0000000000000000000000000000000000000000;
      reserveAddresses["AAVE"]["arbitrum-sepolia"] = 0x0FDc113b620F994fa7FE03b7454193f519494D40;
      reserveAddresses["EURS"]["arbitrum-sepolia"] = 0x0000000000000000000000000000000000000000;
    }
  }

  function _init_reserve_oracles() internal {
    {
      reserveOracles["DAI"]["main"] = 0x773616E4d11A78F511299002da57A0a94577F1f4;
      reserveOracles["LINK"]["main"] = 0x396c5E36DD0a0F5a5D33dae44368D4193f69a1F0;
      reserveOracles["USDC"]["main"] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
      reserveOracles["WBTC"]["main"] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
      reserveOracles["WETH"]["main"] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
      reserveOracles["USDT"]["main"] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
      reserveOracles["AAVE"]["main"] = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;
      reserveOracles["EURS"]["main"] = 0x25Fa978ea1a7dc9bDc33a2959B9053EaE57169B5;
    }

    {
      reserveOracles["DAI"]["sepolia"] = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
      reserveOracles["LINK"]["sepolia"] = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
      reserveOracles["USDC"]["sepolia"] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
      reserveOracles["WBTC"]["sepolia"] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
      reserveOracles["WETH"]["sepolia"] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
      reserveOracles["USDT"]["sepolia"] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // ?  use usdc
      reserveOracles["AAVE"]["sepolia"] = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
      reserveOracles["EURS"]["sepolia"] = 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910;
    }

    {
      reserveOracles["DAI"]["arbitrum"] = 0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB;
      reserveOracles["LINK"]["arbitrum"] = 0x86E53CF1B870786351Da77A57575e79CB55812CB;
      reserveOracles["USDC"]["arbitrum"] = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
      reserveOracles["WBTC"]["arbitrum"] = 0x6ce185860a4963106506C203335A2910413708e9;
      reserveOracles["WETH"]["arbitrum"] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
      reserveOracles["USDT"]["arbitrum"] = 0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7;
      reserveOracles["AAVE"]["arbitrum"] = 0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034;
      reserveOracles["EURS"]["arbitrum"] = 0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84;
    }

    {
      reserveOracles["DAI"]["arbitrum-sepolia"] = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;
      reserveOracles["LINK"]["arbitrum-sepolia"] = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;
      reserveOracles["USDC"]["arbitrum-sepolia"] = 0x0153002d20B96532C639313c2d54c3dA09109309;
      reserveOracles["WBTC"]["arbitrum-sepolia"] = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
      reserveOracles["WETH"]["arbitrum-sepolia"] = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
      reserveOracles["USDT"]["arbitrum-sepolia"] = 0x80EDee6f667eCc9f63a0a6f55578F870651f06A4;
      reserveOracles["EURS"]["arbitrum-sepolia"] = 0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84;
    }
  }

  function _init_reserve_test_price() internal {
    reservePrices["DAI"] = 1e8;
    reservePrices["LINK"] = 30e8;
    reservePrices["USDC"] = 1e8;
    reservePrices["WBTC"] = 40000e8;
    reservePrices["WETH"] = 2000e8;
    reservePrices["USDT"] = 1e8;
    reservePrices["AAVE"] = 100e8;
    reservePrices["EURS"] = 1e8;
  }

  function _init_reserve_rate_strategies() internal {
    {
      rateStrategyStableOne = InterestRateStrategyParams({
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
    }
    {
      rateStrategyStableTwo = InterestRateStrategyParams({
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
    }
    {
      rateStrategyVolatileOne = InterestRateStrategyParams({
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
    }
  }

  function _init_reserve_strategy_dai() internal {
    reserveParams["DAI"] = ReserveParams({
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
  }

  function _init_reserve_strategy_usdc() internal {
    reserveParams["USDC"] = ReserveParams({
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
  }

  function _init_reserve_strategy_aave() internal {
    reserveParams["AAVE"] = ReserveParams({
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
  }

  function _init_reserve_strategy_weth() internal {
    reserveParams["WETH"] = ReserveParams({
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
  }

  function _init_reserve_strategy_link() internal {
    reserveParams["LINK"] = ReserveParams({
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
  }

  function _init_reserve_strategy_wbtc() internal {
    reserveParams["WBTC"] = ReserveParams({
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
  }

  function _init_reserve_strategy_usdt() internal {
    reserveParams["USDT"] = ReserveParams({
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
  }

  function _init_reserve_strategy_eurs() internal {
    reserveParams["EURS"] = ReserveParams({
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
  }

  function _init() internal {
    _init_symbols();
    _init_reserve_addresses();
    _init_reserve_oracles();
    _init_reserve_test_price();
    _init_reserve_rate_strategies();
    _init_reserve_strategy_dai();
    _init_reserve_strategy_usdc();
    _init_reserve_strategy_aave();
    _init_reserve_strategy_weth();
    _init_reserve_strategy_link();
    _init_reserve_strategy_wbtc();
    _init_reserve_strategy_usdt();
    _init_reserve_strategy_eurs();
  }

  function eqS(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }
}
