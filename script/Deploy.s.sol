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
    address feeReceiver = 0x2918F39540df38D4c33cda3bCA9edFccd8471cBE;
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 protocolFee = 500; // 5%
        uint256 flatFee = 0;

        vm.startBroadcast(deployerPrivateKey);
        LuckyBuy luckyBuy = new LuckyBuy(protocolFee, flatFee, feeReceiver);

        console.log(address(luckyBuy));

        vm.stopBroadcast();
    }
}

// deprecated
contract DeployOpenEdition is Script {
    address luckyBuy = 0x291b55444C1D4b1d945ebBb2D1547171d8324D78;

    function run() external {
        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //
        //vm.startBroadcast(deployerPrivateKey);
        //
        //OpenEdition openEditionToken = new OpenEdition();
        //
        //openEditionToken.mint(luckyBuy, 1, 1000 ether, "");
        //
        //vm.stopBroadcast();
    }
}

// deprecated
contract MintOpenEdition is Script {
    address luckyBuy = 0x291b55444C1D4b1d945ebBb2D1547171d8324D78;
    address openEditionToken = 0x3e988D49b3dE913FcE7D4ea0037919345ebDC3F8;

    function run() external {
        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //
        //vm.startBroadcast(deployerPrivateKey);
        //
        //OpenEdition(openEditionToken).mint(luckyBuy, 1, 1000 ether, "");
        //
        //vm.stopBroadcast();
    }
}

contract SetOpenEditionToken is Script {
    address payable luckyBuy =
<<<<<<< Updated upstream
        payable(0xE6b247ea4dD0C77A3EF8d99a30b4877a779e1c9C);
    address openEditionToken = 0x3e988D49b3dE913FcE7D4ea0037919345ebDC3F8;
=======
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);
    address openEditionToken = 0x4CB756f71A63785a40d2d2D5a7AE56caAb9f9BCa;
>>>>>>> Stashed changes
    uint256 tokenId = 0;
    uint32 amount = 1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).setOpenEditionToken(
            openEditionToken,
            tokenId,
            amount
        );

        vm.stopBroadcast();
    }
}

<<<<<<< Updated upstream
=======
contract SetFeeReceiverAddress is Script {
    address payable luckyBuy =
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);
    address feeReceiver = 0x2918F39540df38D4c33cda3bCA9edFccd8471cBE;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).setFeeReceiver(feeReceiver);

        vm.stopBroadcast();
    }
}

>>>>>>> Stashed changes
contract AddCosigner is Script {
    address payable luckyBuy =
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);
    address cosigner = 0x993f64E049F95d246dc7B0D196CB5dC419d4e1f1;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).addCosigner(cosigner);

        vm.stopBroadcast();
    }
}
contract setFlatFee is Script {
    address payable luckyBuy =
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);
    uint256 flatFee = 825000000000000;
    uint256 flatFeeHumanReadable = 0.000825 ether;

    function run() external {
        // sanity check
        assert(flatFeeHumanReadable == flatFee);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(luckyBuy).setFlatFee(flatFee);

        vm.stopBroadcast();
    }
}

// moves the OE from old LuckyBuy to new LuckyBuy
contract TransferOpenEditionContractOwnership is Script {
    address payable oldLuckyBuy =
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);
    address payable newLuckyBuy =
        payable(0x4CB756f71A63785a40d2d2D5a7AE56caAb9f9BCa);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LuckyBuy(oldLuckyBuy).transferOpenEditionContractOwnership(newLuckyBuy);

        vm.stopBroadcast();
    }
}

contract getLuckyBuy is Script {
    address payable luckyBuy =
        payable(0x291b55444C1D4b1d945ebBb2D1547171d8324D78);

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
