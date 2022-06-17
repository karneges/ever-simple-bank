module.exports = {
  compiler: {
    // Specify path to your TON-Solidity-Compiler
    path: "/mnt/o/projects/broxus/TON-Solidity-Compiler/build/solc/solc",
  },
  linker: {
    // Path to your TVM Linker
    path: "/mnt/o/projects/broxus/TVM-linker/target/release/tvm_linker",
    lib: "/mnt/o/projects/broxus/TON-Solidity-Compiler/lib/stdlib_sol.tvm",
  },
  networks: {
    // You can use TON labs graphql endpoints or local node
    local: {
      ton_client: {
        // See the TON client specification for all available options
        network: {
          server_address: "http://localhost:5000",
        },
      },
      // This giver is default local-node giver
      giver: {
        address:
          "0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94",
        abi: {
          "ABI version": 1,
          functions: [
            { name: "constructor", inputs: [], outputs: [] },
            {
              name: "sendGrams",
              inputs: [
                { name: "dest", type: "address" },
                { name: "amount", type: "uint64" },
              ],
              outputs: [],
            },
          ],
          events: [],
          data: [],
        },
        key: "",
      },
      // Use tonos-cli to generate your phrase
      // !!! Never commit it in your repos !!!
      keys: {
        phrase:
          "room steel rival siren ocean pen choose pause balance electric vacant enroll",
        amount: 20,
      },
    },
  },
};
