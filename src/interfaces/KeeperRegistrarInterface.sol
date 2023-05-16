// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface KeeperRegistrarInterface {
  struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    bytes checkData;
    bytes offchainConfig;
    uint96 amount;
  }

  function registerUpkeep(
    RegistrationParams calldata
  ) external returns (uint256);
}
