// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Presale.sol";
import "../src/interfaces/IAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _dec;
    constructor(string memory n, string memory s, uint8 d) ERC20(n,s) { _dec = d; _mint(msg.sender, 100_000_000 * 1e18); }
    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function decimals() public view override returns (uint8) { return _dec; }
}

contract MockAggregator is IAggregator {
    int256 public price = 2000 * 1e8;
    function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80) { return (0,price,0,0,0); }
}

contract RevertingReceiver { 
    receive() external payable { revert(); } 
}

contract PresaleTest is Test {
    Presale public presale;
    MockERC20 public saleToken;
    MockERC20 public usdt;
    MockERC20 public usdc;
    MockAggregator public dataFeed;
    address fundsReceiver = makeAddr("fundsReceiver");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    uint256[3] phases_ = [uint256(1000000), uint256(500000), uint256(100000)];
    
    receive() external payable {}
    
    function setUp() public {
        saleToken = new MockERC20("Sale","SALE",18);
        usdt = new MockERC20("USDT","USDT",18);
        usdc = new MockERC20("USDC","USDC",6);
        dataFeed = new MockAggregator();
        presale = new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 3000000 * 1e18, block.timestamp, block.timestamp + 5000, phases_);
        saleToken.approve(address(presale), 3000000 * 1e18);
        presale.fundPresale(3000000 * 1e18);
        usdt.mint(user, 100000 * 1e18);
        usdc.mint(user, 100000 * 1e6);
        usdt.mint(user2, 100000 * 1e18);
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(presale), 1 ether);
    }
    
    function test_buyWithStable_USDT_18dec() public {
        vm.startPrank(user);
        usdt.approve(address(presale), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        vm.stopPrank();
    }
    
    function test_buyWithStable_USDC_6dec() public {
        vm.startPrank(user);
        usdc.approve(address(presale), 1000 * 1e6);
        presale.buyWithStable(address(usdc), 1000 * 1e6);
        vm.stopPrank();
    }
    
    function test_buyWithEther_success() public {
        vm.prank(user);
        presale.buyWithEther{value: 1 ether}();
    }
    
    function test_blacklist_and_remove() public {
        presale.blackList(user);
        vm.startPrank(user);
        usdt.approve(address(presale), 10 * 1e18);
        vm.expectRevert("User is blackListed");
        presale.buyWithStable(address(usdt), 10 * 1e18);
        vm.stopPrank();
        presale.removeBlacklist(user);
        vm.prank(user);
        presale.buyWithStable(address(usdt), 10 * 1e18);
    }
    
    function test_buyWithEther_blacklisted() public {
        presale.blackList(user);
        vm.prank(user);
        vm.expectRevert("User is blackListed");
        presale.buyWithEther{value: 1 ether}();
    }
    
    function test_revert_notStarted() public {
        Presale futurePresale = new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 3000000 * 1e18, block.timestamp + 1000, block.timestamp + 6000, phases_);
        vm.prank(user);
        vm.expectRevert("Presale not started yet");
        futurePresale.buyWithEther{value: 1 ether}();
    }
    
    function test_revert_incorrectToken() public {
        MockERC20 fake = new MockERC20("FAKE","FAKE",18);
        fake.mint(user, 100 * 1e18);
        vm.startPrank(user);
        fake.approve(address(presale), 10 * 1e18);
        vm.expectRevert("Incorrect token");
        presale.buyWithStable(address(fake), 10 * 1e18);
        vm.stopPrank();
    }
    
    function test_phaseIncrement() public {
        vm.startPrank(user);
        usdt.approve(address(presale), 2000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        vm.stopPrank();
    }
    
    function test_claim_success() public {
        vm.startPrank(user);
        usdt.approve(address(presale), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 6000);
        vm.prank(user);
        presale.claim();
    }
    
    function test_claim_revert_notEnded() public {
        vm.prank(user);
        vm.expectRevert("Presale not ended");
        presale.claim();
    }
    
    function test_getEtherPrice() public view {
        presale.getEtherPrice();
    }
    
    function test_emergencyWithdraws() public {
        presale.emergencyERC20Withdraw(address(saleToken), 100 * 1e18);
        presale.emergencyETHWithdraw();
    }
    
    function test_constructor_revert() public {
        vm.expectRevert("Incorrect Presale Times");
        new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 100, block.timestamp + 1000, block.timestamp, phases_);
    }
    
    function test_soldOut() public {
        Presale p = new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 1 * 1e18, block.timestamp, block.timestamp + 5000, phases_);
        saleToken.approve(address(p), 1 * 1e18);
        p.fundPresale(1 * 1e18);
        vm.startPrank(user);
        usdt.approve(address(p), 10 * 1e18);
        vm.expectRevert("sold out");
        p.buyWithStable(address(usdt), 10 * 1e18);
        vm.stopPrank();
    }
    
    function test_transferFailed() public {
        RevertingReceiver rev = new RevertingReceiver();
        Presale p = new Presale(address(saleToken), address(usdt), address(usdc), address(rev), address(dataFeed), 3000000 * 1e18, block.timestamp, block.timestamp + 5000, phases_);
        saleToken.approve(address(p), 3000000 * 1e18);
        p.fundPresale(3000000 * 1e18);
        vm.prank(user);
        vm.expectRevert("Transfer Failed");
        p.buyWithEther{value: 1 ether}();
    }

    function test_phaseIncrement_byTime() public {
        vm.warp(block.timestamp + 5000);
        vm.startPrank(user);
        usdt.approve(address(presale), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18); 
        vm.stopPrank();
        assertEq(presale.currentPhase(), 1);
    }

    function test_phaseIncrement_doesNothingIfPhaseIs2() public {
        vm.warp(block.timestamp + 5000);
        vm.startPrank(user);
        usdt.approve(address(presale), 3000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        assertEq(presale.currentPhase(), 2);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        vm.stopPrank();
        assertEq(presale.currentPhase(), 2);
    }

    function test_soldOut_WithEther() public {
        Presale p = new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 1, block.timestamp, block.timestamp + 5000, phases_);
        saleToken.approve(address(p), 1 * 1e18);
        p.fundPresale(1 * 1e18);
        vm.prank(user);
        vm.expectRevert("sold out");
        p.buyWithEther{value: 1 ether}();
    }

    function test_revert_presaleEnded() public {
        vm.warp(block.timestamp + 6000);
        vm.prank(user);
        vm.expectRevert("Presale not started yet");
        presale.buyWithEther{value: 1 ether}();
    }

    function test_phaseIncrement_byVolume() public {
        uint256[3] memory lowPhases = [uint256(500), uint256(500), uint256(500)];
        Presale p = new Presale(address(saleToken), address(usdt), address(usdc), fundsReceiver, address(dataFeed), 3000000 * 1e18, block.timestamp, block.timestamp + 5000, lowPhases);
        
        vm.startPrank(user);
        usdt.approve(address(p), 1000 * 1e18);
        p.buyWithStable(address(usdt), 1000 * 1e18);
        assertEq(p.currentPhase(), 1);
        vm.stopPrank();
    }
    
    function test_buyWithStable_USDC_RequireBranch() public {
        vm.startPrank(user);
        usdc.approve(address(presale), 10 * 1e6);
        presale.buyWithStable(address(usdc), 10 * 1e6);
        vm.stopPrank();
    }

        function test_buyWithStable_USDT_18dec_RequireBranch() public {
        vm.startPrank(user);
        usdt.approve(address(presale), 1000 * 1e18);
        presale.buyWithStable(address(usdt), 1000 * 1e18);
        vm.stopPrank();
    }

    function test_buyWithEther_RequireRevert_EndTime() public {
        vm.warp(block.timestamp + 5001);
        vm.prank(user);
        vm.expectRevert("Presale not started yet");
        presale.buyWithEther{value: 1 ether}();
    }
}