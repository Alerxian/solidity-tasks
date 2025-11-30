export const ERC20ABI = [
  { "type": "function", "name": "decimals", "inputs": [], "outputs": [{ "type": "uint8" }], "stateMutability": "view" },
  { "type": "function", "name": "balanceOf", "inputs": [{ "type": "address" }], "outputs": [{ "type": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "allowance", "inputs": [{ "type": "address" }, { "type": "address" }], "outputs": [{ "type": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "approve", "inputs": [{ "type": "address" }, { "type": "uint256" }], "outputs": [{ "type": "bool" }], "stateMutability": "nonpayable" }
]
