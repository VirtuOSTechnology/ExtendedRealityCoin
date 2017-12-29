pragma solidity ^0.4.18;

interface recipientToken {function receiveApproval (address _from, uint256 _value, address _token, bytes _extraData) public;}

contract sale is common
{
	/*  Основные константы контракта  */
	string constant public name 	= 'Virtuality Systems';
	string constant public symbol 	= 'VS';
	uint8  constant public decimals = 2;
	string constant public version 	= '1.2 (Strict Edition) - Sale Stage';
	
	uint constant reservedFundShare = 1000;										//	Доля резервного фонда в общем объеме выпущенных токенов
	uint constant personelFundShare = 1000;										//	Доля фонда компании в общем объеме выпущенных токенов
	uint constant investorFundShare = 8000;										//	Доля инвесторов в общем объеме выпущенных токенов
	
	uint constant bountyLimit = 1500;											//	Лимит отчислений на программу Bounty
	
	uint constant tokensSaleLimit = 3000000 * (10 ** uint (decimals));			//	Лимит токенов на распродаже (без учета бонусных токенов)
	uint constant tokensBonusLimit = 5000000 * (10 ** uint (decimals));			//	Лимит бонусных токенов
	
	uint constant tokensLimitAtPreSale = 1000000 * (10 ** uint (decimals));		//	Лимит токенов для распродажи на этапе PreSale
	uint constant tokensLimitAtMainSale = 2000000 * (10 ** uint (decimals));	//	Лимит токенов для распродажи на этапе MainSale
	
	uint constant tokensCostPreSale = 10000000000000000;						//	Стоимость токена (0,0100 ETH) на этапе PreSale (предварительная продажа)
	uint constant tokensCostMainSale = 20000000000000000;						//	Стоимость токена (0,0200 ETH) на этапе MainSale (основная продажа)
	uint constant tokensCostBonusSale = 1000000000000000;						//	Стоимость токена (0,0010 ETH) на этапе распродажи бонусов BonusSale
	
	//	Бонусные токены на этапах PreSale и MainSale
	//	начисляются только при указании покупателем
	//	кода, выданного менеджером по продажам
	uint constant tokensPerOneAtPreSale = 4;									//	Количество бонусных токенов за приобретенную единицу на этапе PreSale
	uint constant tokensPerOneAtMainSale = 2;									//	Количество бонусных токенов за приобретенную единицу на этапе MainSale
	uint constant tokensPerOneAtBonusSale = 1;									//	Количество бонусных токенов за приобретенную единицу на этапе BonusSale
	
	address public owner = 0x0;													//	Адрес аккаунта, с которого был установлен контракт
	
	holders internal holder;													//	Расширение: балансы держателей токенов (balances, v. 1.0+)
	
	mapping (address => bounty_t) internal bounty;								//	Хранение сведений об участниках баунти-програм
	
	bool public finished = false;
	
	//	Эту группу данных нужно будет перенести в основной контракт
	//	после завершения распродажи токенов
	funds_t internal funds;														//	Адреса хранилищ фондов компании
	
	uint public totalInSale = tokensSaleLimit;									//	Количество токенов в распродаже на текущий момент (остаток)
	uint public totalBonuses = tokensBonusLimit;								//	Остаток бонусных токенов на текущий момент
	uint public totalSupply = 0;												//	Общее число выпущенных токенов: распродажа + фонды
	uint public totalBounty = 0;												//	Общее число выданных токенов по программе Bounty
	uint public totalReserved = 0;												//	Количество токенов (за вычетом выплаченных по программе Bounty) в резервном фонде
	uint public totalPersonel = 0;												//	Количество токенов, зарезервированных на персонал
	
	modifier onlyowner {require (msg.sender == owner); _;}
	
	event Complete (string message, address where, bool deleted);
	event Income (address from, uint income, uint amount, uint refund, uint tokens);
	
	function sale () public
	{
		owner = msg.sender;
	}
	
	/*	Метод инициализации наиболее важных параметров контракта  */
	function initialize (address balanceAddress, address financesFundsAddress, address reservedFundsAddress, address personelFundsAddress) public onlyowner returns (bool)
	{
		//	Метод не может быть выполнен, если установлен флаг о завершении распродажи токенов
		if (finished == true) return false;
		
		//	Указание адреса контракта-хранилища балансов держателей токенов ОБЯЗАТЕЛЬНО,
		//	но может быть установлено позднее. Без его указания этот метод завершится критической
		//	ошибкой, а контракт будет в нерабочем состоянии до этого момента
		require (balance = balances (balanceAddress));
		
		//	Потребность в ниже обозначенных адресах продиктован требованиями безопасности
		//	при хранении ETH на балансе контракта (будет выводиться при каждом поступлении платежа
		//	и распределен равномерно по группе аккаунтов с целью снижения риска в случае кражи) и
		//	логикой распределения токенов по резевному фонду и выдачи токенов сотрудникам.
		//	Объем допустимого вывода из резервного фонда строго лимитирован (15%) и
		//	предназначен для оплаты участников баунти-программы. Остальная часть может
		//	быть выведена на биржу либо продана действующим держателям токенов только в случае
		//	особой необходимости! Распределение токенов сотрудников полностью запрещено
		//	до окончательного завершения проекта. В этом случае разблокировка происходит автоматически.
		if ((funds.finances = balance.create (financesFundsAddress)) != financesFundsAddress) return false;
		if ((funds.reserved = balance.create (reservedFundsAddress)) != reservedFundsAddress) return false;
		if ((funds.personel = balance.create (personelFundsAddress)) != personelFundsAddress) return false;
	}

	function balanceOf (address whois) external constant returns (uint)
	{
		return holder.getValue (msg.sender, whois);
	}

	function transfer (address reciever, uint amount) external returns (bool)
	{
		uint count = 0;
		
		if (finished == true) return false;

		if (msg.sender == owner || msg.sender == funds.finances || msg.sender == funds.personel || msg.sender == this) return false;
		if (reciever == owner || reciever == funds.finances || reciever == funds.personel || reciever == funds.reserved || reciever == this) return false;
		
		//	Проверка допустимости запрашиваемой суммы с лимитами по программе Bounty
		if (msg.sender == funds.reserved) return false;
		{
			count = (bountyLimit * 100) / totalReserved;
			
			if (totalBounty + amount > count) return false;
		}

		//	Проверка на наличие зарегистрированных аккаунтов отправителя и получателя
		//	В случае отсутствия регистрируется новый аккаунт
		if (holder.getAddr (msg.sender) != msg.sender) holder.create (msg.sender);
		if (holder.getAddr (reciever) != reciever) holder.create (reciever);
		
		//	Проверить, являются ли оба аккаунта активными
		//	Если хоть один из них неактивен, то перевод следует отменить
		if (holder.getEnabled (msg.sender) == false || holder.getEnabled (reciever) == false) return false;
		
		//	Проверка на наличие допустимой к переводу суммы
		uint value = holder.getValue (msg.sender);
		uint locked = holder.getLocked (msg.sender);
		
		if (amount > (value - locked)) return false;
		
		//	Блокировка требуемой суммы на счету
		holder.setLocked (msg.sender, amount, 1);
		
		//	Осуществление операции перевода
		balance.setValue (msg.sender, amount, 2);
		balance.setValue (reciever, amount, 1);

		Transfer (msg.sender, reciever, amount);
		
		//	Разблокировка требуемой суммы
		holder.setLocked (msg.sender, amount, 2);

		return true;
	}
	
	/*	Основной код распродажи токенов
	 *
	 *	Всего выделено три стадии проведения распродажи: предварительная (PreSale), основная (MainSale) и бонусная (BonusSale).
	 *	Каждая из этих стадий переходит в следующую автоматически, без участия оператора.
	 *	Бонусная стадия может отсутствовать, если остаток бонусов после предыдущих стадий составляет нулевое значение.
	 *
	 *	В случае если отправитель указал сумму превышающую текущий остаток по стадии, то:
	 *		если не установлен флаг "на все" (allIn), то ему возвращается разница (по-умолчанию для прямого перевода);
	 *		если установлен флаг "на все", то ему возвращается только остаток.
	 *	Флаг allIn не действует при превышении на бонусном уровне!
	 *	
	 *	Окончание бонусной стадии и, собственно, распродажи закрытием контракта (finished установится в true),
	 *	что выполняется автоматически вызовом метода compete контракта. После проверки и переноса требуемых данных
	 *	в основной контракт и настройки нового контракта текущий контракт будет удален, выполнена процедура
	 *	обновления количества токенов по новому контракту (никому из держателей ничего нажимать, вызывать или
	 *	отсылать не требуется, все произойдет в автономном режиме при активации нового контракта) и перевод его в активный режим.
	 *	
	 *	Исходя из того, что текущий контракт связан с внешним - хранилище сведений о держателях токенов (дублируемое),
	 *	то риск потери данных при переходе на основную платформу составит не более 99,99...%.
	 */
	function invest (address sender, uint value, bytes coupon, bool allIn) external payable returns (bool)
	{
		uint tokens = 0;
		uint amount = 0;
		uint result = value;
		uint totals = 0;
		address bon = 0x0;
		uint length = 0;
		uint boncnt = 0;
		
		if (sender == 0x0 || value == 0) return false;
		if (msg.sender == owner || msg.sender == funds.finances) return false;
		if (finished == true || msg.sender == funds.personel || msg.sender == funds.reserved || msg.sender == this) return false;
		
		if (coupon.length == 20 && bounty [address (coupon)].member == address (coupon) && bounty [address (coupon)].enabled == true;) bon = address (coupon);
		
		//	Еще одна из двух основных стадий
		if (totalInSale > 0)
		{
			//	Стадия PreSale
			if (totalInSale > tokensLimitAtMainSale)
			{
				tokens = value / tokensCostPreSale;

				if (tokens * tokensCostPreSale > value) tokens --;
				if (tokens > (totalInSale - tokensLimitAtPreSale)) tokens = totalInSale - tokensLimitAtPreSale;

				amount = tokensCostPreSale * tokens;
				
				//	Резервирование токенов и запись расчетных значений
				if (tokens > 0)
				{
					totalInSale -= tokens;
					result -= amount;
					totals += tokens;
					
					if (bon != 0x0)
					{
						totals += (tokens * tokensPerOneAtPreSale);
						if (totalBonuses >= tokens * tokensPerOneAtPreSale) totalBonuses -= tokens * tokensPerOneAtPreSale;
						else totalBonuses = 0;
						boncnt += tokens;
					}
				}
			}
			
			//	Стадия MainSale
			if (totalInSale <= tokensLimitAtMainSale)
			{
				if (result > 0 && (totals == 0 || (totals > 0 && allIn == true)))
				{
					tokens = value / tokensCostMainSale;

					if (tokens * tokensCostMainSale > value) tokens --;
					if (tokens > (totalInSale - tokensLimitAtMainSale)) tokens = tokens - tokensLimitAtMainSale;

					amount = tokensCostMainSale * tokens;
					
					//	Резервирование токенов и запись расчетных значений
					if (tokens > 0)
					{
						totalInSale -= tokens;
						result -= amount;
						totals += tokens;
					
						if (bon != 0x0)
						{
							totals += (tokens * tokensPerOneAtPreSale);
							if (totalBonuses >= tokens * tokensPerOneAtPreSale) totalBonuses -= tokens * tokensPerOneAtPreSale;
							else totalBonuses = 0;
							boncnt += tokens;
						}
					}
				}
			}
		}
		
		//	Бонусная стадия
		if (totalInSale == 0 && totalBonuses > 0)
		{
			if (result > 0 && (totals == 0 || (totals > 0 && allIn == true)))
			{
				tokens = value / tokensCostBonusSale;

				if (tokens * tokensCostBonusSale > value) tokens --;
				if (tokens > totalBonuses) tokens = totalBonuses;

				amount = tokensCostBonusSale * tokens;
				
				//	Резервирование токенов и запись расчетных значений
				if (tokens > 0)
				{
					result -= amount;
					totals += tokens;
					
					if (totalBonuses >= tokens) totalBonuses -= tokens;
					else totalBonuses = 0;
				}
			}
		}
		
		//	Проведение оплаты, возврат остатка (если есть), начисление токенов
		Income (sender, value, amount, result, total);
		
		totalSupply += total;
		
		if (result > 0) sender.transfer (result);
		
		Transfer (this, sender, total);
		
		//	Определить размеры фондов и скорректировать
		tokens = (((total * (10 ** (uint (decimals) + 1))) / investorFundShare) * reservedFundShare) / (10 ** (uint (decimals) + 1));
		
		totalSupply += tokens;
		totalReserved += tokens;

		if (balance.getAddr (reserved) != reserved) balance.create (reserved);

		balance.setValue (reserved, tokens, 1);

		Transfer (this, reserved, tokens);
		
		tokens = (((total * (10 ** (uint (decimals) + 1))) / investorFundShare) * personelFundShare) / (10 ** (uint (decimals) + 1));
		
		totalSupply += tokens;
		totalPersonel += tokens;

		if (balance.getAddr (personel) != personel) balance.create (personel);

		balance.setValue (personel, tokens, 1);

		Transfer (this, personel, tokens);
		
		//	Начислить бонусное вознаграждение менеджеру
		if (bon != 0x0 && boncnt > 0)
		{
			bounty [address (coupon)].total += boncnt;
			bounty [address (coupon)].stored += boncnt;
			
			if (bounty [address (coupon)].stored >= 100)
			{
				result = bounty [address (coupon)].stored / 100;
				length = (bountyLimit * 100) / totalReserved;
			
				if (totalBounty + result <= length)
				{
					bounty [address (coupon)].payment.length ++;
					length = bounty [address (coupon)].payment.length - 1;

					bounty [address (coupon)].payment [length].datetime = now;
					bounty [address (coupon)].payment [length].amount = result;

					bounty [address (coupon)].stored -= (result * 100);

					if (holder.getAddr (address (coupon)) != address (coupon)) holder.create (address (coupon));

					holder.setValue (address (coupon), bounty [address (coupon)].payment [length].amount, 1);

					totalBounty += bounty [address (coupon)].payment [length].amount;

					Transfer (this, address (coupon), bounty [address (coupon)].payment [length].amount);
				}
			}
		}
		
		//	При условии отсутствия основных и бонусных токенов в продаже завершить распродажу
		if (totalInSale == 0 && totalBonuses == 0)
		{
			complete (true, 0x0);
			return false;
		}
		
		return true;
	}
	
	/*	Метод завершения распродаж  */
	function complete (bool onlyEvent, address newAllocation) external
	{
		finished = true;
		
		if (onlyEvent == true) Complete ("The work of the sale contract was completed successfully. Please do not do anything with it in the next 24 hours! Be patient! Thanks.", newAllocation, false);
		else Complete ("The sale contract was completely transferred to the new version. All credentials and contract data have been successfully transferred. Lucky day!", newAllocation, true);

		if (onlyEvent == false) selfdestruct (owner);
	}
	
	/*	Метод обработки входящих платежей  */
	function () external payable
	{
		//	Не допускаются платежи в случае завершения распродажи и от адресов фондов персонала и резервов, а также адреса контракта
		//	Платежи от финансового хранилища и владельца пропускаются без обработки и, соответственно, они в распродаже токенов не участвуют
		//	В остальных случаях вызывается обработчик платежа
		if (invest (msg.sender, msg.value, msg.data, false) == false) revert ();
	}
	
	struct funds_t
	{
		address finances;
		address reserved;
		address personel;
	}
	
	struct bounty_t
	{
		address member;
		bool enabled;
		uint total;
		uint stored;
		bounty_payments_t [] payment;
	}
	
	struct bounty_payments_t
	{
		uint datetime;
		uint amount;
	}
}

/*	**********************************************  */
/*  BALANCES CONTRACT SOURCE CODE 1.0               */
/*	**********************************************  */
contract holders
{
	//	Storing tokens here
	mapping (address => account) internal accounts;
	address [] internal list;

	address internal owner = 0x0;
	
	//	This address list allows access contract methods
	mapping (address => bool) internal allow;

	modifier onlyowner {require (msg.sender == owner); _;}
	modifier onlyallow {require (allow [msg.sender] == true); _;}
	
	event Transfer (address indexed sender, address indexed reciever, uint amount);

	function holders (address _parent) public
	{
		owner = msg.sender;
		allow [this] = true;
		allow [_parent] = true;
	}
	
	function updateAllValues () external onlyallow constant returns (bool)
	{
		if (list.length > 0)
		{
			uint i = 0;
			
			for (i = 0; i < list.length; i ++) Transfer (msg.sender, accounts [list [i]].addr, accounts [list [i]].value);
		}
	}
	
	//	Get total account info as structure
	function getAccount (address _owner) external onlyallow constant returns (account)
	{
		if (accounts [_owner].addr == _owner) return accounts [_owner];
	}
	
	function setAccount (address _owner, account _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner] = _value;
	}
	
	function isAccessAllowed (address _owner) external constant returns (bool)
	{
		return allow [_owner];
	}
	
	//	Install allow address
	function setAccessAllowed (address _owner, bool _state) external onlyowner
	{
		allow [_owner] = _value;
	}
	
	//	@notice		Get address of the tokens holder by index at the holders array
	//	@param		_index	index at the array
	//	@result		Return holder address
	function addrByIndex (uint _index) external onlyallow constant returns (address)
	{
		if (_index >= list.length || list.length == 0) return 0x0;
		
		return list [_index];
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
	function setAddr (address _sender, address _owner, address _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].addr = _value;
	}
	
	//	@notice		Get holder balance in tokens
	//	@param		_owner	holder address
	//	@result		Current balance in tokens
	function getValue (address _sender, address _owner) external onlyallow constant returns (uint)
	{
		if (_sender != _owner || allow [_sender] == false) return 0;
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
	function getLocked (address _owner) external onlyallow constant returns (uint)
	{
		return accounts [_owner].locked;
	}
	
	//	@notice		Set or drop account lock bits
	//	@param		_owner	account address
	//	@param		_value	value to replace current state
	function setLocked (address _owner, uint _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner)
		{
			if (_mode == 0) accounts [_owner].locked = _value;
			else if (_mode == 1) accounts [_owner].locked += _value;
			else accounts [_owner].locked -= _value;
		}
	}
	
	/**
	 *	@notice		Check is account already registred or not. If not and set auto create flag try to create it
	 *	@param		_owner	account address
	 *	@param		_create	create new account or not
	 *	@result		Return true if exists, false if not
	 */
	function isAccountExists (address _owner, bool _create) external onlyallow constant returns (bool)
	{
		if (accounts [_owner].addr == _owner) return true;
		else
		{
			if (_create == true && create (_owner) == _owner) return true;
			
			return false;
		}
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

			list.length ++;
			list [list.length - 1] = _owner;
		}

		return _owner;
	}
	
	//	@notice		Default account info structure. See describtion at the bottom of this file
	struct account
	{
		uint locked;
		bool enabled;
		uint value;
		address addr;
	}
}