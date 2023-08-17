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

    GovHelpers.Payload[] memory payloads = new GovHelpers.Payload[](1);
      payloads[0] = GovHelpers.Payload({
        target: address(1),
        // to create unique proposals we randomize the signature with block number
        signature: string(abi.encode(block.number)),
        callData: '',
        withDelegatecall: true,
        value: 0
      });

    uint256 proposalId = GovHelpers.createTestProposal(vm, payloads, AaveGovernanceV2.SHORT_EXECUTOR);

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
