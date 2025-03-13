const fs = require("fs");

function convertFileToJson(filePath, outputFilePath) {
  const data = fs.readFileSync(filePath, "utf8");
  const lines = data.trim().split("\n");

  const result = lines.map((line) => {
    const [address, amount] = line.split(/\s+/);
    return {
      address,
      amount: parseFloat(amount.replace(",", "")),
    };
  });

  fs.writeFileSync(outputFilePath, JSON.stringify(result, null, 2), "utf8");
}

const filePath = "sayAirdrop.txt"; // Replace with your file path
const outputFilePath = "output.json"; // Replace with desired output file path
convertFileToJson(filePath, outputFilePath);
console.log(`JSON data written to ${outputFilePath}`);
