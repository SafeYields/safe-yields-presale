const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// Read and parse the file
const fileContent = fs.readFileSync("sayAirdrop.txt", "utf-8");
const lines = fileContent.trim().split("\n");

// Convert file data into whitelist
const whitelist = lines.map((line) => {
  const [address, amount] = line.split(/\s+/); // Split by whitespace or tabs
  const convertedAmount = BigInt(
    Math.round(parseFloat(amount) * 10 ** 18)
  ).toString(); // Convert to uint256 format

  return [address, convertedAmount];
});

// // (2)
const tree = StandardMerkleTree.of(whitelist, ["address", "uint256"]);

// Prepare output
let output = `Merkle Root: ${tree.root}\n\nEntries:\n`;

for (const [i, v] of tree.entries()) {
  const proof = tree.getProof(i);
  output += `Value: ${JSON.stringify(v)}\nProof: ${JSON.stringify(proof)}\n\n`;
}

// Write to output.txt
fs.writeFileSync("AirdropOutput.txt", output);
