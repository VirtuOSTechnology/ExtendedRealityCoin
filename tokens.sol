pragma solidity ^0.4.18;

interface recipientToken {function receiveApproval (address _from, uint256 _value, address _token, bytes _extraData) public;}

/*
	@title	Contract allows to hold all tokens between migration of the main contract code
	@author	Pereshein V.G. <envage@yandex.ru>
	@notice	If you want to become a tokens sale investor, want to learn more about bounty program
			or have questions, please write me. Now you can buy tokens at lower price 3500 tokens per ETH
*/
contract balances
{
	//	Storing tokens here
	mapping (address => account) public accounts;
	address [] public holders;

	address public owner = 0x0;
	
	//	This address allows access contract methods
	address public allow = 0x0;

	modifier onlyowner {require (msg.sender == owner); _;}
	modifier onlyallow {require (msg.sender == allow); _;}

	function balances (address _parent) public
	{
		owner = msg.sender;
		allow = _parent;
	}
	
	//	Get total account info as structure
	function getAccount (address _owner) external onlyallow constant returns (account)
	{
		if (accounts [_owner].addr == _owner) return accounts [_owner];
	}
	
	//	Install allow address
	function setAllow (address _value) external onlyowner
	{
		allow = _value;
	}
	
	//	@notice		Get address of the tokens holder by index at the holders array
	//	@param		_index	index at the array
	//	@result		Return holder address
	function addrByIndex (uint _index) external onlyallow constant returns (address)
	{
		if (_index >= holders.length) return 0x0;
		
		return holders [_index];
	}
	
	//	@notice		Same as addrByIndex, but returns value from accounts mapping
	//				at the assigned address. It's important for the account exist checks
	//	@param		_owner	holders address
	//	@result		holder address
	function getAddr (address _owner) external onlyallow constant returns (address)
	{
		return accounts [_owner].addr;
	}
	
	//	@notice		Set or replace holder address. Be carefull!
	//	@param		_owner	account holder address
	//	@param		_value	new holder address
	function setAddr (address _owner, address _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].addr = _value;
	}
	
	//	@notice		Get holder balance in tokens
	//	@param		_owner	holder address
	//	@result		Current balance in tokens
	function getValue (address _owner) external onlyallow constant returns (uint)
	{
		return accounts [_owner].value;
	}
	
	//	@notice		Set or update holder balance in tokens
	//	@param		_owner	holder address
	//	@param		_value	new balance value
	//	@param		_mode	how to change balance
	//						0 - replace current value with new
	//						1 - add new value to the current
	//						2 - substract new value from current
	//	@warning	This method doesn't check value ranges. So, this must executed by sender!
	function setValue (address _owner, uint _value, uint _mode) external onlyallow
	{
		if (accounts [_owner].addr == _owner)
		{
			if (_mode == 0) accounts [_owner].value = _value;
			else if (_mode == 1) accounts [_owner].value += _value;
			else accounts [_owner].value -= _value;
		}
	}
	
	//	@notice		Check is account active or not
	//	@param		_owner	holder address
	//	@result		Boolean value (true if active, false in another cases)
	function getEnabled (address _owner) external onlyallow constant returns (bool)
	{
		return accounts [_owner].enabled;
	}
	
	//	@notice		Setup new activity value
	//	@param		_owner	account owner address
	//	@param		_value	new state value
	function setEnabled (address _owner, bool _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].enabled = _value;
	}
	
	//	@notice		Account busy check. E.g. Account owner couldn't transfer any tokens in lock state
	//	@param		_owner	locking account address
	//	@result		Return current lock state (as binary flags)
	function getLock (address _owner) external onlyallow constant returns (uint)
	{
		return accounts [_owner].locked;
	}
	
	//	@notice		Set or drop account lock bits
	//	@param		_owner	account address
	//	@param		_value	value to replace current state
	function setLock (address _owner, uint _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].locked = _value;
	}
	
	//	@notice		Create new account
	//	@param		_owner	account address
	//	@result		Return holder address
	function create (address _owner) external onlyallow returns (address) 
	{
		if (accounts [_owner].addr != _owner)
		{
			accounts [_owner].locked = 0;
			accounts [_owner].enabled = true;
			accounts [_owner].value = 0;
			accounts [_owner].addr = _owner;

			holders.length ++;
			holders [holders.length - 1] = _owner;
		}

		return _owner;
	}
	
	//	@notice		Get account external identifier (e.g. remote serve control)
	//	@param		_owner	account address
	//	@result		UTF-8 string value of the identifier
	function getIdentifier (address _owner) external onlyallow constant returns (string)
	{
		return accounts [_owner].identifier;
	}

	function setIdentifier (address _owner, string _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].identifier = _value;
	}
	
	//	@notice		Default account info structure. See describtion at the bottom of this file
	struct account
	{
		string identifier;
		uint locked;
		bool enabled;
		uint value;
		address addr;
	}
}

contract general
{
	string public name = 'Extended Reality Coin';
	string public symbol = 'ERC';
	uint8 public decimals = 2;
	string public version = '1.0 (Step 1 "PreInvest")';
	string public description = "PreInvest stage for the next extension of the project";

	//  Total issued or current volume of the tokens
	uint public totalSupply = 0;
	
	//  Total sold tokens, not free or share
	uint public totalSold = 0;
	uint public totalWei = 0;
	uint public totalReserved = 0;
	uint public totalCompany = 0;
	
	//  Variable below consider the fractionality (N/10^decimals)
	uint public tokensInSale = 500000;
	
	//  Bonus exchange rate for then volume above (value below * 1 token = Investors profit in tokens)
	uint public tokensRate = 3500;

	//  Here placed contract owner ethereum address
	address public publisher = 0x0;
	address public reserved = 0x0;
	address public company = 0x0;

	balances public balance;

	bool public contractMigrated = false;

	//  Events declaration
	event Transfer (address indexed sender, address indexed reciever, uint amount);
	event Issued (address indexed reciever, uint volume, uint amount);
	event IncomeValue (address indexed from, uint amount, uint mainTokens, uint totalTokens);
	event Migrating (bool removed);

	//  Contract constructor
	function general (address balancesAddress) public
	{
		balance = balances (balancesAddress);

		publisher = msg.sender;
	}

	function initialize (address reservedAccount, address companyAccount) public
	{
		if (contractMigrated == true) return;

		if (msg.sender == publisher)
		{
			publisher = balance.create (publisher);
			reserved = balance.create (reservedAccount);
			company = balance.create (companyAccount);
		}
	}

	function balanceOf (address owner) external constant returns (uint)
	{
		if (contractMigrated == true) return 0;

		return balance.getValue (owner);
	}

	function transfer (address reciever, uint amount) external returns (bool)
	{
		if (contractMigrated == true) return false;

		//	Tokens couldn't be transfered from contract affliate addresses, but not bounty, adwizors and mentors
		if (msg.sender == publisher || msg.sender == reserved || msg.sender == company || msg.sender == address (this)) return false;
		if (reciever == publisher || reciever == reserved || reciever == company || reciever == address (this)) return false;

		//	If accounts not registred create them
		if (balance.getAddr (msg.sender) != msg.sender) balance.create (msg.sender);
		if (balance.getAddr (reciever) != reciever) balance.create (reciever);
		//	It's a binary flag
		if ((uint lock = balance.getLock (msg.sender)) & LOCK_TRANSFER != 0) return false;

		//	Lock address untill this operation not done
		balance.setLock (msg.sender, (lock | LOCK_TRANSFER));

		if (balance.getValue (msg.sender) < amount)
		{
			//	Balance of the sender low then required amount, so unlock address and exit
			balance.setLock (msg.sender, (balance.getLock (msg.sender) ^ LOCK_TRANSFER));
			return false;
		}

		balance.setValue (msg.sender, amount, 2);
		balance.setValue (reciever, amount, 1);

		Transfer (msg.sender, reciever, amount);

		balance.setLock (msg.sender, (balance.getLock (msg.sender) ^ LOCK_TRANSFER));

		return true;
	}
	
	//	@notice		Set contract remove state by sending event message or/and delete contract with all data
	//	@param		onlyEvent	prevent full contract removing or not
	function kill (bool onlyEvent) external
	{
		if (onlyEvent == true) Migrating (false);
		else Migrating (true);

		contractMigrated = true;

		if (onlyEvent == false) selfdestruct (publisher);
	}

	function buy (address owner, uint value) private returns (bool)
	{
		if (contractMigrated == true) return false;

		//	Contract publisher can transfer some ETH for the forward operations (e.g. migration that's took a lot of money for transfers)
		if (owner != publisher)
		{
			uint tokens = 0;
			uint amount = 0;
			uint totals = 0;

			tokens = (value * (10 ** uint (decimals))) / (10 ** 18);

			if (tokens * (10 ** 16) > value) tokens --;
			if (tokens > tokensInSale) tokens = tokensInSale;

			amount = (10 ** 17) * tokens;

			if (owner == 0x0 || value == 0 || tokensInSale == 0) return false;
			if (balance.getAddr (owner) != owner) balance.create (owner);
			if (balance.getEnabled (owner) == false) return false;
			if (amount == 0 || tokens == 0) return false;

			totals = tokens * tokensRate;
			tokensInSale -= tokens;
			totalSupply += totals;
			totalSold += tokens;
			totalWei += amount;

			balance.setValue (owner, totals, 1);

			IncomeValue (owner, amount, tokens, totals);
			Transfer (this, owner, totals);

			if (amount < value) owner.transfer (value - amount);

			publisher.transfer (amount);

			if (RESERVED_SHARE > 0 && reserved != 0x0)
			{
				tokens = (((totals * (10 ** (uint (decimals) + 1))) / INVESTORS_SHARE) * RESERVED_SHARE) / (10 ** (uint (decimals) + 1));

				totalSupply += tokens;
				totalReserved += tokens;

				if (balance.getAddr (reserved) != reserved) balance.create (reserved);

				balance.setValue (reserved, tokens, 1);

				Transfer (this, reserved, tokens);
			}

			if (COMPANY_SHARE > 0 && company != 0x0)
			{
				tokens = ((totals * (10 ** (uint (decimals) + 1)) / INVESTORS_SHARE) * COMPANY_SHARE) / (10 ** (uint (decimals) + 1));

				totalSupply += tokens;
				totalCompany += tokens;

				if (balance.getAddr (company) != company) balance.create (company);

				balance.setValue (company, tokens, 1);

				Transfer (this, company, tokens);
			}
		}

		return true;
	}

	function () external payable
	{
		if (buy (msg.sender, msg.value) == false) revert ();
	}

	struct account
	{
		string identifier;	//	External identifier. E.g. remote control server
		uint locked;		//  What oprations is deprecated to the user
		bool enabled;		//  Is account enabled
		uint value;			//  Tokens balance
		address addr;
	}

	uint constant LOCK_TRANSFER = 1;		//	Lock from changes bit flag
	uint constant RESERVED_SHARE = 1000;	//	Equals to 10.00%
	uint constant COMPANY_SHARE = 1500;		//	Equals to 15.00%
	uint constant INVESTORS_SHARE = 7500;	//	Equals to 75.00%
}