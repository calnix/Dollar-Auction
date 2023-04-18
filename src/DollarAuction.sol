// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
@title Dollar Auction (ERC20 prize)
@author Calnix
@notice A dollar auction is a non-zero-sum sequential game where the highest bidder receives a dollar and the loser must pay the amount that they bid as well.
Everyone except topBid and secondBid will be able to claim back bids on auction end. topBid can claim prize.
@dev Prize is meant to be ERC20 token. This can be modified accordingly. 
*/

contract DollarAuction is Ownable {

    // auction prize
    IERC20 public immutable token;

    // auction properties 
    uint256 public immutable duration;
    uint256 public immutable auctionEnd;
    uint256 public immutable minIncrement;

    // highest bid
    address public topBidder;
    uint256 public topBid;
    
    // second highest bid
    address public secondBidder;
    uint256 public secondBid;

    // tracks participants' committed capital
    mapping(address => uint256) public balances;

    // events
    event Bid(address topBidder, uint256 topBid);
    event Withdraw(address withdrawer, uint256 amount);
    event Claim(address winner, uint256 amount);
    event Collect(address auctioneer, uint256 amount);

    // errors
    error InvalidBid(uint256 newBid);
    error TopBidder();
    error TopTwoBiddersCannotWithdraw();

    constructor(IERC20 token_, uint256 minIncrement_, uint256 duration_) {
        token = token_;
        minIncrement = minIncrement_;
        duration = duration_;

        auctionEnd = block.timestamp + duration;
    }

    ///@notice Users are to incrementally bid using Eth
    ///@dev msg.value = difference btw prior bid and target bid they wish to achieve
    function bid() external payable auctionActive {

        // cache storage variables - gas savings
        uint256 _topBid = topBid;
        address _topBidder = topBidder;

        if(msg.sender == _topBidder) revert TopBidder();

        // check if valid bid
        uint256 priorAmount = balances[msg.sender];
        uint256 newBid = priorAmount + msg.value;
        if(newBid < _topBid + minIncrement) {
            revert InvalidBid(newBid);
        }

        // update balances
        balances[msg.sender] += msg.value;

        // update second bid
        secondBid = _topBid;
        secondBidder = _topBidder;

        // update top bid
        topBid = newBid;
        topBidder = msg.sender;

        // emit 
        emit Bid(msg.sender, newBid);
    }

    ///@notice Users to withdraw committed Eth at Auction end
    function withdraw() external auctionEnded {
        
        if(msg.sender == topBidder || msg.sender == secondBidder) {
            revert TopTwoBiddersCannotWithdraw();
        }
       
        uint256 amount = balances[msg.sender];
        delete balances[msg.sender];

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // emit
        emit Withdraw(msg.sender, amount);
    }

    ///@notice Auction winner to claim prize
    function claim() external auctionEnded {
        require(msg.sender == topBidder, "Not winner");

        uint256 prize = token.balanceOf(address(this));
        require(token.transfer(topBidder, prize), "Transfer failed");

        //emit
        emit Claim(msg.sender, prize);
    }

    ///@notice Auction owner to claim topBid + secondBid
    function collect() external onlyOwner auctionEnded {
        uint256 amount = topBid + secondBid;
        
        // optional: can opt to retain values instead
        delete balances[topBidder];
        delete balances[secondBidder];

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        //emit
        emit Collect(msg.sender, amount);
    }   


    modifier auctionEnded() {
        require(block.timestamp > auctionEnd, "Auction active");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < auctionEnd, "Auction over");
        _;
    }

}


