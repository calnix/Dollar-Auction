// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract DollarAuction {

    IERC20Token public token;

    address public seller;

    uint256 public minIncrement;
    uint256 public timeoutPeriod;
    uint256 public auctionEnd;

    address public topBidder;
    uint256 public topBid;

    address public secondBidder;
    uint256 public secondBid;

    // tracks participants' committed capital
    mapping(address => uint256) public balances;

    event Bid(address highBidder, uint256 highBid);

    constructor(IERC20Token _token,uint256 _minIncrement,uint256 _timeoutPeriod) {
        token = _token;
        minIncrement = _minIncrement;
        timeoutPeriod = _timeoutPeriod;

        seller = msg.sender;
        auctionEnd = now + timeoutPeriod;
        highBidder = seller;
    }

    // Users to bid in Eth
    function bid() external payable {
        require(block.timestamp < auctionEnd);
        require(msg.sender != topBidder);

        // check if valid bid value
        uint256 increase = msg.value - (topBid + minIncrement);
        require(increase > 0, "Invalid Bid");

        balances[msg.sender] += msg.value;

        // update second bid
        secondBid = topBid;
        secondBidder = topBidder;

        // update top bid
        topBid = msg.sender;
        topBidder += msg.value;

        // emit 
        emit Bid(topBidder, topBid);
    }

    // Users to withdraw committed bids
    // only if they not first or second
    function withdraw() external {
        require(block.timestamp > auctionEnd, "Auction active");

        require(msg.sender != topBidder);
        require(msg.sender != secondBidder);
        
        uint256 amount = balances[msg.sender];
        delete balances[msg.sender];

        msg.sender.transfer(amount);

        // emit
    }

    // Winner to claim prize
    function claim() external {
        require(block.timestamp > auctionEnd, "Auction active");
        require(msg.sender == topBidder);

        uint256 prize = token.balanceOf(this);
        require(token.transfer(highBidder, prize));
    }

    function dissolve() external only
}


// A dollar auction is a non-zero-sum sequential game where the highest bidder receives a dollar and the loser must pay the amount that they bid as well.
// The highest bidder receives the dollar bill and the loser must pay the amount that they bid as well.
