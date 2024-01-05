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
import {WETH9Mocked} from
  "@aave/core-v3/contracts/mocks/tokens/WETH9Mocked.sol";
import {MintableERC20} from
  "@aave/core-v3/contracts/mocks/tokens/MintableERC20.sol";

contract CounterScript is Script {
  PoolAddressesProviderRegistry public registry;
  InitializableAdminUpgradeabilityProxy public reserveProxy;

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
    PoolAddressesProvider provider = new PoolAddressesProvider("AAVE Market", deployer);
    registry.registerAddressesProvider(address(provider), 1);
  }

  function _deploy_test_tokens(address deployer) internal {
    bool isTestnet = vm.envBool("IS_TESTNET");
    if (!isTestnet) {
      return;
    }
    WETH9Mocked weth = new WETH9Mocked();
    MintableERC20 dai = new MintableERC20("DAI", "DAI", 18);

    InitializableAdminUpgradeabilityProxy proxy = new InitializableAdminUpgradeabilityProxy();


  }

  function _run(address deployer) internal {
    _deploy_marketRegistry(deployer);
    _deploy_treasury(deployer);
    _deploy_addresses_provider(deployer);
  }

  function run() public {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    _before();

    vm.startBroadcast(deployer);

    _run(deployer);

    _after();

    vm.stopBroadcast();
  }
}
