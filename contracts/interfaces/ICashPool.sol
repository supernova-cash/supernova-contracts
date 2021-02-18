pragma solidity ^0.6.0;

interface ICashPool {
    function release(uint256 amount) external;
}