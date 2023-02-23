# Aave Governance Robot

Repository containing contracts for automating proposal actions for Governance V2 (currently) using Chainlink Automation.

### Keeper Contracts

The keeper contracts are deployed and registered for each network supported and have the following 2 functions:

- `checkUpKeep()`

  This is called off-chain by Chainlink to check if `performUpKeep()` needs to be called.
  It checks all the proposals whether it can be moved to `Queued`, `Executed` or `Canceled` State and returns true with the action to perform if so.

  Conditions required to move a proposal to `Queued` state:

  - If the current state of the proposal is `Succeeded`

  Conditions required to move a proposal to `Executed` state:

  - If the current state of the proposal is `Queued`
  - If block.timestamp >= exectionTime (executionTime is set during queue as block.timestamp + delay)

  Conditions required to move a proposal to `Canceled` state:

  - If the proposal is not already `Expired`, `Expired` or `Canceled`
  - If the proposition power of proposal creator is less than the minimum proposition power needed

    Note: Proposals represented by ActionSetsId on L2 can only be `Canceled` by guardian.

- `performUpKeep()`

  This is called when `checkUpKeep()` returns true and calls the governance contract / bridge executor to `execute()` or `queue()`

### Lifecycle of a proposal on ethereum ([reference](https://docs.aave.com/developers/guides/governance-guide/)):

Each proposal on ethereum is represented by `proposalId` and has the following states: `Pending`, `Canceled`, `Active`, `Failed`, `Succeeded`, `Queued`, `Expired`, `Executed`.

<img width="1468" alt="Screenshot 2023-02-20 at 11 35 57 AM" src="https://user-images.githubusercontent.com/22850280/220023358-26dcafca-1ced-4cfb-9423-481a0a52cd50.png">

### Lifecycle of a proposal on L2:

Each Cross chain proposal on the L2 is represented by its `ActionSetsId` and has the following states: `Queued`, `Executed`, `Canceled`, `Expired`.

Cross chain proposals after being `Executed` on ethereum are then relayed to the destination chain and are `Queued` automatically post which can be `Executed` by anyone.

<img width="1110" alt="Screenshot 2023-02-20 at 11 58 08 AM" src="https://user-images.githubusercontent.com/22850280/220028962-f0050e33-8731-48aa-b65c-0ff92cb60e7c.png">
