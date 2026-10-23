pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAggregator.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

contract Presale is Ownable {
    using SafeERC20 for IERC20;
    address public saleTokenAddress;
    address public usdtAddress;
    address public usdcAddress;
    address public fundsReceiverAddress;
    address public dataFeedAddress;
    uint256 public maxSellingAmount;
    uint256 public startingTime;
    uint256 public endingTime;
    uint256[3] public phases;
    uint256 public totalSold;
    uint256 public currentPhase;
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) public userTokenBalance;
    event TokenBuy(address indexed user, uint256 amount);

    constructor(address saleTokenAddress_, address usdtAddress_, address usdcAddress_, address fundsReceiverAddress_, address dataFeedAddress_, uint256 maxSellingAmount_, uint256 startingTime_ , uint256 endingTime_ , uint256[3] memory phases_) Ownable(msg.sender) {
        saleTokenAddress = saleTokenAddress_;
        usdtAddress = usdtAddress_;
        usdcAddress = usdcAddress_;
        fundsReceiverAddress = fundsReceiverAddress_;
        dataFeedAddress = dataFeedAddress_;
        maxSellingAmount = maxSellingAmount_;
        startingTime = startingTime_;
        endingTime = endingTime_;
        phases = phases_;
        require(endingTime > startingTime, "Incorrect Presale Times");
    }

    function fundPresale(uint256 amount_) external onlyOwner {
        IERC20(saleTokenAddress).safeTransferFrom(msg.sender, address(this), amount_);
    }

    function blackList(address user_) external onlyOwner { isBlacklisted[user_] = true; }
    function removeBlacklist(address user_) external onlyOwner { isBlacklisted[user_] = false; }

    function checkCurrentPhase(uint256 amount_) private returns(uint256) {
        if(currentPhase < 2) {
            if(totalSold + amount_ >= phases[currentPhase] || block.timestamp >= endingTime) {
                currentPhase++;
            }
        }
        return currentPhase;
    }

    function buyWithStable(address tokenUsedtoToBuy_, uint256 amount_) external {
        require(!isBlacklisted[msg.sender], "User is blackListed");
        require(block.timestamp >= startingTime && block.timestamp <= endingTime, "Presale not started yet");
        require(tokenUsedtoToBuy_ == usdtAddress || tokenUsedtoToBuy_ == usdcAddress, "Incorrect token");
        uint8 dec = IERC20Decimals(tokenUsedtoToBuy_).decimals();
        uint256 tokenAmountToReceive;
        if (dec == 18) tokenAmountToReceive = amount_ * 1e6 / phases[currentPhase];
        else tokenAmountToReceive = amount_ * 10**(18 - dec) * 1e6 / phases[currentPhase];
        checkCurrentPhase(tokenAmountToReceive);
        totalSold += tokenAmountToReceive;
        require(totalSold <= maxSellingAmount, "sold out");
        userTokenBalance[msg.sender] += tokenAmountToReceive;
        IERC20(tokenUsedtoToBuy_).safeTransferFrom(msg.sender, fundsReceiverAddress, amount_);
        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }

    function buyWithEther() external payable {
        require(!isBlacklisted[msg.sender], "User is blackListed");
        require(block.timestamp >= startingTime && block.timestamp <= endingTime, "Presale not started yet");
        uint256 usdValue = msg.value * getEtherPrice() / 1e18;
        uint256 tokenAmountToReceive = usdValue * 1e6 / phases[currentPhase];
        checkCurrentPhase(tokenAmountToReceive);
        totalSold += tokenAmountToReceive;
        require(totalSold <= maxSellingAmount, "sold out");
        userTokenBalance[msg.sender] += tokenAmountToReceive;
        (bool success, )= fundsReceiverAddress.call{value: msg.value}("");
        require(success, "Transfer Failed");
        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }

    function claim() external {
        require(block.timestamp > endingTime, "Presale not ended");
        uint256 amount = userTokenBalance[msg.sender];
        delete userTokenBalance[msg.sender];
        IERC20(saleTokenAddress).safeTransfer(msg.sender, amount);
    }

    function getEtherPrice() public view returns (uint256) {
       (, int256 price,,,) = IAggregator(dataFeedAddress).latestRoundData();
       price = price * (10 ** 10);
       return uint256(price);
    }

    function emergencyERC20Withdraw(address tokenAddress_, uint256 amount_) external onlyOwner {
        IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
    }

    function emergencyETHWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

        
}
