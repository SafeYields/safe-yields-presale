const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");

// Whitelist with addresses and amounts (as strings)
const whitelist = [
  ["0x328809Bc894f92807417D2dAD6b7C998c1aFdac6", "1000000000000000000000"],
  ["0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e", "1000000000000000000000"],
  ["0xea475d60c118d7058beF4bDd9c32bA51139a74e0", "1000000000000000000000"],
];

// (2)
const tree = StandardMerkleTree.of(whitelist, ["address", "uint256"]);

// (3)
console.log("Merkle Root:", tree.root);

for (const [i, v] of tree.entries()) {
  // (3)
  const proof = tree.getProof(i);
  console.log("Value:", v);
  console.log("Proof:", proof);
}
