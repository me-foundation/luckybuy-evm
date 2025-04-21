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
        LuckyBuy luckyBuy = new LuckyBuy(protocolFee, msg.sender);

        console.log(address(luckyBuy));

        vm.stopBroadcast();
    }
}

contract DeployOpenEdition is Script {
    address luckyBuy = 0x85d31445AF0b0fF26851bf3C5e27e90058Df3270;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OpenEdition openEditionToken = new OpenEdition();

        openEditionToken.mint(luckyBuy, 1, 1000 ether, "");

        vm.stopBroadcast();
    }
}

contract MintOpenEdition is Script {
    address luckyBuy = 0x85d31445AF0b0fF26851bf3C5e27e90058Df3270;
    address openEditionToken = 0x62A3A7ebc812810f868ef52be81935147Ed9456c;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OpenEdition(openEditionToken).mint(luckyBuy, 1, 1000 ether, "");

        vm.stopBroadcast();
    }
}

contract SetOpenEditionToken is Script {
    address payable luckyBuy =
        payable(0x85d31445AF0b0fF26851bf3C5e27e90058Df3270);
    address openEditionToken = 0x62A3A7ebc812810f868ef52be81935147Ed9456c;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).setOpenEditionToken(openEditionToken, 1, 1);

        vm.stopBroadcast();
    }
}

contract AddCosigner is Script {
    address payable luckyBuy =
        payable(0x85d31445AF0b0fF26851bf3C5e27e90058Df3270);
    address cosigner = 0x993f64E049F95d246dc7B0D196CB5dC419d4e1f1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).addCosigner(cosigner);

        vm.stopBroadcast();
    }
}

contract getLuckyBuy is Script {
    address payable luckyBuy =
        payable(0x85d31445AF0b0fF26851bf3C5e27e90058Df3270);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        (
            uint256 id,
            address receiver,
            address cosigner,
            uint256 seed,
            uint256 counter,
            bytes32 orderHash,
            uint256 amount,
            uint256 reward
        ) = LuckyBuy(luckyBuy).luckyBuys(0);
        console.log(id);
        console.log(receiver);
        console.log(cosigner);
        console.log(seed);
        console.log(counter);
        console.logBytes32(orderHash);
        console.log(amount);
        console.log(reward);

        console.log(LuckyBuy(luckyBuy).feesPaid(0));
        console.log(LuckyBuy(luckyBuy).protocolFee());

        console.log("########################");
        console.log(LuckyBuy(luckyBuy).treasuryBalance());
        console.log(LuckyBuy(luckyBuy).commitBalance());

        console.log(LuckyBuy(luckyBuy).protocolBalance());

        vm.stopBroadcast();
    }
}
