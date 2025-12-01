export const MetaNodeStakeABI = [
  { "type": "function", "name": "poolLength", "inputs": [], "outputs": [{ "type": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "pool", "inputs": [{ "type": "uint256", "name": "pid" }], "outputs": [
    { "type": "address" },
    { "type": "uint256" },
    { "type": "uint256" },
    { "type": "uint256" },
    { "type": "uint256" },
    { "type": "uint256" },
    { "type": "uint256" }
  ], "stateMutability": "view" },
  { "type": "function", "name": "pendingMetaNode", "inputs": [{ "type": "uint256" }, { "type": "address" }], "outputs": [{ "type": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "stakingBalance", "inputs": [{ "type": "uint256" }, { "type": "address" }], "outputs": [{ "type": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "withdrawAmount", "inputs": [{ "type": "uint256" }, { "type": "address" }], "outputs": [{ "type": "uint256", "name": "requestAmount" }, { "type": "uint256", "name": "pendingWithdrawAmount" }], "stateMutability": "view" },
  { "type": "function", "name": "depositETH", "inputs": [{ "type": "uint256" }], "outputs": [], "stateMutability": "payable" },
  { "type": "function", "name": "deposit", "inputs": [{ "type": "uint256" }, { "type": "uint256" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "function", "name": "unStake", "inputs": [{ "type": "uint256" }, { "type": "uint256" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "function", "name": "withdraw", "inputs": [{ "type": "uint256" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "function", "name": "claim", "inputs": [{ "type": "uint256" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "function", "name": "user", "inputs": [{ "type": "uint256" }, { "type": "address" }], "outputs": [{ "type": "uint256", "name": "stAmount" }, { "type": "uint256", "name": "finishedMetaNode" }, { "type": "uint256", "name": "pendingMetaNode" }, { "type": "uint256", "name": "totalClaimed" }], "stateMutability": "view" },
  {
    "type": "event",
    "name": "Deposit",
    "inputs": [
      { "indexed": true, "name": "user", "type": "address" },
      { "indexed": true, "name": "pid", "type": "uint256" },
      { "indexed": false, "name": "amount", "type": "uint256" }
    ]
  },
  {
    "type": "event",
    "name": "RequestUnStake",
    "inputs": [
      { "indexed": true, "name": "user", "type": "address" },
      { "indexed": true, "name": "pid", "type": "uint256" },
      { "indexed": false, "name": "amount", "type": "uint256" }
    ]
  },
  {
    "type": "event",
    "name": "Withdraw",
    "inputs": [
      { "indexed": true, "name": "user", "type": "address" },
      { "indexed": true, "name": "pid", "type": "uint256" },
      { "indexed": false, "name": "amount", "type": "uint256" },
      { "indexed": false, "name": "blockNumber", "type": "uint256" }
    ]
  },
  {
    "type": "event",
    "name": "Claim",
    "inputs": [
      { "indexed": true, "name": "user", "type": "address" },
      { "indexed": true, "name": "pid", "type": "uint256" },
      { "indexed": false, "name": "amount", "type": "uint256" }
    ]
  }
]
