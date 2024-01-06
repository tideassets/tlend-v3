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
import {StakedAave} from "@aave/stake-v2/contracts/stake/StakedAave.sol";
import {StakedAaveV2} from "@aave/stake-v2/contracts/stake/StakedAaveV2.sol";
import {StakedTokenV2Rev3} from
  "@aave/stake-v2/contracts/proposals/extend-stkaave-distribution/StakedTokenV2Rev3.sol";
import {MockAggregator} from "@aave/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import {Pool, IPool} from "@aave/core-v3/contracts/protocol/pool/Pool.sol";
import {L2Pool, IL2Pool} from "@aave/core-v3/contracts/protocol/pool/L2Pool.sol";
import {L2Encoder} from "@aave/core-v3/contracts/misc/L2Encoder.sol";
import {PoolConfigurator} from "@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol";
import {ReservesSetupHelper} from "@aave/core-v3/contracts/deployments/ReservesSetupHelper.sol";
import {ACLManager} from "@aave/core-v3/contracts/protocol/configuration/ACLManager.sol";
import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {EmissionManager} from "@aave/periphery-v3/contracts/rewards/EmissionManager.sol";
import {RewardsController} from "@aave/periphery-v3/contracts/rewards/RewardsController.sol";
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

import {ReservConfig} from "./config.s.sol";

contract CounterScript is Script, ReservConfig {
  string market_name;
  string network;
  bool l2_suppored;
  bool is_test;

  PoolAddressesProviderRegistry public registry;
  InitializableAdminUpgradeabilityProxy public treasuryProxy;
  InitializableAdminUpgradeabilityProxy public stakeProxy;
  PoolAddressesProvider addressProvider;
  ReservesSetupHelper helper;
  address public weth;
  L2Encoder l2Encoder;
  MockFlashLoanReceiver flashLoanReceiver;

  AToken public aToken;
  DelegationAwareAToken public dToken;
  StableDebtToken public sToken;
  VariableDebtToken public vToken;

  function _before() internal {
    _init();
  }

  function _after() internal {}

  function _deploy_marketRegistry(address deployer) internal {
    registry = new PoolAddressesProviderRegistry(deployer);
  }

  function _deploy_treasury(address deployer) internal {
    AaveEcosystemReserveV2 treasury = new AaveEcosystemReserveV2();
    AaveEcosystemReserveController treasury_controller =
      new AaveEcosystemReserveController(deployer);
    treasuryProxy = new InitializableAdminUpgradeabilityProxy();
    bytes memory data = abi.encodeWithSignature("initialize(address)", address(treasury_controller));
    treasuryProxy.initialize(address(treasury), deployer, data);
  }

  function _deploy_addresses_provider(address deployer) internal {
    addressProvider = new PoolAddressesProvider(market_name, deployer);
    registry.registerAddressesProvider(address(provider), 1);
    addressProvider.setMarketId(market_name);
    AaveProtocolDataProvider dataProvider = new AaveProtocolDataProvider(addressProvider);
    addressProvider.setPoolDataProvider(address(dataProvider));
  }

  function _deploy_test_tokens(address deployer) internal {
    string memory NATIVE_TOKEN_SYMBOL = vm.envString("NATIVE_TOKEN_SYMBOL");
    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      address addr;
      if (symbol == NATIVE_TOKEN_SYMBOL) {
        WETH9Mocked mweth = new WETH9Mocked();
        addr = address(mweth);
        weth = addr;
      } else {
        MintableERC20 token = new MintableERC20(symbol, symbol, 18);
        addr = address(token);
      }
      console2.log("deployed token: ", symbol, addr);
      reserveAddresses[symbol][network] = addr;
    }
    string[] memory rewardSymbols = ["stkAAVE", "REW"];
    for (uint i = 0; i < rewardSymbols.length; i++) {
      string memory symbol = rewardSymbols[i];
      MintableERC20 token = new MintableERC20(symbol, symbol, 18);
      console2.log("deployed reward token: ", symbol);
    }
    uint COOLDOWN_SECONDS = 3600;
    uint UNSTAKE_WINDOW = 1800;

    address token = reserveAddresses["AAVE"]["test"];
    uint distributionDruration = 3600 * 1000;
    StakedAave stakedAave =
    new StakedAave(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration);
    StakedAaveV2 stakedAaveV2 =
    new StakedAaveV2(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration, address(0));
    StakedTokenV2Rev3 stakedTokenV2Rev3 =
    new StakedTokenV2Rev3(token, token, COOLDOWN_SECONDS, UNSTAKE_WINDOW, deployer, deployer, distributionDruration, "Staked Aave", "stkAAVE", 18, address(0));

    if (address(stakeProxy) == address(0)) {
      stakeProxy = new InitializableAdminUpgradeabilityProxy();
    }
    InitializableAdminUpgradeabilityProxy proxy = stakeProxy;
    proxy.getImplementation();
    proxy.initialize(address(stakedAave), deployer, bytes(""));
    stakedAave.initialize(address(0), "Staked Aave", "stkAAVE", 18);
    bytes memory data = abi.encodeWithSignature("initialize()");
    proxy.upgradeToAndCall(address(stakedAaveV2), data);
    proxy.upgradeToAndCall(address(stakedTokenV2Rev3), data);
  }

  function _deploy_price_feeds(address) internal {
    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      uint price = reservePrices[symbol];
      MockAggregator aggregator = new MockAggregator(price);
      reserveOracles[symbol]["test"] = address(aggregator);
    }
  }

  function _deploy_pool(address) internal {
    Pool pool = new Pool(addressesProvider);
    addressesProvider.setPoolImpl(address(pool));
    Pool(addressProvider.getPool()).initialize(addressesProvider);
  }

  function _deploy_l2_pool(address) internal {
    L2Pool l2pool = new L2Pool(addressesProvider);
    addressesProvider.setPoolImpl(address(l2pool));
    address poolProxy = addressProvider.getPool();
    L2Pool(poolProxy).initialize(addressesProvider);
    l2Encoder = new L2Encoder(L2Pool(poolProxy));
  }

  function _deploy_pool_config(address) internal {
    PoolConfigurator configurator = new PoolConfigurator();
    addressesProvider.setPoolConfiguratorImpl(address(configurator));
    address configProxy = addressProvider.getPoolConfigurator();
    PoolConfigurator(configProxy).initialize(addressesProvider);
    PoolConfigurator(configProxy).updateFlashloanPremiumTotal(5);
    PoolConfigurator(configProxy).updateFlashloanPremiumToProtocol(4);
    helper = new ReservesSetupHelper();
  }

  function _deploy_acl(address deployer) internal {
    addressesProvider.setACLAdmin(deployer);
    ACLManager acl = new ACLManager(addressesProvider);
    addressesProvider.setACLManager(address(acl));
    acl.addPoolAdmin(deployer);
    acl.addEmergencyAdmin(deployer);
  }

  function _deploy_oracle(address deployer) internal {
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

  function _deploy_incentives(address deployer) internal {
    EmissionManager mgr = new EmissionManager(deployer);
    RewardsController ctrl = new RewardsController();
    ctrl.initialize(address(0));
    bytes32 ctrl_hash = keccak256("INCENTIVES_CONTROLLER");
    address ctrlProxy = addressesProvider.getAddress(ctrl_hash);
    if (ctrlProxy == address(0)) {
      addressesProvider.setAddressAsProxy(ctrl_hash, address(ctrl));
      ctrlProxy = addressesProvider.getAddress(ctrl_hash);
    }
    mgr.setRewardsController(ctrlProxy);
    RewardsController(ctrlProxy).initialize(address(mgr));
    PullRewardsTransferStrategy pullStrategy =
      new PullRewardsTransferStrategy(address(ctrlProxy), deployer, deployer);
  }

  function _deploy_token_impl(address deployer) internal {
    IPool pool = IPool(addressProvider.getPool());
    aToken = new AToken(pool);
    aToken.initialize(pool, address(0), address(0), address(0), 0, "ATOKEN_IMPL", "ATOKEN_IMPL", "");
    dToken = new DelegationAwareAToken(pool);
    dToken.initialize(
      pool,
      address(0),
      address(0),
      address(0),
      0,
      "DELEGATION_AWARE_ATOKEN_IMPL",
      "DELEGATION_AWARE_ATOKEN_IMPL",
      ""
    );
    sToken = new StableDebtToken(pool);
    sToken.initialize(
      pool,
      address(0),
      address(0),
      address(0),
      0,
      "STABLE_DEBT_TOKEN_IMPL",
      "STABLE_DEBT_TOKEN_IMPL",
      ""
    );
    vToken = new VariableDebtToken(pool);
    vToken.initialize(
      pool,
      address(0),
      address(0),
      address(0),
      0,
      "VARIABLE_DEBT_TOKEN_IMPL",
      "VARIABLE_DEBT_TOKEN_IMPL",
      ""
    );
  }

  function _deploy_init_reserves(address deployer) internal {
    IPool pool = IPool(addressProvider.getPool());
    DefaultReserveInterestRateStrateg strategy1 =
      new DefaultReserveInterestRateStrategy(addressProvider, rateStrategyStableOne);
    DefaultReserveInterestRateStrateg strategy2 =
      new DefaultReserveInterestRateStrategy(addressProvider, rateStrategyStableTwo);
    DefaultReserveInterestRateStrateg strategy3 =
      new DefaultReserveInterestRateStrategy(addressProvider, rateStrategyVolatileOne);

    uint len = reserveSymbols.length;
    ConfiguratorInputTypes.InitReserveInput[] memory inputs =
      new ConfiguratorInputTypes.InitReserveInput[](len);
    ReservesSetupHelper.ConfiguratorInputTypes[] memory helperInputs =
      new ReservesSetupHelper.ConfiguratorInputTypes[](len);
    for (uint i = 0; i < len; ++i) {
      string memory symbol = reserveSymbols[i];
      address asset = reserveAddresses[symbol][network];
      if (pool.getReserveData(asset) != address(0)) {
        continue;
      }

      DefaultReserveInterestRateStrateg strategy = strategy3;
      if (symbol == "USDC" || symbol == "USDT" || symbol == "ERRS") {
        strategy = strategy1;
      } else if (symbol == "DAI") {
        strategy = strategy2;
      }
      inputs[i] = ConfiguratorInputTypes.InitReserveInput({
        aTokenImpl: address(aToken),
        stableDebtTokenImpl: address(sToken),
        variableDebtTokenImpl: address(vToken),
        underlyingAssetDecimals: 18,
        interestRateStrategyAddress: address(strategy),
        underlyingAsset: asset,
        treasury: address(treasuryProxy),
        incentivesController: address(0),
        aTokenName: string(abi.encodePacked("Aave aToken ", symbol)),
        aTokenSymbol: string(abi.encodePacked("AAVE-aToken-", symbol)),
        variableDebtTokenName: string(abi.encodePacked("Aave variable debt ", symbol)),
        variableDebtTokenSymbol: string(abi.encodePacked("v", symbol)),
        stableDebtTokenName: string(abi.encodePacked("Aave stable debt ", symbol)),
        stableDebtTokenSymbol: string(abi.encodePacked("s", symbol)),
        params: "0x10"
      });
      reserveParams params = reserveParams[symbol];
      helperInputs[i] = ReservesSetupHelper.ConfiguratorInputTypes({
        asset: asset,
        baseLTV: params.baseLTV,
        liquidationThreshold: params.liquidationThreshold,
        liquidationBonus: params.liquidationBonus,
        reserveFactor: params.reserveFactor,
        borrowCap: params.borrowCap,
        supplyCap: params.supplyCap,
        stableBorrowingEnabled: params.stableBorrowingEnabled,
        borrowingEnabled: params.borrowingEnabled,
        flashLoanEnabled: params.flashLoanEnabled
      });
    }
    PoolConfigurator(addressProvider.getPoolConfigurator()).InitReserve(inputs);

    address aclMgr = addressProvider.getACLManager();
    ACLManager(aclMgr).addRiskAdmin(address(helper));
    helper.configureReserves(addressProvider.getPoolConfigurator(), helperInputs);
    ACLManager(aclMgr).removeRiskAdmin(address(helper));
  }

  function _deploy_init_periphery(address deployer) internal {
    flashLoanReceiver = new MockFlashLoanReceiver(addressProvider);
  }

  function _deploy_periphery_post(address deployer) internal {
    WrappedTokenGatewayV3 gateway =
      new WrappedTokenGatewayV3(weth, deployer, addressProvider.getPool());
    WalletBalanceProvider walletBalanceProvider = new WalletBalanceProvider();
    UiIncentiveDataProviderV3 incentiveDataProvider = new UiIncentiveDataProviderV3();
    UiPoolDataProviderV3 poolDataProvider = new UiPoolDataProviderV3(address(0), address(0));
    ParaSwapLiquiditySwapAdapter paraSwapLiquiditySwapAdapter =
      new ParaSwapLiquiditySwapAdapter(addressProvider);
    ParaSwapRepayAdapter paraSwapRepayAdapter = new ParaSwapRepayAdapter(addressProvider);
  }

  function _run(address deployer) internal {
    _deploy_marketRegistry(deployer);
    _deploy_treasury(deployer);
    _deploy_addresses_provider(deployer);
    if (is_test) {
      _deploy_test_tokens(deployer);
      _deploy_price_feeds(deployer);
    }
    _deploy_pool(deployer);
    if (l2_suppored) {
      _deploy_l2_pool(deployer);
    }
    _deploy_pool_config(deployer);
    _deploy_acl(deployer);
    _deploy_oracle(deployer);
    _deploy_incenrives(deployer);
    _deploy_token_impl(deployer);
    _deploy_init_reserves(deployer);
    _deploy_init_periphery(deployer);
    _deploy_periphery_post(deployer);
  }

  function run() public {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    market_name = vm.envString("MARKET");
    network = vm.envString("NETWORK");
    weth = vm.envString("WETH");
    is_test = vm.envBool("IS_TEST");
    l2_suppored = vm.envBool("L2_SUPPORTED");

    _before();

    vm.startBroadcast(deployer);

    _run(deployer);

    _after();

    vm.stopBroadcast();
  }
}
