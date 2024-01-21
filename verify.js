const fs = require("fs");
const path = require("path");
const { exec, execSync } = require("child_process");

// 获取命令行参数
const [, , jsonFilePath] = process.argv;

// 读取 JSON 文件
const data = fs.readFileSync(path.resolve(jsonFilePath), "utf8");

// 解析 JSON 数据
const jdata = JSON.parse(data);

// 过滤出所有的 "CREATE" 交易
const createTransactions = jdata.transactions.filter(
  (transaction) => transaction.transactionType === "CREATE"
);

// 将结果格式化为数组
const contracts = createTransactions.map((transaction) => ({
  name: transaction.contractName,
  addr: transaction.contractAddress,
  argv: transaction.arguments,
}));

// 解析 JSON 数据
// const contracts = JSON.parse(data);
function generateAbiEncodeCommand(argv) {
  const types = [];
  const values = [];

  argv.forEach((arg) => {
    if (arg.startsWith("[") && arg.endsWith("]")) {
      // This is an array argument
      const arrayArgs = arg.slice(1, -1).split(", ");
      types.push(getType(arrayArgs[0]).concat("[] memory"));
      values.push(`[${arrayArgs.join(",")}]`);
    } else {
      // This is a normal argument
      types.push(getType(arg));
      values.push(arg);
    }
  });

  return `"constructor(${types.join(",")})" ${values.join(" ")}`;
}

function getType(arg) {
  if (arg.length === 42) {
    return "address";
  } else if (arg.length > 42) {
    return "bytes";
  } else if (/^\d+$/.test(arg)) {
    return "uint256";
  } else {
    return "string";
  }
}

let ok = true;
// 循环处理每个合约
contracts.forEach((contract) => {
  // 构造命令
  let command = `forge verify-contract --verifier etherscan --verifier-url https://api-sepolia.arbiscan.io/api --watch --etherscan-api-key TK2UEC7AQT91SUIND9YVXMGJFDEQBXQKWR ${contract.addr} ${contract.name} --compiler-version "v0.8.23+commit.f704f362" --chain arbitrum-sepolia`;

  // 如果 argv 不是 null，就添加这个参数
  if (contract.argv !== null) {
    const abiEncodeCommand = generateAbiEncodeCommand(contract.argv);
    command += ` --constructor-args $(cast abi-encode ${abiEncodeCommand})`;
  }

  if (jdata.libraries !== null) {
    jdata.libraries.forEach((lib) => {
      command += ` --libraries "${lib}"`;
    });
  }

  // 执行命令
  // if (contract.name == "AaveOracle") {
  //   ok = false;
  // }
  // if (ok) {
  //   return;
  // }
  console.log(`${command}`);
  const output = execSync(command);
  console.log(`${output}`);

  execSync("sleep 1");
});
