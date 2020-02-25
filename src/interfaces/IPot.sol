pragma solidity ^0.5.15;

interface IPot {
    function rho () external returns (uint256);
    function drip () external returns (uint256);
    function chi () external view returns (uint256);
}