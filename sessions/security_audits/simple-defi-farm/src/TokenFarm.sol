// SPDX-License-Identifier: MIT
// https://github.com/JuliaGastellu/simple-defi-farm/commit/afae9848d66c51d0ea9c36cedd163fa8420eb0ce
pragma solidity ^0.8.22;

import "./DAppToken.sol";
import "./LPToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFarm {
    string public name = "Proportional Token Farm";
    address public owner;
    DAppToken public dappToken;
    LPToken public lpToken;

    uint256 public rewardPerBlockMin = 1e18;
    uint256 public rewardPerBlockMax = 5e18;
    uint256 public rewardPerBlock = 1e18;

    uint256 public totalStakingBalance;

    uint256 public withdrawalFeeBasisPoints = 100;
    uint256 public accumulatedFees;

    struct Staker {
        uint256 stakingBalance;
        uint256 checkpoint;
        uint256 pendingRewards;
        bool hasStaked;
        bool isStaking;
    }

    mapping(address => Staker) public stakers;
    address[] public stakerAddresses;

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo owner puede ejecutar");
        _;
    }

    modifier onlyStaker() {
        require(stakers[msg.sender].isStaking, "No estas haciendo staking");
        _;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed();

    constructor(DAppToken _dappToken, LPToken _lpToken) {
        owner = msg.sender;
        dappToken = _dappToken;
        lpToken = _lpToken;
    }

    function setRewardPerBlock(uint256 _newReward) external onlyOwner {
        require(_newReward >= rewardPerBlockMin && _newReward <= rewardPerBlockMax, "Recompensa fuera del rango");
        rewardPerBlock = _newReward;
    }

    function setWithdrawalFee(uint256 _basisPoints) external onlyOwner {
        require(_basisPoints <= 1000, "Fee maximo 10%");
        withdrawalFeeBasisPoints = _basisPoints;
    }

    function withdrawFees() external onlyOwner {
        require(accumulatedFees > 0, "No hay fees para retirar");
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        dappToken.transfer(owner, amount);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Monto debe ser mayor a 0");
        Staker storage user = stakers[msg.sender];
        distributeRewards(msg.sender);

        bool sent = lpToken.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Transferencia LPToken fallo");

        if (!user.hasStaked) {
            user.hasStaked = true;
            stakerAddresses.push(msg.sender);
        }

        user.stakingBalance += _amount;
        totalStakingBalance += _amount;
        user.isStaking = true;
        if (user.checkpoint == 0) {
            user.checkpoint = block.number;
        }

        emit Deposit(msg.sender, _amount);
    }

    function withdraw() external onlyStaker {
        Staker storage user = stakers[msg.sender];
        require(user.stakingBalance > 0, "No tienes tokens para retirar");

        distributeRewards(msg.sender);

        uint256 amountToWithdraw = user.stakingBalance;
        user.stakingBalance = 0;
        user.isStaking = false;
        totalStakingBalance -= amountToWithdraw;

        bool sent = lpToken.transfer(msg.sender, amountToWithdraw);
        require(sent, "Transferencia LPToken fallo");

        emit Withdraw(msg.sender, amountToWithdraw, 0);
    }

    function claimRewards() external onlyStaker { 
        Staker storage user = stakers[msg.sender];
        distributeRewards(msg.sender);

        uint256 reward = user.pendingRewards;
        require(reward > 0, "No tienes recompensas pendientes");

        uint256 fee = (reward * withdrawalFeeBasisPoints) / 10000;
        uint256 rewardAfterFee = reward - fee;

        user.pendingRewards = 0;
        accumulatedFees += fee;

        dappToken.transfer(msg.sender, rewardAfterFee);

        emit RewardsClaimed(msg.sender, rewardAfterFee);
    }

    function distributeRewardsAll() external onlyOwner {
        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            address stakerAddr = stakerAddresses[i];
            if (stakers[stakerAddr].isStaking) {
                distributeRewards(stakerAddr);
            }
        }
        emit RewardsDistributed();
    }

    function distributeRewards(address beneficiary) private {
        Staker storage user = stakers[beneficiary];
        if (block.number <= user.checkpoint || totalStakingBalance == 0) {
            return;
        }
        uint256 blocksPassed = block.number - user.checkpoint;
        uint256 share = (user.stakingBalance * 1e18) / totalStakingBalance;
        uint256 reward = (rewardPerBlock * blocksPassed * share) / 1e18;

        user.pendingRewards += reward;
        user.checkpoint = block.number;
    }
}
