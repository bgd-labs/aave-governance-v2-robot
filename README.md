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

The keeper contracts are deployed and registered for ethereum and also for all L2 for cross-chain-governance proposals with the `GUARDIAN` as the owner and have the following functions:

- `checkUpKeep()`

  This is called off-chain by Chainlink every block to check if any action could be performed and if so calls `performUpKeep()`.
  It loops the last 25 proposals / actionsSetId and checks if any proposal / actionsSetId could be moved to `Queued`, `Executed` or `Canceled` State.
  If any action could be perfomed it checks 25 more proposals and so on to be confident.
  In case any actions could be performed it stores them in an array of struct `ActionWithId[]` which contain the id of proposal/actionsSet and the action to perform and returns true with the `ActionWithId[]` encoded in params.

- `performUpKeep()`

  This is called when `checkUpKeep()` returns true with the params containing ids and actions to perform.
  The `performUpKeep()` revalidates again if the actions could be performed.
  The actions are always executed in order from the first proposalId / actionsSetId to last.
  If any action could be performed it calls the governance contract / bridge executor to `execute()` `queue()` or `cancel()`.

  Note: A maximum of 25 actions are returned by `checkUpKeep()` to execute, if there are more actions they will be performed in the next block.

- `disableAutomation()`

  Called only by the owner which is initially set to the `GUARDIAN` to pause automation for a certain proposalId or actionsSetId.

# Deployment

1. [DeployEthRobotKeeper.s.sol](./scripts/DeployEthRobotKeeper.s.sol): Will deploy the Keeper contract for Ethereum and set the owner as `GUARDIAN`.
2. [DeployArbitrumRobotKeeper.s.sol](./scripts/DeployArbitrumRobotKeeper.s.sol): Will deploy the Keeper contract for Arbitrum and set the owner as `GUARDIAN`.
3. [DeployPolygonRobotKeeper.s.sol](./scripts/DeployPolygonRobotKeeper.s.sol): Will deploy the Keeper contract for Polygon and set the owner as `GUARDIAN`.

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
