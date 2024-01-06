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
import {ACLManager} from "@aave/core-v3/contracts/protocol/configuration/ACLManager.sol";
import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {EmissionManager} from "@aave/periphery-v3/contracts/rewards/EmissionManager.sol";
import {RewardsController} from "@aave/periphery-v3/contracts/rewards/RewardsController.sol";
import {PullRewardsTransferStrategy} from
  "@aave/periphery-v3/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {StakedTokenTransferStrategy} from
  "@aave/periphery-v3/contracts/rewards/transfer-strategies/StakedTokenTransferStrategy.sol";
import {InitializableImmutableAdminUpgradeabilityProxy} from
  "@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol";

import {ReservConfig} from "./config.s.sol";

contract CounterScript is Script, ReservConfig {
  PoolAddressesProviderRegistry public registry;
  InitializableAdminUpgradeabilityProxy public reserveProxy;
  InitializableAdminUpgradeabilityProxy public stakeProxy;
  PoolAddressesProvider addressProvider;
  WETH9Mocked public weth;
  L2Encoder l2Encoder;
  string market_name;
  string network;
  bool l2_suppored;

  function _before() internal {}

  function _after() internal {}

  function _deploy_marketRegistry(address deployer) internal {
    registry = new PoolAddressesProviderRegistry(deployer);
  }

  function _deploy_treasury(address deployer) internal {
    AaveEcosystemReserveV2 reserve = new AaveEcosystemReserveV2();
    AaveEcosystemReserveController controler = new AaveEcosystemReserveController(deployer);
    reserveProxy = new InitializableAdminUpgradeabilityProxy();
    reserveProxy.initialize(address(reserve), deployer, bytes(""));
    reserve.initialize(address(controler));
  }

  function _deploy_addresses_provider(address deployer) internal {
    provider = new PoolAddressesProvider(marketName, deployer);
    registry.registerAddressesProvider(address(provider), 1);
  }

  function _deploy_test_tokens(address deployer) internal {
    string memory NATIVE_TOKEN_SYMBOL = vm.envString("NATIVE_TOKEN_SYMBOL");
    for (uint i = 0; i < reserveSymbols.length; i++) {
      string memory symbol = reserveSymbols[i];
      address addr;
      if (symbol == NATIVE_TOKEN_SYMBOL) {
        weth = new WETH9Mocked();
        addr = address(weth);
      } else {
        MintableERC20 token = new MintableERC20(symbol, symbol, 18);
        addr = address(token);
      }
      console2.log("deployed token: ", symbol, addr);
      reserveAddresses[symbol]["test"] = addr;
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

  function _deploy_incenrives(address deployer) internal {
    EmissionManager mgr = new EmissionManager(deployer);
    RewardsController ctrl = new RewardsController();
    ctrl.initialize(address(0));
    bytes32 ctrl_hash = keccak256("INCENTIVES_CONTROLLER");
    address ctrlProxy = addressesProvider.getAddress(ctrl_hash);
    if (ctrlProxy == address(0)) {
      addressesProvider.setAddressAsProxy(ctrl_hash, address(ctrl));
    }
  }

  function _run(address deployer) internal {
    _deploy_marketRegistry(deployer);
    _deploy_treasury(deployer);
    _deploy_addresses_provider(deployer);
    if (network == "test") {
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
  }

  function run() public {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    market_name = vm.envString("MARKET");
    network = vm.envString("NETWORK");

    _before();

    vm.startBroadcast(deployer);

    _run(deployer);

    _after();

    vm.stopBroadcast();
  }
}
