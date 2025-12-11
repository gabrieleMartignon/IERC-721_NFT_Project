// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {NFT} from "../src/NFT.sol";

contract NFT_Test is Script {
    NFT public nftContract;

    function run() public {
        vm.startBroadcast();

        nftContract = new NFT(
            "DnA collection",
            "DnA",
            0.01 ether,
            1000,
            0x5FbDB2315678afecb367f032d93F642f64180aa3,
            103879211952579031713867079929460612471442534541176311565333808004552223209919
        );

        vm.stopBroadcast();
    }
}
