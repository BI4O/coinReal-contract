// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {USDC} from "./USDC.sol";
import {ProjectToken} from "./ProjectToken.sol";

contract CampaignToken is ERC20 {
    // 计价的USDC和项目方token
    USDC public usdc;
    ProjectToken public projectToken;

    uint public topicId; // 关联的话题ID
    uint256 public jackpotStart; // 奖金开始值，美元计价
    uint256 public jackpotRealTime; // 奖金实时值，美元计价
    uint256 public minJackpot = 1000 * 1e6; // 1000美元
    uint256 public minDuration = 1 days; // 1天

    // 活动状态
    uint256 public startTime;
    uint256 public endTime;
    bool public isActive = false;
    bool public initialized = false;

    // 活动进行中计算奖励，为了避免小数，会乘以1e6，到js中再除以1e6
    uint256 public usdcPerMillionCPToken;
    uint256 public ptokenPerMillionCPToken;

    // 活动结束后计算奖励
    uint256 public usdcPerMillionCPTokenFinal;
    uint256 public ptokenPerMillionCPTokenFinal;

    // ERC20名称和符号的存储
    string private _name;
    string private _symbol;

    // 空构造函数，用于最小代理
    constructor() ERC20("", "") {}
    
    // 重写name和symbol函数
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    
    // 初始化函数，替代构造函数
    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol, 
        uint _topicId,
        address _usdc,
        address _projectToken
    ) external {
        require(!initialized, "Already initialized");       
        // 设置ERC20信息
        _name = _tokenName;
        _symbol = _tokenSymbol;       
        topicId = _topicId;
        usdc = USDC(_usdc);
        projectToken = ProjectToken(_projectToken);
        initialized = true;
    }
    
    // mint函数
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // 销毁函数
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    // 活动开始
    function start(uint256 _endTime) public {
        // 需要注资USDC或者1.5倍于奖金美元价值的项目方token
        uint256 usdcInUSD = usdc.balanceOf(msg.sender);
        uint256 projectTokenInUSD = projectToken.balanceOf(msg.sender) * projectToken.price();
        require(usdcInUSD + projectTokenInUSD >= minJackpot * 15 / 10, "Insufficient balance");

        // 1. 记录开始时的奖金值
        jackpotStart = usdcInUSD + projectTokenInUSD; // 记录开始时的奖金值
        // 2. 记录开始时间
        startTime = block.timestamp;
        // 3. 记录结束时间
        endTime = _endTime;
        // 活动时长不能小于最小时长1天
        require(endTime - startTime >= minDuration, "Duration must be greater than or 1 day");
        // 4. 激活活动
        isActive = true;
    }

    // 活进行中模拟结算，或者结束时候真实结算
    function updateReward() public returns(uint256, uint256, uint256) {
        // 计算每个CP token的奖励
        // decimal 18 的 USDC / decimal 18 的 CP token = 1 USDC / CP token
        usdcPerMillionCPToken = 1e6 * usdc.balanceOf(address(this)) / totalSupply();
        ptokenPerMillionCPToken = 1e6 * projectToken.balanceOf(address(this)) / totalSupply();

        // 计算实时奖金
        uint256 usdcInUSD = usdc.balanceOf(msg.sender);
        uint256 projectTokenInUSD = projectToken.balanceOf(msg.sender) * projectToken.price();
        jackpotRealTime = usdcInUSD + projectTokenInUSD;

        return (usdcPerMillionCPToken, ptokenPerMillionCPToken, jackpotRealTime);
    }

    // 活动结束方式一：到期
    function finish() public {
        require(block.timestamp >= endTime, "Campaign is not finished");
        isActive = false;
        (usdcPerMillionCPTokenFinal, ptokenPerMillionCPTokenFinal, jackpotRealTime) = updateReward();
    }

    // 活动结束方式二：项目方代币价值跌至1.1倍的原来承诺的奖金价值
    function finishByLowProjectTokenPrice() public {
        uint256 currentProjectTokenPrice = projectToken.price();
        uint256 forceLiquidationTokenPrice = jackpotStart * 11 / 10;
        require(currentProjectTokenPrice <= forceLiquidationTokenPrice, "Project token price is not low enough to force liquidation");
        isActive = false;
        (usdcPerMillionCPTokenFinal, ptokenPerMillionCPTokenFinal, jackpotRealTime) = updateReward();
    }

    // 活动结束后：持有项目方token的参与者，可以获得奖金
    function claim() public {
        require(isActive == false, "Campaign is not active");
        require(balanceOf(msg.sender) > 0, "You don't have any campaign token left");

        // 按照比例来分USDC和项目方token，发放的时候除去1e6
        uint256 usdcToClaim = usdcPerMillionCPTokenFinal * balanceOf(msg.sender) / 1e6;
        uint256 ptokenToClaim = ptokenPerMillionCPTokenFinal * balanceOf(msg.sender) / 1e6;
        usdc.transfer(msg.sender, usdcToClaim);
        projectToken.transfer(msg.sender, ptokenToClaim);

        // 清空这个用户的项目方token
        burn(msg.sender, balanceOf(msg.sender));
    }
}