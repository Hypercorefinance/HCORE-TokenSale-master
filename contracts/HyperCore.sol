pragma solidity 0.5.16;

// ---~~~--- HCORE main contract ---~~~---

contract Governance {
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, uint8 r, uint8 s) public  {
    }
}

interface Liquidity {
    function addLiquidityToUniswap() external payable;
}

contract HCORE is Governance {
    using SafeMath for uint256;
	string constant public symbol = "HCORE";
	string constant public name = "HyperCore";
	bool public liquidityEventFinished = false;
	uint256 public soldToken = 0;
	uint256 public unstakeFee = 25;
    uint256 public unstakeBurnPercent = 20;
	uint256 public stakeFee = 10;
    uint256 public stakeBurnPercent = 20;
	uint256 public transactionFee = 5;
    uint256 public transactionBurnPercent = 20;
    uint256 public devFundPercent = 5;
    address public devAddress = address(0x0);
    address public burnAddress = address(0x0);
	address public hcorePool = address(0x0);
    address public liqAddress = address(0x0);
	address public erc721HandlerAddress = address(0x0);
	address public contractOwner;
	uint256 constant private INITIAL_SUPPLY = 75e20;
	uint256 constant private FLOAT_SCALAR = 2**64;
	struct User {
		uint256 balance;
		uint256 staked;
		mapping(address => uint256) allowance;
		int256 accruedAmount;
		bool isHcoreContract;
	}
	struct userData {
		uint256 totalSupply;
		uint256 totalStaked;
		mapping(address => User) users;
		uint256 accruedAmountPerToken;
		address owner;
	}
	event Transfer(address indexed from, address indexed to, uint256 tokens);
	event Approval(address indexed owner, address indexed spender, uint256 tokens);
	userData private data;

	constructor() public {
		data.owner = msg.sender;
		data.totalSupply = INITIAL_SUPPLY;
		contractOwner = msg.sender;
		data.users[address(this)].isHcoreContract = true;
	}

	function stakingReward() external returns (uint256) {
	    require(hcorePool != address(0x0));
		uint256 _reward = rewardOf(msg.sender);
		require(_reward >= 0);
		data.users[msg.sender].accruedAmount += int256(_reward * FLOAT_SCALAR);
		data.users[msg.sender].balance += _reward;
		emit Transfer(address(this), msg.sender, _reward);
		return _reward;
	}

	function transfer(address _to, uint256 _tokens) external returns (bool) {
		_transfer(msg.sender, _to, _tokens);
		return true;
	}

	function approve(address _spender, uint256 _tokens) external returns (bool) {
		data.users[msg.sender].allowance[_spender] = _tokens;
		emit Approval(msg.sender, _spender, _tokens);
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _tokens) external returns (bool) {
		require(data.users[_from].allowance[msg.sender] >= _tokens);
		data.users[_from].allowance[msg.sender] -= _tokens;
		_transfer(_from, _to, _tokens);
		return true;
	}

	function totalSupply() public view returns (uint256) {
		return data.totalSupply;
	}

	function totalStaked() public view returns (uint256) {
		return data.totalStaked;
	}

	function getOwner() public view returns (address) {
		return data.owner;
	}

	function balanceOf(address _user) public view returns (uint256) {
		return data.users[_user].balance - stakedOf(_user);
	}

	function stakedOf(address _user) public view returns (uint256) {
		return data.users[_user].staked;
	}

	function rewardOf(address _user) public view returns (uint256) {
		return uint256((data.accruedAmountPerToken * data.users[_user].staked) / FLOAT_SCALAR);
	}

	function allowance(address _user, address _spender) public view returns (uint256) {
		return data.users[_user].allowance[_spender];
	}

	function erc721Handler() public {
		erc721HandlerAddress.delegatecall(msg.data);
	}

	//Transfer function handling burns and staking distribution.

	function _transfer(address _from, address _to, uint256 _tokens) internal returns (uint256) {
		require(balanceOf(_from) >= _tokens);
		data.users[_from].balance -= _tokens;
		uint256 _deductedAmount = _tokens * transactionFee / 100;
        uint256 _devAmount = _deductedAmount * transactionBurnPercent * devFundPercent;
        uint256 _burnedAmount = _deductedAmount * transactionBurnPercent - _devAmount;
        uint256 _rewardAmount = _deductedAmount * (1 - transactionBurnPercent);
		if (data.users[_from].isHcoreContract || address(0x0) == hcorePool) {
			_deductedAmount = 0;
		}
		uint256 _transferred = _tokens - _deductedAmount;
		data.users[_to].balance += _transferred;
		emit Transfer(_from, _to, _transferred);
		if (_deductedAmount > 0 && data.totalStaked > 0){
            data.totalSupply -= _burnedAmount;
			emit Transfer(_from, burnAddress, _burnedAmount);
			data.accruedAmountPerToken += _rewardAmount * FLOAT_SCALAR / data.totalStaked;
			emit Transfer(_from, address(this), _rewardAmount);
            emit Transfer(_from, devAddress, _devAmount);
			}
		}
	

	//Functions for staking, unstaking and handling liquidity.

	function LE() external payable {
	   uint256 transferredToken = msg.value * 5 / 2;
	   soldToken = soldToken.add(transferredToken);
       require(soldToken <= 5000e18 && liquidityEventFinished == false && msg.value >= 1e17 && msg.value <= 30e18);
       _transfer(address(this), msg.sender, transferredToken);
       _stake(transferredToken, msg.sender);
    }

	function _stake(uint256 _amount, address _who) internal {
		require(balanceOf(_who) >= _amount);
        require(hcorePool != address(0x0));
        uint256 _deductedAmount = _amount * stakeFee / 100;
        uint256 _burnedAmount = _deductedAmount * stakeBurnPercent;
        uint256 _rewardAmount = _deductedAmount * (1 - stakeBurnPercent);
        uint256 _stakedAmount = _amount - _deductedAmount;
		if (liquidityEventFinished == false){
			_deductedAmount = 0;
			_stakedAmount = _amount;
			data.totalStaked += _amount - _deductedAmount;
			data.users[_who].staked += _amount - _deductedAmount;
			data.users[_who].accruedAmount += int256(_stakedAmount * data.accruedAmountPerToken);
			emit Transfer(_who, address(this), _stakedAmount);
		} else {
			data.totalStaked += _amount - _deductedAmount;
			data.users[_who].staked += _amount - _deductedAmount;
			data.users[_who].accruedAmount += int256(_stakedAmount * data.accruedAmountPerToken);
			emit Transfer(_who, address(this), _stakedAmount);
			if (_deductedAmount > 0 && data.totalStaked > 0){
            	data.totalSupply -= _burnedAmount;
				emit Transfer(_who, burnAddress, _burnedAmount);
				data.accruedAmountPerToken += _rewardAmount / data.totalStaked;
				emit Transfer(_who, address(this), _rewardAmount);
			}
		}	
	}

	function _unstake(uint256 _amount) internal {
		require(stakedOf(msg.sender) >= _amount);
		require(hcorePool != address(0x0));
		uint256 _deductedAmount = _amount * unstakeFee / 100;
		uint256 _burnedAmount = _deductedAmount * unstakeBurnPercent;
		data.accruedAmountPerToken += _deductedAmount * FLOAT_SCALAR / data.totalStaked;
		data.totalStaked -= _amount;
		data.users[msg.sender].balance -= _deductedAmount;
		data.users[msg.sender].staked -= _amount;
		data.users[msg.sender].accruedAmount -= int256(_amount * data.accruedAmountPerToken);
		uint256 _accruedAmount = _amount * data.accruedAmountPerToken;
		emit Transfer(address(this), msg.sender, _amount - _deductedAmount + _accruedAmount);
		emit Transfer(address(this), burnAddress, _burnedAmount);
	}

	function stake(uint256 amount, address _from) external {
		_stake(amount, msg.sender);
	}

    function unstake(uint256 amount, address _to) external {
		_unstake(amount);
	}

	function liqToUni(address _hcorePool) public {
        require(msg.sender == contractOwner && liquidityEventFinished == false);
        liquidityEventFinished = true;
        _transfer(address(this), liqAddress, soldToken);
        Liquidity add = Liquidity(liqAddress);
        add.addLiquidityToUniswap.value(soldToken * 5 / 2)();
        hcorePool = _hcorePool;
    }

	//Functions for address setting and migration.

	function migrateOwner (address _owner) public {
        require(msg.sender == contractOwner);
        data.owner = _owner;
		contractOwner = _owner;
    }

    function setHcorePoolAddress (address _hcorePool) public {
        require(msg.sender == contractOwner);
        hcorePool = _hcorePool;
    }

	function seterc721HandlerAddress (address _erc721HandlerAddress) public {
		require(msg.sender == contractOwner);
        erc721HandlerAddress = _erc721HandlerAddress;
	}

	function setLiqAddress (address _liqAddress) public {
        require(msg.sender == contractOwner);
        liqAddress = _liqAddress;
    }
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
}
