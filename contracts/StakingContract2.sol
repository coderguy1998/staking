// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockERC20.sol";

contract StakingContract2 is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; 
        uint256 allocPoint; 
        uint256 lastRewardBlock; 
        uint256 accRewardsPerShare; 
    }

    MockERC20 public _underlyingToken;
    address public devaddr;
    uint256 public rewardsPerBlock;

    PoolInfo public poolInfo2;
    mapping(address => UserInfo) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed amount);

    constructor(
        MockERC20 underlyingToken,
        address _devaddr,
        uint256 _rewardsPerBlock,
        uint256 _startBlock
    ) {
        _underlyingToken = underlyingToken;
        devaddr = _devaddr;
        rewardsPerBlock = _rewardsPerBlock;
        startBlock = _startBlock;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            updatePool();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo2 = PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRewardsPerShare: 0
        });
    }

    function set(uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            updatePool();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo2.allocPoint).add(
            _allocPoint
        );
        poolInfo2.allocPoint = _allocPoint;
    }

    function pendingSushi(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo2;
        UserInfo storage user = userInfo[_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = (block.number).sub(pool.lastRewardBlock);
            uint256 reward = multiplier
                .mul(rewardsPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accRewardsPerShare = accRewardsPerShare.add(
                reward.mul(1e12).div(lpSupply)
            );
        }
        return
            user.amount.mul(accRewardsPerShare).div(1e12).sub(user.rewardDebt);
    }

    function updatePool() public {
        PoolInfo storage pool = poolInfo2;
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = (block.number).sub(pool.lastRewardBlock);
        uint256 reward = multiplier
            .mul(rewardsPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        _underlyingToken.mint(devaddr, reward.div(10));
        _underlyingToken.mint(address(this), reward);
        pool.accRewardsPerShare = pool.accRewardsPerShare.add(
            reward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo2;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accRewardsPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            safeTokenTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        PoolInfo storage pool = poolInfo2;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 pending = user
            .amount
            .mul(pool.accRewardsPerShare)
            .div(1e12)
            .sub(user.rewardDebt);
        safeTokenTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardsPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = _underlyingToken.balanceOf(address(this));
        if (_amount > tokenBal) {
            _underlyingToken.transfer(_to, tokenBal);
        } else {
            _underlyingToken.transfer(_to, _amount);
        }
    }

    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
