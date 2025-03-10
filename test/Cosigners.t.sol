// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/LuckyBuy.sol";

import "@openzeppelin/contracts/access/IAccessControl.sol";

contract LuckyBuyTest is Test {
    LuckyBuy public luckyBuy;
    address public admin = address(0x1);
    address public user = address(0x2);
    address public cosigner1 = address(0x3);
    address public cosigner2 = address(0x4);

    event CosignerAdded(address indexed cosigner);
    event CosignerRemoved(address indexed cosigner);

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new LuckyBuy();
        vm.stopPrank();
    }

    function testAddCosignerByAdmin() public {
        vm.startPrank(admin);

        vm.expectEmit(true, false, false, false);
        emit CosignerAdded(cosigner1);
        luckyBuy.addCosigner(cosigner1);

        assertTrue(luckyBuy.isCosigner(cosigner1), "Cosigner should be active");
        vm.stopPrank();
    }

    function testAddCosignerByNonAdmin() public {
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                0x00
            )
        );
        luckyBuy.addCosigner(cosigner1);

        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should not be active"
        );
        vm.stopPrank();
    }

    function testAddCosignerTwice() public {
        vm.startPrank(admin);
        luckyBuy.addCosigner(cosigner1);
        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be active after first addition"
        );

        vm.expectEmit(true, false, false, false);
        emit CosignerAdded(cosigner1);
        luckyBuy.addCosigner(cosigner1);

        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should remain active after second addition"
        );
        vm.stopPrank();
    }

    function testAddMultipleCosigners() public {
        vm.startPrank(admin);

        luckyBuy.addCosigner(cosigner1);

        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "First cosigner should be active"
        );
        assertFalse(
            luckyBuy.isCosigner(cosigner2),
            "Second cosigner should not be active yet"
        );

        luckyBuy.addCosigner(cosigner2);

        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "First cosigner should remain active"
        );
        assertTrue(
            luckyBuy.isCosigner(cosigner2),
            "Second cosigner should be active"
        );
        vm.stopPrank();
    }

    function testAddZeroAddressAsCosigner() public {
        vm.startPrank(admin);
        address zeroAddress = address(0);

        vm.expectEmit(true, false, false, false);
        emit CosignerAdded(zeroAddress);
        luckyBuy.addCosigner(zeroAddress);

        assertTrue(
            luckyBuy.isCosigner(zeroAddress),
            "Zero address should be active as cosigner"
        );
        vm.stopPrank();
    }

    function testRemoveCosignerByAdmin() public {
        vm.startPrank(admin);
        luckyBuy.addCosigner(cosigner1);
        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be active before removal"
        );

        vm.expectEmit(true, false, false, false);
        emit CosignerRemoved(cosigner1);
        luckyBuy.removeCosigner(cosigner1);

        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be inactive after removal"
        );
        vm.stopPrank();
    }

    function testRemoveCosignerByNonAdmin() public {
        vm.startPrank(admin);
        luckyBuy.addCosigner(cosigner1);
        vm.stopPrank();

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                0x00
            )
        );
        luckyBuy.removeCosigner(cosigner1);

        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should remain active"
        );
        vm.stopPrank();
    }

    function testRemoveNonExistentCosigner() public {
        vm.startPrank(admin);
        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should not be active initially"
        );

        vm.expectEmit(true, false, false, false);
        emit CosignerRemoved(cosigner1);
        luckyBuy.removeCosigner(cosigner1);

        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should remain inactive"
        );
        vm.stopPrank();
    }

    function testRemoveCosignerTwice() public {
        vm.startPrank(admin);
        luckyBuy.addCosigner(cosigner1);
        luckyBuy.removeCosigner(cosigner1);
        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be inactive after first removal"
        );

        vm.expectEmit(true, false, false, false);
        emit CosignerRemoved(cosigner1);
        luckyBuy.removeCosigner(cosigner1);

        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should remain inactive after second removal"
        );
        vm.stopPrank();
    }

    function testCosignerFunctionalityInCommit() public {
        vm.startPrank(admin);
        luckyBuy.addCosigner(cosigner1);
        vm.stopPrank();

        address receiver = address(0x5);
        uint256 seed = 123456;
        string memory orderHash = "testOrderHash";
        uint256 amount = 1 ether;

        vm.startPrank(user);
        vm.deal(user, amount);
        luckyBuy.commit{value: amount}(receiver, cosigner1, seed, orderHash);
        vm.stopPrank();

        vm.startPrank(admin);
        luckyBuy.removeCosigner(cosigner1);
        vm.stopPrank();

        vm.startPrank(user);
        vm.deal(user, amount);
        vm.expectRevert(LuckyBuy.InvalidCoSigner.selector);
        luckyBuy.commit{value: amount}(receiver, cosigner1, seed, orderHash);
        vm.stopPrank();
    }

    function testAddRemoveAddCosigner() public {
        vm.startPrank(admin);

        luckyBuy.addCosigner(cosigner1);
        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be active after addition"
        );

        luckyBuy.removeCosigner(cosigner1);
        assertFalse(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be inactive after removal"
        );

        luckyBuy.addCosigner(cosigner1);
        assertTrue(
            luckyBuy.isCosigner(cosigner1),
            "Cosigner should be active after re-addition"
        );
        vm.stopPrank();
    }
}
