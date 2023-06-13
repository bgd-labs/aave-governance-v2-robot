# Aave Governance Robot

Repository containing contracts for automating governance actions for Aave Governance V2 and Aave Cross-Chain-Governance using Chainlink Automation.

The smart contracts performing automated actions on Governance V2 and Bridge Executors for cross-chain proposals are completely permissionless with the cost of running the keeper covered by the Aave DAO.

### Lifecycle of a proposal on ethereum ([reference](https://docs.aave.com/developers/guides/governance-guide/)):

Each proposal on ethereum is represented by `proposalId` and has the following states: `Pending`, `Canceled`, `Active`, `Failed`, `Succeeded`, `Queued`, `Expired`, `Executed`.

<img width="1366" alt="Screenshot 2023-03-03 at 2 59 45 PM" src="https://user-images.githubusercontent.com/22850280/222683940-19a2fd9e-7124-42cc-9651-25b7a567dea3.png">

Actions such as moving a proposal to `Queued`, `Executed` or `Canceled` state are public and is performed automatically by the keeper on the governance-v2 ethereum contract when the conditions are met.

Conditions required to move a proposal to `Queued` state:

- If the current state of the proposal is `Succeeded`

Conditions required to move a proposal to `Executed` state:

- If the current state of the proposal is `Queued`
- If block.timestamp >= exectionTime (executionTime is set during queue as block.timestamp + delay)

Conditions required to move a proposal to `Canceled` state:

- If the proposal is not already `Expired`, `Executed` or `Canceled`
- If the proposition power of proposal creator is less than the minimum proposition power needed

### Lifecycle of a proposal on L2:

Each Cross chain proposal on the L2 is represented by a `ActionSetsId` and has the following states: `Queued`, `Executed`, `Canceled`, `Expired`.

Cross chain proposals after being `Executed` on ethereum are then relayed to the destination chain and are `Queued` automatically.
Post the actionsSetId is moved to `Queued`, the action to move move the state to `Executed` is public and is called automatically by the keeper on the `BridgeExecutor` contract.

<img width="1223" alt="Screenshot 2023-03-03 at 3 02 22 PM" src="https://user-images.githubusercontent.com/22850280/222684555-912ca74b-f970-4e92-b1b4-ab99c8b680cb.png">

Conditions required to move a `ActionsSetId` to `Executed` state:

- If the current state of the `ActionsSetId` is `Queued`
- If block.timestamp >= exectionTime (executionTime is set during queue as block.timestamp + delay)

Note: `ActionSetsId` for cross-chain-governance can only be `Canceled` by `GUARDIAN`.

### Keeper Contracts

The keeper contracts are deployed and registered for ethereum and also for all L2's and have the following functions:

- `checkUpKeep()`

  This is called off-chain by Chainlink every block to check if any action could be performed and if so calls `performUpKeep()`.
  It loops the last `MAX_SKIP` number of proposals / actionsSetId and checks if any proposal / actionsSetId could be moved to `Queued`, `Executed` or `Canceled` State.
  If any action could be perfomed it checks `MAX_SKIP` more proposals / actionsSetId and so on to be confident.
  If any proposal / actionsSetId is disabled by the Aave CL Robot Operator, it skips it.
  In case any actions could be performed it stores them in an array of struct `ActionWithId[]` which contain the id of proposal/actionsSet and the action to perform and returns true with the `ActionWithId[]` encoded in params.

- `performUpKeep()`

  This is called when `checkUpKeep()` returns true with the params containing ids and actions to perform.
  The `performUpKeep()` revalidates again if the actions could be performed.
  The actions are always executed in order from the first proposalId / actionsSetId to last.
  If any action could be performed it calls the governance contract / bridge executor to `execute()` `queue()` or `cancel()`.

  Note: A maximum of 25 actions are returned by `checkUpKeep()` to execute, if there are more actions they will be performed in the next block.

### Aave CL Robot Operator

The contract to perform admin actions on the Aave Robot Keepers.

<img width="852" alt="Screenshot 2023-05-22 at 12 12 42 PM" src="https://github.com/bgd-labs/aave-governance-v2-robot/assets/22850280/91250424-c851-4d55-b5a4-75f4d1ae8395">

- `register()`

  Called by the funds admin of the Robot Operator to register the Chainlink Keeper.

- `cancel()`

  Called by the funds admin of the Robot Operator to cancel the Chainlink Keeper.

- `withdrawLink()`

  Called by the funds admin of the Robot Operator to withdraw link from the Chainlink Keeper. Note that we can only withdraw link after a keeper has been canceled and certain blocks have passed after being canceled.

- `setGasLimit()`

  Called by the maintenance admin or the funds admin to set the max gas limit for execution by the Chainlink Keeper.

- `toggleDisableAutomationById()`

  Called only by the maintenance admin or the funds admin to disable / enable automation for a certain proposalId or actionsSetId for a specific Chainlink Keeper.

# Deployment

1. [DeployEthereumPayload.s.sol](./scripts/DeployEthereumPayload.s.sol): Will deploy the Keeper contract, Operator Contract and the Proposal Payload for Ethereum.
2. [DeployArbitrumPayload.s.sol](./scripts/DeployArbitrumPayload.s.sol): Will deploy the Keeper contract, Operator Contract and the Proposal Payload for Arbitrum.
3. [DeployPolygonPayload.s.sol](./scripts/DeployPolygonPayload.s.sol): Will deploy the Keeper contract, Operator Contract and the Proposal Payload for Polygon.
4. [DeployOptimismPayload.s.sol](./scripts/DeployOptimismPayload.s.sol): Will deploy the Keeper contract, Operator Contract and the Proposal Payload for Optimism.

# Setup

This repo has forge dependencies. You will need to install foundry and run:

```
forge install
```

# Tests

To run the tests:

```
forge test
```
