pragma solidity ^0.5.12;

interface CTokenI {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function getCash() external view returns (uint);
    function exchangeRateCurrent() external view returns (uint);
    function exchangeRateStored() external view returns (uint);
}