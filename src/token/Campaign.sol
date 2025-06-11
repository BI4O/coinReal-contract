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

    address public sponsor; // 项目方
    address public appContract; // 只有app可以mint
    uint public topicId; // 关联的话题ID
    uint256 public jackpot; // 奖金，美元计价
    uint256 public minJackpot = 1000 * 1e6; // 1000美元
    uint256 public minDuration = 1 days; // 1天

    // 活动状态
    uint256 public startTime;
    uint256 public endTime;
    bool public isActive = false;
    bool public initialized = false;

    // 空构造函数，用于最小代理
    constructor() ERC20("", "") {}
    
    // 初始化函数，替代构造函数
    function initialize(
        string memory _name,
        string memory _symbol, 
        address _sponsor,
        address _appContract,
        uint _topicId
    ) external {
        require(!initialized, "Already initialized");
        
        // 设置ERC20信息
        _name = _name;
        _symbol = _symbol;
        
        sponsor = _sponsor;
        appContract = _appContract;
        topicId = _topicId;
        initialized = true;
    }
    
    modifier onlyApp() {
        require(msg.sender == appContract, "Only app can mint");
        _;
    }
    
    // mint函数，只有app可以调用
    function mint(address to, uint256 amount) external onlyApp {
        _mint(to, amount);
    }

    // 活动开始
    function start(uint256 duration) public {
        // 需要注资USDC或者1.5倍于奖金美元价值的项目方token
        uint256 usdcInUSD = usdc.balanceOf(msg.sender);
        uint256 projectTokenInUSD = projectToken.balanceOf(msg.sender) * projectToken.price();
        require(usdcInUSD >= jackpot || projectTokenInUSD >= jackpot * 15 / 10, "Insufficient balance");
        // 活动时长不能小于最小时长1天
        require(duration >= minDuration, "Duration must be greater than or equal to minDuration");
        startTime = block.timestamp;
        endTime = startTime + duration;
        isActive = true;
    }

    // 活动结束方式一：到期
    function finish() public {
        require(block.timestamp >= endTime, "Campaign is not finished");
        isActive = false;
    }

    // 活动结合方式二：项目方代币价值跌至1.1倍的原来承诺的奖金价值
    function finishByLowProjectTokenPrice() public {
        uint256 currentProjectTokenPrice = projectToken.price();
        uint256 targetProjectTokenPrice = jackpot * 11 / 10;
        require(currentProjectTokenPrice <= targetProjectTokenPrice, "Project token price is not low enough");
        isActive = false;
    }

    // 活动结束后持有项目方token的参与者，可以获得奖金
    function claim() public {
        require(isActive == false, "Campaign is not active");
        require(projectToken.balanceOf(msg.sender) > 0, "You don't have any project token");
        // 按照比例来分USDC和项目方token
        uint usdcPerCPToken = usdc.balanceOf(address(this)) / totalSupply();
        uint ptokenPerCPToken = projectToken.balanceOf(address(this)) / totalSupply();
        uint usdcToClaim = usdcPerCPToken * projectToken.balanceOf(msg.sender);
        uint ptokenToClaim = ptokenPerCPToken * projectToken.balanceOf(msg.sender);
        usdc.transfer(msg.sender, usdcToClaim);
        projectToken.transfer(msg.sender, ptokenToClaim);
    }
}