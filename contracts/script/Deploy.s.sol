// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {ShadowToken} from "../src/ShadowToken.sol";
import {Shadowlings} from "../src/Shadowlings.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        bytes32 salt = bytes32(uint256(0x5afe));
        address entryPoint = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;

        Shadowlings shadowlings = new Shadowlings{salt: salt}(entryPoint);
        console.log("Shadowlings:", address(shadowlings));

        ShadowToken token = new ShadowToken{salt: salt}();
        console.log("ShadowToken:", address(token));

        vm.stopBroadcast();
    }
}
