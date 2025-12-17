
## License

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)


# Project Overview
This project implements an IERC-721 compatible token collection using Solidity for smart contract logic, Chainlink VRF for generating the token rarity randomness and Foundry as framework for compiling, testing and deploying.


## Features

- Collection tokenomics fully customizable.
- Implements the IERC721 interface, ensuring compliance with the NFT standard for transfers, approvals, and ownership tracking.
- Implements Chainlink VRF for a trustful source of number randomness.
- Each token stores metadata, including token rarity. 
- Secure fund withdrawal restricted to contract owner.
- Includes unit tests covering both success and failure cases.
- Supports IERC721Receiver for safe contract-to-contract transfers.
- Includes a standard deploy script.
- JSONs and NFTs images are saved on IPFS network.


## Run Locally on WSL  (Windows Subsystem for Linux) <br>https://learn.microsoft.com/en-us/windows/wsl/install

Want to run this project? Make sure 

```bash
  git clone https://github.com/gabrieleMartignon/DnA-Collection-NFTs
```

Go to the project directory

```bash
  cd DnA-Collection-NFTs
```

Compile 

```bash
  forge compile
```

Test 

```bash
 forge test -vv
```

Start your local blockchain

```bash
anvil

```

Now you can deploy the project to your local simulated blockchain using the script included in the project
```bash
forge script script/NFT.s.sol --rpc-url 127.0.0.1:8545 --private-key <YOUR-PRIVATE-KEY> --broadcast

```



# Risks & Disclaimers
This project is a learning prototype. Do not deploy to mainnet with real funds without extensive auditing, tests, and legal review. Economic parameters are illustrative.
These tests and this contract are not intended to be production-ready.
## Tech Stack

- **Solidity** — [Docs](https://docs.soliditylang.org/en/v0.8.30/)
- **Foundry** — [Docs](https://getfoundry.sh/)
- **Chainlink VRF** — [Docs](https://docs.chain.link/vrf)

## Author

- [Gabriele Martignon](https://github.com/gabrieleMartignon)

## Contacts

**Gabriele Martignon** | Master in Blockchain Development | Blockchain & Web3 Developer  
- Personal Portfolio (in development): https://gabrielemartignon.github.io/  
- Email: gabrielemartignon@gmail.com  
- GitHub: https://github.com/gabrieleMartignon  
- LinkedIn: https://www.linkedin.com/in/gabrielemartignon
- Project Contract deployed on Sepolia : [https://sepolia.etherscan.io/address/0x93c3514f01f11f1729a8bbf341b79fd22e86f4f0](https://sepolia.etherscan.io/address/0x93c3514f01f11f1729a8bbf341b79fd22e86f4f0)
