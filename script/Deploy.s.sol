// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/LuckyBuy.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract OpenEdition is ERC1155 {
    constructor() ERC1155("") {}

    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public {
        _mint(to, id, value, data);
    }
}

contract DeployLuckyBuy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 protocolFee = 500; // 5%

        vm.startBroadcast(deployerPrivateKey);
        LuckyBuy luckyBuy = new LuckyBuy(protocolFee);

        console.log(address(luckyBuy));

        vm.stopBroadcast();
    }
}

contract DeployOpenEdition is Script {
    address luckyBuy = 0x088276f447Bd80882330E225a255930c201836C4;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OpenEdition openEditionToken = new OpenEdition();

        openEditionToken.mint(luckyBuy, 1, 1000 ether, "");

        vm.stopBroadcast();
    }
}

contract SetOpenEditionToken is Script {
    address payable luckyBuy =
        payable(0x088276f447Bd80882330E225a255930c201836C4);
    address openEditionToken = 0x62A3A7ebc812810f868ef52be81935147Ed9456c;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).setOpenEditionToken(openEditionToken, 1, 1);

        vm.stopBroadcast();
    }
}
