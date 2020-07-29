// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


pragma solidity ^0.5.0;

interface ILoihi {

    function originSwap (
        address _origin,
        address _target,
        uint _originAmount,
        uint _minTargetAmount,
        uint _deadline
    ) external returns (
        uint
    );

    function originSwapTo (
        address _origin,
        address _target,
        uint _originAmount,
        uint _minTargetAmount,
        uint _deadline,
        address _recipient
    ) external returns (
        uint targetAmount_
    );

    function viewOriginSwap (
        address _origin,
        address _target,
        uint _originAmount
    ) external view returns (
        uint targetAmount_
    );

    function targetSwap (
        address _origin,
        address _target,
        uint _targetAmount,
        uint _maxOriginAmount,
        uint _deadline
    ) external returns (
        uint originAmount_
    );

    function tansferByTarget (
        address _origin,
        address _target,
        uint _targetAmount,
        uint _maxOriginAmount,
        address _recipient,
        uint _deadline
    ) external returns (
        uint originAmount_
    );

    function viewTargetSwap (
        address _origin,
        address _target,
        uint _targetAmount
    ) external view returns (
        uint originAmount_
    );

    function proportionalDeposit (
        uint _totalStablecoins,
        uint _deadline
    ) external returns (
        uint shellsMinted_,
        uint[] memory deposits_
    );

    function viewProportionalDeposit (
        uint _totalStablecoins
    ) external view returns (
        uint shellsToMint_,
        uint[] memory depositsToMake_
    );

    function selectiveDeposit (
        address[] calldata _derivatives,
        uint[] calldata _amounts,
        uint _minShells,
        uint _deadline
    ) external returns (
        uint shellsMinted_
    );

    function viewSelectiveDeposit (
        address[] calldata _derivatives,
        uint[] calldata _amounts
    ) external view returns (
        uint shellsToMint_
    );

    function proportionalWithdraw (
        uint _shellTokens,
        uint _deadline
    ) external returns (
        uint[] memory withdrawals_
    );

    function viewProportionalWithdraw (
        uint _shellTokens
    ) external view returns (
        uint[] memory withdrawalsToMake_
    );

    function selectiveWithdraw (
        address[] calldata _derivatives,
        uint[] calldata _amounts,
        uint _maxShells,
        uint _deadline
    ) external returns (
        uint shellsBurned_
    );

    function viewSelectiveWithdraw (
        address[] calldata _derivatives,
        uint[] calldata _amounts
    ) external view returns (
        uint shellsToBurn_
    );

    function partitionedWithdraw (
        address[] calldata _derivatives,
        uint[] calldata _amounts
    ) external returns (
        uint[] memory withdrawals_
    );

    function viewPartitionClaims (
        address _addr
    ) external view returns (
        uint[] memory claims_
    );

    function owner () external view returns (address);

    function includeAsset (
        address _numeraire,
        address _numeraireAssimilator,
        address _reserve,
        address _reserveAssimilator,
        uint _weight
    ) external;

    function includeAssimilator (
        address _numeraire,
        address _derivative,
        address _assimilator
    ) external;

    function excluseAssimilator (
        address _assimilator
    ) external;

    function freeze (
        bool _toFreezeOrNotToFreeze
    ) external;

    function transferOwnership (
        address _newOwner
    ) external;

    function setParams (
        uint _alpha,
        uint _beta,
        uint _deltaDerivative,
        uint _epsilon,
        uint _lambda
    ) external;

    function prime () external;

    function liquidity () external view returns (
        uint totalLiquidity_,
        uint[] memory reservesLiquidity_
    );

    function name () external view returns (string memory);
    function symbol () external view returns (string memory);

    function decimals() external view returns (uint);

    function totalSupply() external view returns (uint);

    function balanceOf(
        address account
    ) external view returns (uint);

    function transfer(
        address recipient,
        uint amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    function approve(
        address spender,
        uint amount
    ) external returns (bool);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint);

    event Transfer(
        address indexed from,
        address indexed to,
        uint value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint value
    );

    event ShellsMinted(
        address indexed minter,
        uint amount,
        address[] indexed coins,
        uint[] amounts
    );

    event ShellsBurned(
        address indexed burner,
        uint amount,
        address[] indexed coins,
        uint[] amounts
    );

    event ShellsBurned(
        address indexed burner,
        uint amount
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event Trade(
        address indexed trader,
        address indexed origin,
        address indexed target,
        uint originAmount,
        uint targetAmount
    );

}