// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

interface IEACAggregatorProxy {
  function decimals() external view returns (uint8);

  function latestAnswer() external view returns (int);

  function latestTimestamp() external view returns (uint);

  function latestRound() external view returns (uint);

  function getAnswer(uint roundId) external view returns (int);

  function getTimestamp(uint roundId) external view returns (uint);

  event AnswerUpdated(int indexed current, uint indexed roundId, uint timestamp);
  event NewRound(uint indexed roundId, address indexed startedBy);
}
