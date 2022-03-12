// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CurrencyConvert {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        priceFeed = AggregatorV3Interface(
            0x5498BB86BC934c8D34FDA08E81D444153d0D06aD
        );
    }

    function getCurrentPrice() public view returns (uint256) {
        (
            ,
            /*uint80 roundID*/
            int256 price,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function convertCurrency(uint256 price) public view returns (uint256) {
        uint256 currentPrice = getCurrentPrice();
        return price / currentPrice;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}