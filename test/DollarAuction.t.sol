// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DollarAuction.sol";

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

abstract contract StateZero is Test {
    
    DollarAuction public dollarAuction;
    ERC20Mock public mockToken;

    IERC20 public token;
    uint256 public minIncrement = 1 ether;
    uint256 public duration =  3600;   // 1 hour
    uint256 prize = 10 ether;

    address user1;
    address user2;
    address user3;
    address deployer;


    function setUp() public virtual {

        user1 = address(1);
        vm.label(user1, "user1");

        user2 = address(2);
        vm.label(user2, "user2");
        
        user3 = address(3);
        vm.label(user3, "user3");

        deployer = address(789);
        vm.label(deployer, "deployer");

        vm.startPrank(deployer);

        mockToken = new ERC20Mock("token", "txt", address(1), 0);
        vm.label(address(mockToken), "mockToken");

        dollarAuction = new DollarAuction(IERC20(mockToken), minIncrement, duration);
        vm.label(address(dollarAuction), "dollarAuction");

        mockToken.mint(address(dollarAuction), prize);

        vm.stopPrank();
    } 
}


contract StateZeroTest is StateZero { 
    // Note: Auction has started

    function testCannotCollect(uint amount) public {
        console2.log("No collecting before Auction end");
        
        vm.expectRevert("Auction active");

        vm.prank(deployer);
        dollarAuction.collect();

    }

    function testCannotClaim() public {
        console2.log("No claims before Auction end");

        vm.expectRevert("Auction active");

        vm.prank(user1);
        dollarAuction.claim();
    }

    function testBid() public{
        console2.log("Bidding should be possible");
        vm.deal(user1, 5 ether);
        vm.deal(user2, 5 ether);

        vm.prank(user1);
        dollarAuction.bid{value: 1 ether}();

        vm.prank(user2);
        dollarAuction.bid{value: 2 ether}();

        assertTrue(dollarAuction.balances(user1) == 1 ether);
        assertTrue(dollarAuction.balances(user2) == 2 ether);
        assertTrue(address(dollarAuction).balance == 3 ether);
    } 

}


abstract contract StateBid is StateZero {   
    
    function setUp() public override virtual {
        super.setUp();

        vm.deal(user1, 20 ether);
        vm.deal(user2, 20 ether);
        vm.deal(user3, 20 ether);

    }

}

contract StateBidTest is StateBid{
  
    function testCannotWithdraw() public{
        console2.log("No withdrawals before Auction end");

        vm.prank(user1);
        dollarAuction.bid{value: 1 ether}();

        vm.expectRevert("Auction active");

        vm.prank(user1);
        dollarAuction.withdraw();
    }

    function testIncrementingBids() public {

        vm.prank(user1);
        dollarAuction.bid{value: 1 ether}();

        assertTrue(dollarAuction.topBid() == 1 ether);
        assertTrue(dollarAuction.secondBid() == 0);

        vm.prank(user2);
        dollarAuction.bid{value: 2 ether}();

        assertTrue(dollarAuction.topBid() == 2 ether); 
        assertTrue(dollarAuction.secondBid() == 1 ether);

        vm.prank(user3);
        dollarAuction.bid{value: 4 ether}();

        assertTrue(dollarAuction.topBid() == 4 ether); 
        assertTrue(dollarAuction.secondBid() == 2 ether);

    }
}


abstract contract StateEnded is StateBid {
    function setUp() public override virtual {
        super.setUp();
        vm.prank(user1);
        dollarAuction.bid{value: 1 ether}();

        vm.prank(user2);
        dollarAuction.bid{value: 2 ether}();

        vm.prank(user3);
        dollarAuction.bid{value: 4 ether}();

        vm.warp(block.timestamp + 36000);
    }

}   

contract StateEndedTest is StateEnded {
    // Note: Auction has ended

    function testCannotBid() public {
        console2.log("Bidding should not be possible");

        uint256 amount = dollarAuction.topBid() + dollarAuction.minIncrement();

        vm.expectRevert("Auction over");

        vm.prank(user1);
        dollarAuction.bid{value: amount}();
    }

    function testWithdraw() public {
        console2.log("can withdraw if not top 2 bids");

        vm.prank(user1);
        dollarAuction.withdraw();

        assertTrue(dollarAuction.balances(user1) == 0 ether);
        assertTrue(address(user1).balance == 20 ether);
    }

    function testCollect() public {
        console2.log("auctioneer can collect top two bids");

        uint256 amount = dollarAuction.topBid() + dollarAuction.secondBid();

        console2.log(address(dollarAuction).balance);

        vm.prank(deployer);
        dollarAuction.collect();

        assertTrue(address(deployer).balance == amount);
    }

    function testClaim() public {
        console2.log("winner winner chicken dinner");

        console2.log(dollarAuction.topBidder());

        vm.prank(dollarAuction.topBidder());
        dollarAuction.claim();

        assertTrue(mockToken.balanceOf(dollarAuction.topBidder()) == prize);
        assertTrue(mockToken.balanceOf(address(dollarAuction)) == 0);

    }
}

