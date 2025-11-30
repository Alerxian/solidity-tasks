import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MetaNodeStakeModule", (m) => {
  const metaToken = m.contract("MockERC20", ["MetaNode", "META", 18], {
    id: "MetaToken",
  });
  const lpToken = m.contract("MockERC20", ["LP Token", "LPT", 18], {
    id: "LpToken",
  });
  const stake = m.contract("MetaNodeStake");

  const init = m.call(stake, "initialize", [
    metaToken,
    m.getParameter("metaNodePerBlock", 1000000000000000000n),
  ]);

  // First pool must be ETH pool (address(0))
  const addEthPool = m.call(
    stake,
    "addPool",
    [
      m.getParameter(
        "ethPoolToken",
        "0x0000000000000000000000000000000000000000"
      ),
      m.getParameter("ethPoolWeight", 100n),
      m.getParameter("ethMinDeposit", 100000000000000000n), // 0.1 ETH
      m.getParameter("ethLockedBlocks", 1000n),
    ],
    { id: "AddEthPool", after: [init] }
  );

  // Add LP Token pool
  m.call(
    stake,
    "addPool",
    [
      lpToken,
      m.getParameter("lpPoolWeight", 200n),
      m.getParameter("lpMinDeposit", 1000000000000000000n), // 1 LPT
      m.getParameter("lpLockedBlocks", 1000n),
    ],
    { id: "AddLpPool", after: [addEthPool] }
  );

  // Fund stake contract with rewards so claim can work
  m.call(
    metaToken,
    "mint",
    [stake, m.getParameter("initialRewards", 1000000000000000000000n)],
    { after: [addEthPool] }
  );

  return { metaToken, stake, lpToken };
});
