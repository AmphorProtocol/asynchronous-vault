function getSwapTx(from, to, inToken, out, amount, slippage) {
  const tokens = process.env.ONEINCH_API_KEYS.split(",");
  const headers = {
    headers: {
      Authorization: `Bearer ${tokens[getRandomInt(tokens.length)]}`,
      accept: "application/json",
    },
  };
  const swpParams = {
    src: `0x${inToken}`,
    dst: `0x${out}`,
    amount: amount,
    from: `0x${from}`,
    receiver: `0x${to}`,
    slippage: Number(slippage) / 10000,
    disableEstimate: true,
    allowPartialFill: false,
  };

  const url = apiRequestUrl("/swap", swpParams);
  return fetch(url, headers);
}

function apiRequestUrl(methodName, queryParams) {
  const chainId = 1;
  const apiBaseUrl = "https://api.1inch.dev/swap/v5.2/" + chainId;

  return (
    apiBaseUrl + methodName + "?" + new URLSearchParams(queryParams).toString()
  );
}

function getRandomInt(max) {
  return Math.floor(Math.random() * max);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const from = BigInt(process.argv[2]).toString(16);
  const to = BigInt(process.argv[3]).toString(16);
  const inToken = BigInt(process.argv[4]).toString(16);
  const outToken = BigInt(process.argv[5]).toString(16);
  const amount = process.argv[6];
  const slippage = process.argv[7];
  await sleep(getRandomInt(10_000));
  getSwapTx(from, to, inToken, outToken, amount, slippage).then(async (res) => {
    const raw = await res.json();
    console.log(raw.tx.data);
  });
}

main();
