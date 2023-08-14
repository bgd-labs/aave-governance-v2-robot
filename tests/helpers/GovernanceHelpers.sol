// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveGovernanceV2, AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {Vm} from 'forge-std/Vm.sol';

contract GovernanceHelpers {
  // creates a dummy proposal with the specified proposal state
  function createDummyProposal(
    Vm vm,
    IAaveGovernanceV2.ProposalState proposalState
  ) external returns (uint256) {
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    string[] memory signatures = new string[](1);
    bytes[] memory calldatas = new bytes[](1);
    bool[] memory withDelegatecalls = new bool[](1);

    targets[0] = address(1);
    // to create unique proposals we randomize the signature with block number
    signatures[0] = string(abi.encode(block.number));
    calldatas[0] = '';
    values[0] = 0;
    withDelegatecalls[0] = false;

    GovHelpers.SPropCreateParams memory createParams = GovHelpers.SPropCreateParams(
      AaveGovernanceV2.SHORT_EXECUTOR,
      targets,
      values,
      signatures,
      calldatas,
      withDelegatecalls,
      bytes32('ipfs')
    );

    uint256 proposalId = GovHelpers.createTestProposal(vm, createParams);

    if (proposalState == IAaveGovernanceV2.ProposalState.Succeeded) {
      GovHelpers.passVote(vm, proposalId);
    } else if (proposalState == IAaveGovernanceV2.ProposalState.Queued) {
      GovHelpers.passVoteAndQueue(vm, proposalId);
    } else if (proposalState == IAaveGovernanceV2.ProposalState.Executed) {
      GovHelpers.passVoteAndExecute(vm, proposalId);
    } else if (proposalState != IAaveGovernanceV2.ProposalState.Pending) {
      revert('Proposal State Not Supported to Create Proposal');
    }

    return proposalId;
  }
}
