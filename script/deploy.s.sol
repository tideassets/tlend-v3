// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PoolAddressesProviderRegistry} from
  "@aave/core-v3/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import {AaveEcosystemReserveV2} from
  "@aave/periphery-v3/contracts/treasury/AaveEcosystemReserveV2.sol";
import {AaveEcosystemReserveController} from
  "@aave/periphery-v3/contracts/treasury/AaveEcosystemReserveController.sol";
import {InitializableAdminUpgradeabilityProxy} from
  "@aave/core-v3/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import {PoolAddressesProvider} from
  "@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol";
import {AaveProtocolDataProvider} from "@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol";
import {WETH9Mocked} from "@aave/core-v3/contracts/mocks/tokens/WETH9Mocked.sol";
import {MintableERC20} from "@aave/core-v3/contracts/mocks/tokens/MintableERC20.sol";
// import {StakedAave} from "@aave/stake-v2/contracts/stake/StakedAave.sol";
// import {StakedAaveV2} from "@aave/stake-v2/contracts/stake/StakedAaveV2.sol";
// import {StakedTokenV2Rev3} from
//   "@aave/stake-v2/contracts/proposals/extend-stkaave-distribution/StakedTokenV2Rev3.sol";
import {MockAggregator} from "@aave/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import {Pool, IPool} from "@aave/core-v3/contracts/protocol/pool/Pool.sol";
import {L2Pool, IL2Pool} from "@aave/core-v3/contracts/protocol/pool/L2Pool.sol";
import {L2Encoder} from "@aave/core-v3/contracts/misc/L2Encoder.sol";
import {PoolConfigurator} from "@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol";
import {ReservesSetupHelper} from "@aave/core-v3/contracts/deployments/ReservesSetupHelper.sol";
import {ACLManager} from "@aave/core-v3/contracts/protocol/configuration/ACLManager.sol";
import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {EmissionManager} from "@aave/periphery-v3/contracts/rewards/EmissionManager.sol";
import {IAaveIncentivesController} from
  "@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol";
import {
  RewardsController,
  IRewardsController
} from "@aave/periphery-v3/contracts/rewards/RewardsController.sol";
import {PullRewardsTransferStrategy} from
  "@aave/periphery-v3/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {StakedTokenTransferStrategy} from
  "@aave/periphery-v3/contracts/rewards/transfer-strategies/StakedTokenTransferStrategy.sol";
import {AToken} from "@aave/core-v3/contracts/protocol/tokenization/AToken.sol";
import {DelegationAwareAToken} from
  "@aave/core-v3/contracts/protocol/tokenization/DelegationAwareAToken.sol";
import {StableDebtToken} from "@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol";
import {VariableDebtToken} from
  "@aave/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from
  "@aave/core-v3/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {ConfiguratorInputTypes} from
  "@aave/core-v3/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import {MockFlashLoanReceiver} from
  "@aave/core-v3/contracts/mocks/flashloan/MockFlashLoanReceiver.sol";
import {WrappedTokenGatewayV3} from "@aave/periphery-v3/contracts/misc/WrappedTokenGatewayV3.sol";
import {WalletBalanceProvider} from "@aave/periphery-v3/contracts/misc/WalletBalanceProvider.sol";
import {UiIncentiveDataProviderV3} from
  "@aave/periphery-v3/contracts/misc/UiIncentiveDataProviderV3.sol";
import {UiPoolDataProviderV3} from "@aave/periphery-v3/contracts/misc/UiPoolDataProviderV3.sol";
import {ParaSwapLiquiditySwapAdapter} from
  "@aave/periphery-v3/contracts/adapters/paraswap/ParaSwapLiquiditySwapAdapter.sol";
import {ParaSwapRepayAdapter} from
  "@aave/periphery-v3/contracts/adapters/paraswap/ParaSwapRepayAdapter.sol";
import {IEACAggregatorProxy} from
  "@aave/periphery-v3/contracts/misc/interfaces/IEACAggregatorProxy.sol";

import {ReservConfig} from "./config.s.sol";

contract DeployScript is Script, ReservConfig {
  address deployer;
  string market_name;
  string network;
  bool l2_suppored;
  bool is_test;
  address public weth;
  string native;

  PoolAddressesProviderRegistry public registry;
  InitializableAdminUpgradeabilityProxy public treasuryProxy;
  InitializableAdminUpgradeabilityProxy public stakeProxy;
  PoolAddressesProvider addressesProvider;
  ReservesSetupHelper helper;
  L2Encoder l2Encoder;
  MockFlashLoanReceiver flashLoanReceiver;
  WrappedTokenGatewayV3 gateway;
  WalletBalanceProvider walletBalanceProvider;
  UiIncentiveDataProviderV3 incentiveDataProvider;
  UiPoolDataProviderV3 poolDataProvider;

  AToken public aToken;
  DelegationAwareAToken public dToken;
  StableDebtToken public sToken;
  VariableDebtToken public vToken;

  function _before() internal {
    _init();
  }

  function _after() internal {}

  function _deploy_marketRegistry() internal {
    registry = new PoolAddressesProviderRegistry(deployer);
  }

  function _deploy_treasury() internal {
    AaveEcosystemReserveV2 treasury = new AaveEcosystemReserveV2();
    AaveEcosystemReserveController treasury_controller =
      new AaveEcosystemReserveController(deployer);
    treasuryProxy = new InitializableAdminUpgradeabilityProxy();
    bytes memory data = abi.encodeWithSignature("initialize()", address(treasury_controller));
    treasuryProxy.initialize(address(treasury), deployer, data);
  }

  function _deploy_addresses_provider() internal {
    addressesProvider = new PoolAddressesProvider(market_name, deployer);
    registry.registerAddressesProvider(address(addressesProvider), 1);
    addressesProvider.setMarketId(market_name);
    AaveProtocolDataProvider dataProvider = new AaveProtocolDataProvider(addressesProvider);
    addressesProvider.setPoolDataProvider(address(dataProvider));
  }

  function _deploy_test_tokens() internal {
    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      address addr;
      if (eqS(symbol, native)) {
        WETH9Mocked mweth = new WETH9Mocked();
        addr = address(mweth);
        weth = addr;
      } else {
        MintableERC20 token = new MintableERC20(string(bytes(symbol)), string(bytes(symbol)), 18);
        addr = address(token);
      }
      console2.log("deployed token: ", symbol, addr);
      reserveAddresses[symbol][network] = addr;
    }
  }

  function _deploy_stake() internal {
    // string[] memory rewardSymbols = ["stkAAVE", "REW"];
    // for (uint i = 0; i < rewardSymbols.length; i++) {
    //   string memory symbol = rewardSymbols[i];
    //   MintableERC20 token = new MintableERC20(symbol, symbol, 18);
    //   console2.log("deployed reward token: ", symbol);
    // }
    // uint COOLDOWN_SECONDS = 3600;
    // uint UNSTAKE_WINDOW = 1800;

    // address token = reserveAddresses["AAVE"][network];
    // uint distributionDruration = 3600 * 1000;
    // StakedAave stakedAave =
    // new StakedAave(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration);
    // StakedAaveV2 stakedAaveV2 =
    // new StakedAaveV2(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration, address(0));
    // StakedTokenV2Rev3 stakedTokenV2Rev3 =
    // new StakedTokenV2Rev3(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration, "Staked Aave", "stkAAVE", 18, address(0));

    // if (address(stakeProxy) == address(0)) {
    //   stakeProxy = new InitializableAdminUpgradeabilityProxy();
    // }
    // InitializableAdminUpgradeabilityProxy proxy = stakeProxy;
    // proxy.getImplementation();
    // proxy.initialize(address(stakedAave), deployer, bytes(""));
    // stakedAave.initialize(address(0), "Staked Aave", "stkAAVE", 18);
    // bytes memory data = abi.encodeWithSignature("initialize()");
    // proxy.upgradeToAndCall(address(stakedAaveV2), data);
    // proxy.upgradeToAndCall(address(stakedTokenV2Rev3), data);
  }

  function _deploy_price_feeds() internal {
    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      uint price = reservePrices[symbol];
      MockAggregator aggregator = new MockAggregator(int(price));
      reserveOracles[symbol]["test"] = address(aggregator);
    }
  }

  function _deploy_pool() internal {
    Pool pool = new Pool(addressesProvider);
    addressesProvider.setPoolImpl(address(pool));
    Pool(addressesProvider.getPool()).initialize(addressesProvider);
  }

  function _deploy_l2_pool() internal {
    L2Pool l2pool = new L2Pool(addressesProvider);
    addressesProvider.setPoolImpl(address(l2pool));
    address poolProxy = addressesProvider.getPool();
    L2Pool(poolProxy).initialize(addressesProvider);
    l2Encoder = new L2Encoder(L2Pool(poolProxy));
  }

  function _deploy_pool_config() internal {
    PoolConfigurator configurator = new PoolConfigurator();
    addressesProvider.setPoolConfiguratorImpl(address(configurator));
    address configProxy = addressesProvider.getPoolConfigurator();
    PoolConfigurator(configProxy).initialize(addressesProvider);
    PoolConfigurator(configProxy).updateFlashloanPremiumTotal(5);
    PoolConfigurator(configProxy).updateFlashloanPremiumToProtocol(4);
    helper = new ReservesSetupHelper();
  }

  function _deploy_acl() internal {
    addressesProvider.setACLAdmin(deployer);
    ACLManager acl = new ACLManager(addressesProvider);
    addressesProvider.setACLManager(address(acl));
    acl.addPoolAdmin(deployer);
    acl.addEmergencyAdmin(deployer);
  }

  function _deploy_oracle() internal {
    address[] memory assets = new address[](reserveSymbols.length);
    address[] memory oracles = new address[](reserveSymbols.length);

    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      assets[i] = reserveAddresses[symbol][network];
      oracles[i] = reserveOracles[symbol][network];
    }

    AaveOracle oracle =
      new AaveOracle(addressesProvider, assets, oracles, address(0), address(0), 8);
    addressesProvider.setPriceOracle(address(oracle));
  }

  function _deploy_incentives() internal {
    RewardsController ctrl = new RewardsController();
    EmissionManager mgr = new EmissionManager(address(ctrl), deployer);
    ctrl.initialize(address(0));
    bytes32 ctrl_hash = keccak256("INCENTIVES_CONTROLLER");
    address ctrlProxy = addressesProvider.getAddress(ctrl_hash);
    if (ctrlProxy == address(0)) {
      addressesProvider.setAddressAsProxy(ctrl_hash, address(ctrl));
      ctrlProxy = addressesProvider.getAddress(ctrl_hash);
    }
    mgr.setRewardsController(ctrlProxy);
    RewardsController(ctrlProxy).initialize(address(mgr));
    // PullRewardsTransferStrategy pullStrategy =
    new PullRewardsTransferStrategy(address(ctrlProxy), deployer, deployer);
  }

  function _new_aToken() internal {
    IPool pool = IPool(addressesProvider.getPool());
    aToken = new AToken(pool);
    aToken.initialize(
      pool,
      address(0),
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      "ATOKEN_IMPL",
      "ATOKEN_IMPL",
      ""
    );
  }

  function _new_delegation_aToken() internal {
    IPool pool = IPool(addressesProvider.getPool());
    dToken = new DelegationAwareAToken(pool);
    dToken.initialize(
      pool,
      address(0),
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      "DELEGATION_AWARE_ATOKEN_IMPL",
      "DELEGATION_AWARE_ATOKEN_IMPL",
      ""
    );
  }

  function _new_stable_debt_token() internal {
    IPool pool = IPool(addressesProvider.getPool());
    sToken = new StableDebtToken(pool);
    sToken.initialize(
      pool,
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      "STABLE_DEBT_TOKEN_IMPL",
      "STABLE_DEBT_TOKEN_IMPL",
      ""
    );
  }

  function _new_variable_debt_token() internal {
    IPool pool = IPool(addressesProvider.getPool());
    vToken = new VariableDebtToken(pool);
    vToken.initialize(
      pool,
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      "VARIABLE_DEBT_TOKEN_IMPL",
      "VARIABLE_DEBT_TOKEN_IMPL",
      ""
    );
  }

  function _deploy_token_impl() internal {
    _new_aToken();
    _new_delegation_aToken();
    _new_stable_debt_token();
    _new_variable_debt_token();
  }

  function _new_strategy1() internal returns (DefaultReserveInterestRateStrategy) {
    DefaultReserveInterestRateStrategy strategy1 = new DefaultReserveInterestRateStrategy(
      addressesProvider,
      rateStrategyStableOne.optimalUsageRatio,
      rateStrategyStableOne.baseVariableBorrowRate,
      rateStrategyStableOne.variableRateSlope1,
      rateStrategyStableOne.variableRateSlope2,
      rateStrategyStableOne.stableRateSlope1,
      rateStrategyStableOne.stableRateSlope2,
      rateStrategyStableOne.baseStableRateOffset,
      rateStrategyStableOne.stableRateExcessOffset,
      rateStrategyStableOne.optimalStableToTotalDebtRatio);
    return strategy1;
  }

  function _new_strategy2() internal returns (DefaultReserveInterestRateStrategy) {
    DefaultReserveInterestRateStrategy strategy2 = new DefaultReserveInterestRateStrategy(
      addressesProvider,
      rateStrategyStableTwo.optimalUsageRatio,
      rateStrategyStableTwo.baseVariableBorrowRate,
      rateStrategyStableTwo.variableRateSlope1,
      rateStrategyStableTwo.variableRateSlope2,
      rateStrategyStableTwo.stableRateSlope1,
      rateStrategyStableTwo.stableRateSlope2,
      rateStrategyStableTwo.baseStableRateOffset,
      rateStrategyStableTwo.stableRateExcessOffset,
      rateStrategyStableTwo.optimalStableToTotalDebtRatio);
    return strategy2;
  }

  function _new_strategy3() internal returns (DefaultReserveInterestRateStrategy) {
    DefaultReserveInterestRateStrategy strategy3 = new DefaultReserveInterestRateStrategy(
      addressesProvider,
      rateStrategyVolatileOne.optimalUsageRatio,
      rateStrategyVolatileOne.baseVariableBorrowRate,
      rateStrategyVolatileOne.variableRateSlope1,
      rateStrategyVolatileOne.variableRateSlope2,
      rateStrategyVolatileOne.stableRateSlope1,
      rateStrategyVolatileOne.stableRateSlope2,
      rateStrategyVolatileOne.baseStableRateOffset,
      rateStrategyVolatileOne.stableRateExcessOffset,
      rateStrategyVolatileOne.optimalStableToTotalDebtRatio);
    return strategy3;
  }

  function _init_config_input(address strategy, string memory symbol, address asset)
    internal
    view
    returns (ConfiguratorInputTypes.InitReserveInput memory)
  {
    ConfiguratorInputTypes.InitReserveInput memory input = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: address(aToken),
      stableDebtTokenImpl: address(sToken),
      variableDebtTokenImpl: address(vToken),
      underlyingAssetDecimals: 18,
      interestRateStrategyAddress: address(strategy),
      underlyingAsset: asset,
      treasury: address(treasuryProxy),
      incentivesController: addressesProvider.getAddress(keccak256("INCENTIVES_CONTROLLER")),
      aTokenName: string(abi.encodePacked("tlend aToken ", symbol)),
      aTokenSymbol: string(abi.encodePacked("a", symbol)),
      variableDebtTokenName: string(abi.encodePacked("tlend variable debt ", symbol)),
      variableDebtTokenSymbol: string(abi.encodePacked("v", symbol)),
      stableDebtTokenName: string(abi.encodePacked("tlend stable debt ", symbol)),
      stableDebtTokenSymbol: string(abi.encodePacked("s", symbol)),
      params: "0x10"
    });
    return input;
  }

  function _init_config() internal {
    DefaultReserveInterestRateStrategy strategy1 = _new_strategy1();
    DefaultReserveInterestRateStrategy strategy2 = _new_strategy2();
    DefaultReserveInterestRateStrategy strategy3 = _new_strategy3();

    IPool pool = IPool(addressesProvider.getPool());
    uint len = reserveSymbols.length;
    ConfiguratorInputTypes.InitReserveInput[] memory inputs =
      new ConfiguratorInputTypes.InitReserveInput[](len);
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      if (pool.getReserveData(asset).aTokenAddress != address(0)) {
        continue;
      }

      DefaultReserveInterestRateStrategy strategy = strategy3;
      if (eqS(symbol, "USDC") || eqS(symbol, "USDT") || eqS(symbol, "ERRS")) {
        strategy = strategy1;
      } else if (eqS(symbol, "DAI")) {
        strategy = strategy2;
      }
      inputs[i] = _init_config_input(address(strategy), symbol, asset);
    }
    PoolConfigurator(addressesProvider.getPoolConfigurator()).initReserves(inputs);
  }

  function _init_setup_helper() internal {
    uint len = reserveSymbols.length;
    ReservesSetupHelper.ConfigureReserveInput[] memory helperInputs =
      new ReservesSetupHelper.ConfigureReserveInput[](len);
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];

      ReserveParams memory params = reserveParams[symbol];
      helperInputs[i] = ReservesSetupHelper.ConfigureReserveInput({
        asset: asset,
        baseLTV: params.baseLTVAsCollateral,
        liquidationThreshold: params.liquidationThreshold,
        liquidationBonus: params.liquidationBonus,
        reserveFactor: params.reserveFactor,
        borrowCap: params.borrowCap,
        supplyCap: params.supplyCap,
        stableBorrowingEnabled: params.stableBorrowRateEnabled,
        borrowingEnabled: params.borrowingEnabled,
        flashLoanEnabled: params.flashLoanEnabled
      });
    }

    address aclMgr = addressesProvider.getACLManager();
    ACLManager(aclMgr).addRiskAdmin(address(helper));
    helper.configureReserves(
      PoolConfigurator(addressesProvider.getPoolConfigurator()), helperInputs
    );
    ACLManager(aclMgr).removeRiskAdmin(address(helper));
  }

  function _deploy_init_reserves() internal {
    _init_config();
    _init_setup_helper();
  }

  function _deploy_init_periphery() internal {
    if (is_test) {
      flashLoanReceiver = new MockFlashLoanReceiver(addressesProvider);
    }
  }

  function _deploy_periphery_post() internal {
    gateway = new WrappedTokenGatewayV3(weth, deployer, IPool(addressesProvider.getPool()));
    walletBalanceProvider = new WalletBalanceProvider();
    incentiveDataProvider = new UiIncentiveDataProviderV3();
    address eth_oracle = reserveOracles[native][network];
    poolDataProvider =
      new UiPoolDataProviderV3(IEACAggregatorProxy(eth_oracle), IEACAggregatorProxy(eth_oracle));
    // ParaSwapLiquiditySwapAdapter paraSwapLiquiditySwapAdapter =
    //   new ParaSwapLiquiditySwapAdapter(addressesProvider);
    // ParaSwapRepayAdapter paraSwapRepayAdapter = new ParaSwapRepayAdapter(addressesProvider);
  }

  function _deploy_setup_debt_ceiling() internal {
    PoolConfigurator configurator = PoolConfigurator(addressesProvider.getPoolConfigurator());
    uint len = reserveSymbols.length;
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      ReserveParams memory params = reserveParams[symbol];
      if (params.debtCeiling > 0) {
        configurator.setDebtCeiling(asset, params.debtCeiling);
      }
    }
  }

  function _deploy_setup_isomode() internal {
    PoolConfigurator configurator = PoolConfigurator(addressesProvider.getPoolConfigurator());
    uint len = reserveSymbols.length;
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      ReserveParams memory params = reserveParams[symbol];
      configurator.setBorrowableInIsolation(asset, params.borrowableIsolation);
    }
  }

  function _deploy_setup_emode() internal {
    PoolConfigurator configurator = PoolConfigurator(addressesProvider.getPoolConfigurator());
    address oracle = addressesProvider.getPriceOracle();
    configurator.setEModeCategory(1, 9700, 9750, 10100, oracle, "Stablecoins");
  }

  function _deploy_setup_liquidation_protocol_fee() internal {
    PoolConfigurator configurator = PoolConfigurator(addressesProvider.getPoolConfigurator());
    uint len = reserveSymbols.length;
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      ReserveParams memory params = reserveParams[symbol];
      configurator.setLiquidationProtocolFee(asset, params.liquidationProtocolFee);
    }
  }

  function _deploy_update_atoken() internal {
    AToken _aToken = new AToken(IPool(addressesProvider.getPool()));
    PoolConfigurator configurator = PoolConfigurator(addressesProvider.getPoolConfigurator());
    uint len = reserveSymbols.length;
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      ConfiguratorInputTypes.UpdateATokenInput memory input = ConfiguratorInputTypes
        .UpdateATokenInput({
        asset: asset,
        treasury: address(treasuryProxy),
        incentivesController: addressesProvider.getAddress(keccak256("INCENTIVES_CONTROLLER")),
        name: string(abi.encodePacked("tlend aToken ", symbol)),
        symbol: string(abi.encodePacked("a", symbol)),
        implementation: address(_aToken),
        params: "0x10"
      });
      configurator.updateAToken(input);
    }
  }

  function _deploy_aave() internal {
    _deploy_marketRegistry();
    _deploy_treasury();
    _deploy_addresses_provider();
    if (is_test) {
      _deploy_test_tokens();
      _deploy_price_feeds();
    }
    _deploy_pool();
    if (l2_suppored) {
      _deploy_l2_pool();
    }
    _deploy_pool_config();
    _deploy_acl();
    _deploy_oracle();
    _deploy_incentives();
    _deploy_token_impl();
    _deploy_init_reserves();
    _deploy_init_periphery();
    _deploy_periphery_post();
    _deploy_setup_debt_ceiling();
    _deploy_setup_isomode();
    _deploy_setup_emode();
    _deploy_setup_liquidation_protocol_fee();
    _deploy_update_atoken();
  }

  //////////////////////////////////////////////////////////////////////////
  ///  deploy tlen : zap, staker, stargate, leverage, liquidator, ...
  //////////////////////////////////////////////////////////////////////////

  function _deploy_zap() internal {
    // todo
  }
  function _deploy_staker() internal {}
  function _deploy_stargate() internal {}
  function _deploy_leverage() internal {}
  function _deploy_dlp() internal {}

  function _deploy_tlen() internal {
    _deploy_zap();
    _deploy_staker();
    _deploy_stargate();
    _deploy_leverage();
    _deploy_dlp();
  }

  function _run() internal {
    _deploy_aave();
    _deploy_tlen();
  }

  function run() public {
    deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    market_name = vm.envString("MARKET");
    network = vm.envString("NETWORK");
    weth = vm.envAddress("WETH");
    is_test = vm.envBool("TESTNET");
    l2_suppored = vm.envBool("L2_SUPPORTED");
    native = vm.envString("NATIVE");

    _before();

    vm.startBroadcast(deployer);

    _run();

    _after();

    vm.stopBroadcast();
  }
}
