pragma solidity ^0.5.12;

import "ds-math/math.sol";

import "./LoihiRoot.sol";
import "./ChaiI.sol";
import "./CTokenI.sol";
import "./ERC20I.sol";
import "./ERC20Token.sol";

contract Loihi is LoihiRoot { 


    function includeAdaptation (address flavor, address adapter, uint256 weight) public {
        flavors[flavor] = Flavor(adapter, weight);
    }

    function excludeAdaptation (address flavor) public {
        delete flavors[flavor];
    }

    function dGetNumeraireAmount (address addr, uint256 amount) internal returns (uint256) {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("getNumeraireAmount(uint256)", amount));
        assert(success);
        return abi.decode(result, (uint256));
    }

    function dGetNumeraireBalance (address addr) internal returns (uint256) {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("getNumeraireBalance()"));
        assert(success);
        return abi.decode(result, (uint256));
    }

    function dIntakeRaw (address addr, address src, uint256 amount) internal {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("intakeRaw(address, uint256)", src, amount));
        assert(success);
    }

    function dIntakeNumeraire (address addr, address src, uint256 amount) internal {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("intakeNumeraire(address, uint256)", src, amount));
        assert(success);
    }

    function dOutputRaw (address addr, address dst, uint256 amount) internal returns (uint256) {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("outputRaw(address, uint256)", dst, amount));
        assert(success);
        return abi.decode(result, (uint256));
    }

    function dOutputNumeraire (address addr, address dst, uint256 amount) internal returns (uint256) {
        (bool success, bytes memory result) = addr.delegatecall(abi.encodeWithSignature("outputNumeraire(address, uint256)", dst, amount));
        assert(success);
        return abi.decode(result, (uint256));
    }

    function swapByTarget (address origin, uint256 maxOriginAmount, address target, uint256 targetAmount, uint256 deadline) public returns (uint256) {
        return executeTargetTrade(origin, target, maxOriginAmount, targetAmount, deadline, msg.sender);
    }
    function transferByTarget (address origin, uint256 maxOriginAmount, address target, uint256 targetAmount, uint256 deadline, address recipient) public returns (uint256) {
        return executeTargetTrade(origin, target, maxOriginAmount, targetAmount, deadline, recipient);
    }
    function swapByOrigin (address origin, uint256 originAmount, address target, uint256 minTargetAmount, uint256 deadline) public returns (uint256) {
        return executeOriginTrade(origin, target, originAmount, minTargetAmount, deadline, msg.sender);
    }
    function transferByOrigin (address origin, uint256 originAmount, address target, uint256 minTargetAmount, uint256 deadline, address recipient) public returns (uint256) {
        return executeOriginTrade(origin, target, originAmount, minTargetAmount, deadline, recipient);
    }

    function executeOriginTrade (address origin, address target, uint256 oAmt, uint256 minTargetAmount, uint256 deadline, address recipient) public returns (uint256) {

        uint256 oNAmt; // origin numeraire amount
        uint256 oPool; // origin pool balance
        uint256 tPool; // target pool balance
        uint256 tNAmt; // target numeraire swap amount
        uint256 grossLiq; // total liquidity in all coins
        Flavor memory o = flavors[origin]; // origin adapter + weight
        Flavor memory t = flavors[target]; // target adapter + weight

        for (uint i = 0; i < reservesList.length; i++) {
            if (reservesList[i] == o.adapter) {
                oNAmt = dGetNumeraireAmount(o.adapter, oAmt);
                oPool = add(dGetNumeraireBalance(o.adapter), oNAmt);
                grossLiq += oPool;
            } else if (reservesList[i] == t.adapter) {
                tPool = dGetNumeraireBalance(t.adapter);
                grossLiq += tPool;
            } else grossLiq += dGetNumeraireBalance(reservesList[i]);
        }

        require(oPool <= wmul(o.weight, wmul(grossLiq, alpha + WAD)), "origin swap halt check");

        uint256 feeThreshold = wmul(o.weight, wmul(grossLiq, beta + WAD));
        if (oPool < feeThreshold) {
            oNAmt = oNAmt;
        } else if (sub(oPool, oNAmt) >= feeThreshold) {
            uint256 fee = wdiv(oNAmt, wmul(o.weight, grossLiq));
            fee = wmul(fee, feeDerivative);
            oNAmt = wmul(oNAmt, WAD - fee);
        } else {
            uint256 oldBalance = sub(oPool, oNAmt);
            uint256 fee = wmul(feeDerivative, wdiv(
                sub(oPool, feeThreshold),
                wmul(o.weight, grossLiq)
            ));
            oNAmt = add(
                sub(feeThreshold, oldBalance),
                wmul(sub(oPool, feeThreshold), WAD - fee)
            );
        }

        tNAmt = oNAmt;
        require(sub(tPool, tNAmt) >= wmul(t.weight, wmul(grossLiq, WAD - alpha)), "target swap halt check");

        feeThreshold = wmul(t.weight, wmul(grossLiq, WAD - beta));
        if (sub(tPool, tNAmt) > feeThreshold) {
            tNAmt = wmul(tNAmt, WAD - feeBase);
        } else if (tPool <= feeThreshold) {
            uint256 fee = wmul(feeDerivative, wdiv(tNAmt, wmul(t.weight, grossLiq))) - feeBase;
            tNAmt = wmul(tNAmt, WAD - fee);
        } else {
            uint256 fee = wmul(feeDerivative, wdiv(
                sub(feeThreshold, sub(tPool, tNAmt)),
                wmul(t.weight, grossLiq)
            ));
            tNAmt = wmul(add(
                sub(tPool, feeThreshold),
                wmul(sub(feeThreshold, sub(tPool, tNAmt)), WAD - fee)
            ), WAD - feeBase);
        }

        dIntakeRaw(o.adapter, msg.sender, oAmt);
        dOutputNumeraire(t.adapter, recipient, tNAmt);

    }

    function executeTargetTrade (address origin, address target, uint256 maxOriginAmount, uint256 tAmt, uint256 deadline, address recipient) public returns (uint256) {
        require(deadline > now, "transaction deadline has passed");

        Flavor memory t = flavors[target]; // target adapter + weight
        Flavor memory o = flavors[origin]; // origin adapter + weight
        uint256 tNAmt; // target numeraire swap amount
        uint256 tPool; // target pool balance
        uint256 oPool; // origin pool balance
        uint256 oNAmt; // origin numeriare swap amount
        uint256 grossLiq; // gross liquidity

        for (uint i = 0; i < reservesList.length; i++) {
            if (reservesList[i] == o.adapter) {
                oPool = dGetNumeraireBalance(o.adapter);
                grossLiq += oPool;
            } else if (reservesList[i] == t.adapter) {
                tNAmt = dGetNumeraireAmount(t.adapter, tNAmt);
                tPool = sub(dGetNumeraireBalance(t.adapter), tNAmt);
                grossLiq += tPool;
            } else grossLiq += dGetNumeraireBalance(reservesList[i]);
        }

        require(tPool - tNAmt >= wmul(t.weight, wmul(grossLiq, WAD - alpha)), "target halt check");

        uint256 feeThreshold = wmul(t.weight, wmul(grossLiq, WAD - beta));
        if (tPool > feeThreshold) {
            tNAmt = wmul(tNAmt, WAD - feeBase);
        } else if (add(tPool, tNAmt) <= feeThreshold) {
            uint256 fee = wmul(feeDerivative, wdiv(tNAmt, wmul(t.weight, grossLiq))) + feeBase;
            tNAmt = wmul(tNAmt, WAD + fee);
        } else {
            uint256 fee = wmul(feeDerivative, wdiv(
                    sub(feeThreshold, tPool),
                    wmul(t.weight, grossLiq)
            ));
            tNAmt = add(
                sub(add(tPool, tNAmt), feeThreshold),
                wmul(sub(feeThreshold, tPool), WAD + fee)
            );
            tNAmt = wmul(tNAmt, WAD + feeBase);
        }

        oNAmt = tNAmt;
        require(oPool + oNAmt <= wmul(o.weight, wmul(grossLiq, WAD + alpha)));

        feeThreshold = wmul(o.weight, wmul(grossLiq, WAD + beta));
        if (oPool + oNAmt < feeThreshold) { }
        else if (oPool >= feeThreshold) {
            uint256 fee = wmul(feeDerivative, wdiv(o.weight, grossLiq));
            oNAmt = wmul(oNAmt, WAD + fee);
        } else {
            uint256 fee = wmul(feeDerivative, wdiv(
                sub(feeThreshold, oPool),
                wmul(o.weight, grossLiq)
            ));
            oNAmt = add(
                sub(feeThreshold, oPool),
                wmul(sub(add(oPool, oNAmt), feeThreshold), WAD + fee)
            );
        }

        dOutputRaw(t.adapter, recipient, tAmt);
        dIntakeNumeraire(o.adapter, msg.sender, oNAmt);

    }

    function selectiveDeposit (address[] calldata _flavors, uint256[] calldata _amounts) external returns (uint256) {

        uint256 oldSum;
        uint256 newSum;
        uint256 newShells;
        uint256[] memory balances = new uint256[](reservesList.length * 3);
        for (uint i = 0; i < _flavors.length; i += 3) {
            Flavor memory d = flavors[_flavors[i]]; // depositing adapter/weight
            for (uint j = 0; j < reservesList.length; j++) {
                if (reservesList[i] == d.adapter) {
                    if (balances[i] == 0) {
                        balances[i] = dGetNumeraireBalance(d.adapter);
                        balances[i+1] = dGetNumeraireAmount(d.adapter, _amounts[i]);
                        balances[i+2] = d.weight;
                        newSum = add(balances[i+1], newSum);
                    } else {
                        uint256 numeraireDeposit = dGetNumeraireAmount(d.adapter, _amounts[i]);
                        balances[i+1] = add(numeraireDeposit, balances[i+1]);
                        newSum = add(numeraireDeposit, newSum);
                    }
                    break;
        } } }

        for (uint i = 0; i < balances.length; i += 3) {
            uint256 oldBalance = balances[i];
            uint256 depositAmount = balances[i+1];
            uint256 newBalance = add(oldBalance, depositAmount);

            require(newBalance <= wmul(balances[i+2], wmul(newSum, alpha + WAD)), "halt check deposit");

            uint256 feeThreshold = wmul(balances[i+2], wmul(newSum, beta + WAD));
            if (newBalance <= feeThreshold) {
                newShells += depositAmount;
            } else if (oldBalance > feeThreshold) {
                uint256 feePrep = wmul(feeDerivative, wdiv(depositAmount, wmul(balances[i+2], newSum)));
                newShells = add(newShells, WAD - feePrep);
            } else {
                uint256 feePrep = wmul(feeDerivative, wdiv(
                    sub(newBalance, feeThreshold),
                    wmul(balances[i+2], newBalance)
                ));
                newShells += add(
                    sub(feeThreshold, oldBalance),
                    wmul(sub(newBalance, feeThreshold), WAD - feePrep)
                );
        } }

        newShells = wdiv(newShells, wmul(oldSum, totalSupply()));

        for (uint i = 0; i < _flavors.length; i++) dOutputNumeraire(_flavors[i], msg.sender, _amounts[i]);

        _mint(msg.sender, newShells);

    }

    function selectiveWithdraw (address[] calldata _flavors, uint256[] calldata _amounts) external returns (uint256) {

        uint256 newSum;
        uint256 oldSum;
        uint256 shellsBurned;
        uint256[] memory balances = new uint256[](reservesList.length * 3);
        for (uint i = 0; i < _flavors.length; i += 3) {
            Flavor memory w = flavors[_flavors[i]]; // withdrawing adapter + weight
            for (uint j = 0; j < reservesList.length; j++) {
                if (reservesList[i] == w.adapter) {
                    if (balances[i] == 0) {
                        balances[i] = dGetNumeraireBalance(w.adapter);
                        balances[i+1] = dGetNumeraireAmount(w.adapter, _amounts[i]);
                        balances[i+2] = w.weight;
                        newSum = sub(add(newSum, balances[i]), balances[i+1]);
                        oldSum += balances[i];
                    } else {
                        uint256 numeraireWithdraw = dGetNumeraireAmount(w.adapter, _amounts[i]);
                        balances[i+1] = add(numeraireWithdraw, balances[i+1]);
                        newSum = sub(newSum, numeraireWithdraw);
                    }
                    break;
        } } }

        for (uint i = 0; i < balances.length; i += 3) {
            uint256 oldBalance = balances[i];
            uint256 withdrawAmount = balances[i+1];
            uint256 newBalance = sub(oldBalance, withdrawAmount);

            bool haltCheck = newBalance >= wmul(balances[i+2], wmul(newBalance, alpha - WAD));
            require(haltCheck, "withdraw halt check");

            uint256 feeThreshold = wmul(balances[i+2], wmul(newBalance, WAD - beta));
            if (newBalance >= feeThreshold) {
                shellsBurned += wmul(withdrawAmount, add(WAD, feeBase));
            } else if (oldBalance < feeThreshold) {
                uint256 feePrep = wdiv(withdrawAmount,
                    wmul(wmul(balances[i+2], newSum), wdiv(feeDerivative, WAD*2))
                );
                shellsBurned += wmul(withdrawAmount, feePrep + feeBase + WAD);
            } else {
                uint256 feePrep = wdiv(
                    sub(feeThreshold, newBalance),
                    wmul(balances[i+2], newSum)
                );
                feePrep = wmul(feeDerivative, feePrep);
                shellsBurned += wmul(add(
                    sub(oldBalance, feeThreshold),
                    wmul(sub(feeThreshold, newBalance), feePrep + WAD)
                ), feeBase + WAD);
        }}

        shellsBurned = wdiv(shellsBurned, wmul(oldSum, totalSupply()));

        for (uint i = 0; i < _flavors.length; i++) dOutputNumeraire(_flavors[i], msg.sender, _amounts[i]);

        _burnFrom(msg.sender, shellsBurned);

    }
}