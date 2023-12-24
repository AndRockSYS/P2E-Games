// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {

    AggregatorV3Interface internal priceFeed;

    //API for specific network with specific currency exchange rate
    constructor() {
        priceFeed = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
    }
    //method returns id of current price round and the latest price of currency
    function getLatestPrice() external view returns (uint80, uint256) {
        (uint80 roundID, int256 price,/*uint256 startedAt*/,/*uint256 updatedAt*/,/*uint80 answeredInRound*/) = priceFeed.latestRoundData();
        return (roundID, uint256(price));
    }
}