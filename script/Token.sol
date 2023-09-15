// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GLBT is ERC20, Ownable {

    mapping(address=>mapping(uint=>uint)) public lockingAmount;

    //      wallet-addr -> locking-period -> amount
    mapping(address => uint[]) public lockingPeriodRecord;
    //      wallet-addr -> locking-period[]
    mapping(address => uint) public unLockedAmount;

    constructor() ERC20("GLOBUS INT", "GLBT") {
        _mint(msg.sender, 120000000 * 10 ** decimals());
    }

    function tranferWithLockPeriod(address to, uint256 amount, uint lockingPeriod) public returns (bool) {
        reduceBalance(amount);
        uint lockingPeriodinUnix = block.timestamp + (lockingPeriod * 86400);   
        if(lockingAmount[to][lockingPeriodinUnix] == 0){
            lockingAmount[to][lockingPeriodinUnix] = amount;
            lockingPeriodRecord[to].push(lockingPeriodinUnix);
        }else{
            lockingAmount[to][lockingPeriodinUnix] += amount;
        }
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        reduceBalance(amount);
        address owner = _msgSender();
        _transfer(owner, to, amount);
        unLockedAmount[to] += amount;
        return true;
    }

    function balanceAvailable() public view returns(uint){
        uint temp = unLockedAmount[msg.sender];
        for(uint i = 0; i < lockingPeriodRecord[msg.sender].length; i++){
            if(lockingPeriodRecord[msg.sender][i] <= block.timestamp && lockingPeriodRecord[msg.sender][i] != 0){
                temp += lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]];
            }
        }
        return (temp);
    }

    function reduceBalance(uint amount) internal returns(bool){
        uint reqAmount = amount;
        require(balanceAvailable() >= reqAmount, "Insufficient Balance");

        for(uint i = 0; i < lockingPeriodRecord[msg.sender].length; i++){
        
            if(lockingPeriodRecord[msg.sender][i] <= block.timestamp && lockingPeriodRecord[msg.sender][i] != 0){
                if(reqAmount == 0){
                    break;
                }else if(reqAmount >= lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]]) {

                    reqAmount -= lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]];
                    lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]] = 0;
                    delete lockingPeriodRecord[msg.sender][i];
                }else if(reqAmount < lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]]){
                    lockingAmount[msg.sender][lockingPeriodRecord[msg.sender][i]] -= reqAmount;
                    reqAmount = 0;
                }
            }
        }
        if(reqAmount != 0 ){
            unLockedAmount[msg.sender] -= reqAmount;
        }
        return true;
    }

    function getAllLockedTokens() view public returns(uint[] memory) {
        uint[] memory unLockTime = new uint[](lockingPeriodRecord[msg.sender].length);
        uint count;
        for(uint i = 0; i < lockingPeriodRecord[msg.sender].length; i++){
            if(lockingPeriodRecord[msg.sender][i]!=0){
                if(lockingPeriodRecord[msg.sender][i] >= block.timestamp){
                    unLockTime[count] = lockingPeriodRecord[msg.sender][i] - block.timestamp;
                    count++;
                }
            }
        }
        return unLockTime;
    }
} 