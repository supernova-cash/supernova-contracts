pragma solidity ^0.6.0;

interface IPegPool {
    function release(uint256 amount) external;
}