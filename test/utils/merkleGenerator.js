const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const { ethers } = require("ethers");
const fs = require("fs");

const filePath = "airdrop.json"; // Ensure this file exists

// Read and parse the JSON file
const fileContent = fs.readFileSync(filePath, "utf-8");
const airdrop = JSON.parse(fileContent);

if (!Array.isArray(airdrop)) {
  throw new Error("Invalid JSON format: Expected an array");
}

// Convert airdrop data into whitelist format
const whitelist = airdrop.map(({ address, amount }) => {
  const normalizedAddress = ethers.getAddress(address); // Normalize the address
  const convertedAmount = ethers.parseEther(amount.toString()).toString(); // Convert ETH to wei

  return [normalizedAddress, convertedAmount];
});

// Ensure consistency by sorting
whitelist.sort((a, b) => a[0].localeCompare(b[0]));

// Create Merkle Tree
const tree = StandardMerkleTree.of(whitelist, ["address", "uint256"]);

console.log("Merkle Root:", tree.root);

// Prepare output
let output = `Merkle Root: ${tree.root}\n\nEntries:\n`;

for (const [i, v] of tree.entries()) {
  const proof = tree.getProof(i);
  output += `Value: ${JSON.stringify(v)}\nProof: ${JSON.stringify(proof)}\n\n`;
}

// Write output to file
fs.writeFileSync("AirdropOutput.txt", output);

console.log(
  "Merkle tree generated successfully! Output saved to AirdropOutput.txt."
);
