pragma solidity ^0.4.18;

interface recipientToken {function receiveApproval (address _from, uint256 _value, address _token, bytes _extraData) public;}

contract sale
{
	/*  Основные константы контракта  */
	string public name 	= 'Virtuality Systems';
	string public symbol 	= 'VS';
	uint8  public decimals = 2;
	string public version 	= '1.2 (Strict Edition) - Sale Stage';
	
	uint reservedFundShare = 1000;										//	Доля резервного фонда в общем объеме выпущенных токенов
	uint personelFundShare = 1000;										//	Доля фонда компании в общем объеме выпущенных токенов
	uint investorFundShare = 8000;										//	Доля инвесторов в общем объеме выпущенных токенов
	
	uint bountyLimit = 1000;											//	Лимит отчислений на программу Bounty
	
	uint tokensSaleLimit = 3000000 * (10 ** uint (decimals));			//	Лимит токенов на распродаже (без учета бонусных токенов)
	uint tokensBonusLimit = 5000000 * (10 ** uint (decimals));			//	Лимит бонусных токенов
	
	uint tokensLimitAtPreSale = 1000000 * (10 ** uint (decimals));		//	Лимит токенов для распродажи на этапе PreSale
	uint tokensLimitAtMainSale = 2000000 * (10 ** uint (decimals));		//	Лимит токенов для распродажи на этапе MainSale
	
	uint tokensCostPreSale = 10000000000000000;							//	Стоимость токена (0,0100 ETH) на этапе PreSale (предварительная продажа)
	uint tokensCostMainSale = 20000000000000000;						//	Стоимость токена (0,0200 ETH) на этапе MainSale (основная продажа)
	uint tokensCostBonusSale = 1000000000000000;						//	Стоимость токена (0,0010 ETH) на этапе распродажи бонусов BonusSale
	
	//	Бонусные токены на этапах PreSale и MainSale
	//	начисляются только при указании покупателем
	//	кода, выданного менеджером по продажам
	uint tokensPerOneAtPreSale = 4;										//	Количество бонусных токенов за приобретенную единицу на этапе PreSale
	uint tokensPerOneAtMainSale = 2;									//	Количество бонусных токенов за приобретенную единицу на этапе MainSale
	uint tokensPerOneAtBonusSale = 1;									//	Количество бонусных токенов за приобретенную единицу на этапе BonusSale
	
	address public owner = 0x0;											//	Адрес аккаунта, с которого был установлен контракт
	
	holders internal holder;											//	Расширение: балансы держателей токенов (balances, v. 1.0+)
	
	mapping (uint => bounty_t) internal bounty;							//	Хранение сведений об участниках баунти-програм
	uint internal lastCoupon = 0;										//	Участники Bounty программы должны быть зарегистрированы
	
	bool public finished = false;
	
	//	Эту группу данных нужно будет перенести в основной контракт
	//	после завершения распродажи токенов
	funds_t internal funds;												//	Адреса хранилища фондов компании
	
	uint public totalInSale = tokensSaleLimit;							//	Количество токенов в распродаже на текущий момент (остаток)
	uint public totalBonuses = tokensBonusLimit;						//	Остаток бонусных токенов на текущий момент
	uint public totalSupply = 0;										//	Общее число выпущенных токенов: распродажа + фонды
	uint public totalBounty = 0;										//	Общее число выданных токенов по программе Bounty
	uint public totalReserved = 0;										//	Количество токенов (за вычетом выплаченных по программе Bounty) в резервном фонде
	uint public totalPersonel = 0;										//	Количество токенов, зарезервированных на персонал
	
	modifier onlyowner {require (msg.sender == owner); _;}
	
	event Complete (string message, address where, uint supplied bool deleted);
	event Income (address from, uint income, uint amount, uint refund, uint tokens);
	event Transfer (address indexed sender, address indexed reciever, uint amount);
	
	function sale () public
	{
		owner = msg.sender;
	}
	
	/*	Метод инициализации наиболее важных параметров контракта
	 *
	 *	Параметры метода
	 *
	 *	balanceAddress			Адрес хранилища данных о держателях токенов и их количестве.
	 *							Необходим для безболезненного перехода на основной контракт
	 *							по завершению распродажи токенов и в целях дополнительной
	 *							безопасности (дублируется)
	 *	financesFundsAddress	Основной адрес для хранения и дальнейшего распределения ETH
	 *	reservedFundsAddress	Адрес резервного фонда. Объем допустимого вывода из резервного
	 *							фонда строго лимитирован (bountyLimit/100%) и предназначен для
	 *							оплаты участников баунти-программы. Остальная часть может быть
	 *							выведена на биржу либо продана действующим держателям токенов
	 *							только в случае особой необходимости!
	 *	personelFundsAddress	Адрес фонда распределения токенов для персонала. Распределение
	 *							токенов сотрудников полностью запрещено до окончательного
	 *							завершения проекта. В этом случае разблокировка происходит автоматически.
	 */
	function initialize (address balanceAddress, address financesFundsAddress, address reservedFundsAddress, address personelFundsAddress) public onlyowner returns (bool)
	{
		//	Метод не может быть выполнен, если установлен флаг о завершении распродажи токенов
		if (finished == true) return false;
		
		//	Указание адреса контракта-хранилища балансов держателей токенов ОБЯЗАТЕЛЬНО,
		//	но может быть установлено позднее. Без его указания этот метод завершится критической
		//	ошибкой, а контракт будет в нерабочем состоянии
		holder = holders (balanceAddress);
		
		if ((funds.finances = holder.create (financesFundsAddress)) != financesFundsAddress) return false;
		if ((funds.reserved = holder.create (reservedFundsAddress)) != reservedFundsAddress) return false;
		if ((funds.personel = holder.create (personelFundsAddress)) != personelFundsAddress) return false;
	}

	function balanceOf (address whois) external constant returns (uint)
	{
		return holder.getValue (msg.sender, whois);
	}

	function transfer (address reciever, uint amount) external returns (bool)
	{
		uint count = 0;
		
		if (finished == true) return false;

		if (msg.sender == owner || msg.sender == funds.finances || msg.sender == funds.personel || msg.sender == address (this)) return false;
		if (reciever == owner || reciever == funds.finances || reciever == funds.personel || reciever == funds.reserved || reciever == address (this)) return false;
		
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
		uint value = holder.getValue (msg.sender, msg.sender);
		uint locked = holder.getLocked (msg.sender);
		
		if (amount > (value - locked)) return false;
		
		//	Блокировка требуемой суммы на счету
		holder.setLocked (msg.sender, amount, 1);
		
		//	Осуществление операции перевода
		holder.setValue (msg.sender, amount, 2);
		holder.setValue (reciever, amount, 1);

		Transfer (msg.sender, reciever, amount);
		
		//	Разблокировка требуемой суммы
		holder.setLocked (msg.sender, amount, 2);

		return true;
	}
	
	/*	Основной код распродажи токенов (выполняется посредством вызова метода ниже)
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
	function invest (address sender, uint value, bytes couponId, bool allIn) external payable returns (bool)
	{
		uint tokens = 0;
		uint amount = 0;
		uint result = value;
		uint totals = 0;
		uint coupon = 0;
		uint length = 0;
		uint boncnt = 0;
		
		if (sender == 0x0 || value == 0) return false;
		if (msg.sender == owner || msg.sender == funds.finances) return false;
		if (finished == true || msg.sender == funds.personel || msg.sender == funds.reserved || msg.sender == address (this)) return false;
		
		if (couponId.length != 20 || (coupon = getCoupon (couponId)) == 0 || bounty [coupon].enabled == false) coupon = 0;
		
		//	Еще одна из двух основных стадий
		if (totalInSale > 0)
		{
			//	Стадия PreSale
			if (totalInSale > tokensLimitAtMainSale)
			{
				tokens = (value * (10 ** uint (decimals))) / tokensCostPreSale;

				if (tokens * tokensCostPreSale > value) tokens --;
				if (tokens > (totalInSale - tokensLimitAtMainSale)) tokens = totalInSale - tokensLimitAtMainSale;

				amount += tokensCostPreSale * tokens;
				
				//	Резервирование токенов и запись расчетных значений
				if (tokens > 0)
				{
					totalInSale -= tokens;
					result -= amount;
					totals += tokens;
					
					if (bon != 0x0)
					{
						totals += ((tokens * tokensPerOneAtPreSale) - tokens);
						if (totalBonuses >= tokens * tokensPerOneAtPreSale) totalBonuses -= tokens * tokensPerOneAtPreSale;
						else totalBonuses = 0;
						boncnt += tokens * tokensPerOneAtPreSale;
					}
				}
			}
			
			//	Стадия MainSale
			if (totalInSale <= tokensLimitAtMainSale)
			{
				if (result > 0 && (totals == 0 || (totals > 0 && allIn == true)))
				{
					tokens = (result * (10 ** uint (decimals))) / tokensCostMainSale;

					if (tokens * tokensCostMainSale > result) tokens --;
					if (tokens > totalInSale) tokens = totalInSale;

					amount += tokensCostMainSale * tokens;
					
					//	Резервирование токенов и запись расчетных значений
					if (tokens > 0)
					{
						totalInSale -= tokens;
						result -= amount;
						totals += tokens;
					
						if (bon != 0x0)
						{
							totals += ((tokens * tokensPerOneAtMainSale) - tokens);
							if (totalBonuses >= tokens * tokensPerOneAtPreSale) totalBonuses -= tokens * tokensPerOneAtMainSale;
							else totalBonuses = 0;
							boncnt += tokens * tokensPerOneAtMainSale;
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
				tokens = (result * (10 ** uint (decimals))) / tokensCostBonusSale;

				if (tokens * tokensCostBonusSale > result) tokens --;
				if (tokens > totalBonuses) tokens = totalBonuses;

				amount += tokensCostBonusSale * tokens;
				
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
		Income (sender, value, amount, result, totals);
		
		totalSupply += totals;
		
		if (result > 0) sender.transfer (result);
		
		Transfer (this, sender, totals);
		
		//	Определить размеры фондов и скорректировать
		tokens = (((totals * (10 ** (uint (decimals) + 1))) / investorFundShare) * reservedFundShare) / (10 ** (uint (decimals) + 1));
		
		totalSupply += tokens;
		totalReserved += tokens;

		if (holder.getAddr (funds.reserved) != funds.reserved) holder.create (funds.reserved);

		holder.setValue (funds.reserved, tokens, 1);

		Transfer (this, funds.reserved, tokens);
		
		tokens = (((totals * (10 ** (uint (decimals) + 1))) / investorFundShare) * personelFundShare) / (10 ** (uint (decimals) + 1));
		
		totalSupply += tokens;
		totalPersonel += tokens;

		if (holder.getAddr (funds.personel) != funds.personel) holder.create (funds.personel);

		holder.setValue (funds.personel, tokens, 1);

		Transfer (this, funds.personel, tokens);
		
		//	Начислить бонусное вознаграждение менеджеру
		if (coupon != 0 && boncnt > 0)
		{
			bounty [coupon].total += boncnt;
			bounty [coupon].stored += boncnt;
			
			if (bounty [coupon].stored >= 100)
			{
				result = bounty [coupon].stored / 100;
				length = (bountyLimit * 100) / totalReserved;
			
				if (totalBounty + result <= length)
				{
					bounty [coupon].payments += result;
					bounty [coupon].stored -= (result * 100);

					if (holder.getAddr (bounty [coupon].member) != bon) holder.create (bounty [coupon].member);

					holder.setValue (bounty [coupon].member, result, 1);

					totalBounty += result;
					totalSupply += result;

					Transfer (this, bounty [coupon].member, result);
				}
			}
		}
		
		if (this.balance > 0) owner.transfer (this.balance);
		
		//	При условии отсутствия основных и бонусных токенов в продаже завершить распродажу
		if (totalInSale == 0 && totalBonuses == 0)
		{
			this.complete (true, 0x0);
			return false;
		}
		
		return true;
	}
	
	/*	Метод завершения распродаж  */
	function complete (bool onlyEvent, address newAllocation) external
	{
		finished = true;
		
		if (onlyEvent == true) Complete ("The work of the sale contract was completed successfully. Please do not do anything with it in the next 24 hours! Be patient! Thanks.", newAllocation, totalSupply, false);
		else Complete ("The sale contract was completely transferred to the new version. All credentials and contract data have been successfully transferred. Lucky day!", newAllocation, totalSupply, true);

		if (onlyEvent == false) selfdestruct (owner);
	}
	
	/*	Преобразование bytes в address  */
	function getCoupon (bytes extra) internal pure returns (uint)
	{
		uint result;
		uint mul = 1;
		uint i = 0;
		
		if (extra.length != 20) return 0;
		
		for (i = 20; i > 0; i --)
		{
			result += uint8 (extra [i - 1]) * mul;
			mul = mul * 256;
		}
		
		return result;
	}
	
	function addCoupon (bytes id, address manager) external onlyowner
	{
		if (bounty [i].member == 0x0) bounty [id] = bounty_t (manager, true, 0, 0, 0);
	}
	
	/*	Метод обработки входящих платежей непосредственной отправкой ETH на адрес этого контракта  */
	function () external payable
	{
		//	Не допускаются платежи в случае завершения распродажи и от адресов фондов персонала и резервов, а также адреса контракта
		//	Платежи от финансового хранилища и владельца пропускаются без обработки и, соответственно, они в распродаже токенов не участвуют
		//	В остальных случаях вызывается обработчик платежа
		if (this.invest (msg.sender, msg.value, bytes (msg.data), false) == false) revert ();
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
		uint payments;
	}
}

/*	**********************************************  */
/*  BALANCES CONTRACT SOURCE CODE 1.0               */
/*	**********************************************  */
contract holders
{
	mapping (address => account) internal accounts;
	address [] internal list;

	address internal owner = 0x0;
	
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
	
	function updateAllValues () external onlyallow returns (bool)
	{
		if (list.length > 0)
		{
			uint i = 0;
			
			for (i = 0; i < list.length; i ++) Transfer (msg.sender, accounts [list [i]].addr, accounts [list [i]].value);
		}
	}
	
	function setAccessAllowed (address _owner, bool _state) external onlyowner
	{
		allow [_owner] = _state;
	}
	
	function getAddr (address _owner) external onlyallow constant returns (address)
	{
		return accounts [_owner].addr;
	}
	
	function setAddr (address _owner, address _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].addr = _value;
	}
	
	function getValue (address _sender, address _owner) external onlyallow constant returns (uint)
	{
		if (_sender != _owner || allow [_sender] == false) return 0;
		return accounts [_owner].value;
	}
	
	function setValue (address _owner, uint _value, uint _mode) external onlyallow
	{
		if (accounts [_owner].addr == _owner)
		{
			if (_mode == 0) accounts [_owner].value = _value;
			else if (_mode == 1) accounts [_owner].value += _value;
			else accounts [_owner].value -= _value;
		}
	}
	
	function getEnabled (address _owner) external onlyallow constant returns (bool)
	{
		return accounts [_owner].enabled;
	}
	
	function setEnabled (address _owner, bool _value) external onlyallow
	{
		if (accounts [_owner].addr == _owner) accounts [_owner].enabled = _value;
	}
	
	function getLocked (address _owner) external onlyallow constant returns (uint)
	{
		return accounts [_owner].locked;
	}
	
	function setLocked (address _owner, uint _value, uint _mode) external onlyallow
	{
		if (accounts [_owner].addr == _owner)
		{
			if (_mode == 0) accounts [_owner].locked = _value;
			else if (_mode == 1) accounts [_owner].locked += _value;
			else accounts [_owner].locked -= _value;
		}
	}
	
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
	
	struct account
	{
		uint locked;
		bool enabled;
		uint value;
		address addr;
	}
}