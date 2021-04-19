pragma solidity ^0.7.0;


contract ST1Token {

  string private constant _symbol = 'ST1';
  string private constant _name = 'ST1 Token';
  uint8 private constant _rate = 10;
  uint8 private constant _reward_rate = 10; // in term of percents, i.e., 10%
  uint256 private _totalSupply;
  mapping (address => uint256) private _balances;
  mapping(address => mapping (address => uint256)) private _allowedToSpend;
   

    struct Provider{
        uint256 balance;
        uint256 collateral;
        uint256 reward;
    }
  
  address[] _providers_ids;
  mapping (address => Provider) private _providers;
  mapping (address => bool) private _provider_exists;

  address public _owner; 

  event Approval(address indexed owner, address indexed spender, uint amount);
  event Transfer(address indexed from, address indexed to, uint amount);
  event ST1Minted (address indexed from, address indexed to, uint256 minted_coints);
  event SendCollateral(address indexed from, address indexed to, uint amount);

  constructor() {
    _owner = msg.sender;
  }



    modifier limit_supply(){
      require(msg.value * _rate + _totalSupply <= 1000000,
        "cannot invoke function as the total supply of ST1 is limited to 1M tokens"
        );
        _;
    }

  function provider_exists(address provider) internal view returns (bool){
        return _provider_exists[provider];
    }

    function add_provider(address provider) public{
        require(provider_exists(provider) ==  false, "provider is already exists");
        _providers_ids.push(provider);
        _provider_exists[provider] = true;
  }

     

    function name() public view virtual  returns (string memory) {
        return _name;
    }

    function symbol() public view virtual  returns (string memory) {
        return _symbol;
    }

  function approve(address spender, uint256 amount)
    external
    returns (bool)
  {
    require(amount > 0, 'Can not approve an amount <= 0');
    require(amount <= _balances[msg.sender], 'The amount is greater than senders balance');

    _allowedToSpend[msg.sender][spender] += amount;  // NOTE overflow

    return true;
  }

  // Buy tokens with ether, mint and allocate new tokens to the purchaser.
  function buy() public payable limit_supply returns (bool)
  {
    // May not buy with a value of 0
    require(msg.value > 0,  'Cannot buy with a value of <= 0, Token.buy()');

    
    // Compute the amount of tokens to mint
    uint256 new_amount_minted = msg.value * _rate;
    _totalSupply += new_amount_minted;
    // Update the total supply and buyer's balance
    _balances[msg.sender] += new_amount_minted;
    
    emit Transfer(msg.sender, address(this),  msg.value);

    emit ST1Minted (address(0), address(this),  new_amount_minted);
    // Emit events


    return true;
  }

  // Transfer value to another address
  function transfer (
    address _to,
    uint256 _value
  ) external
    returns (bool)
  {
    // Ensure from address has a sufficient balance
    require(_balances[msg.sender] > _value, "not enough tokens to transfer");

    // Update the from and to balances

    _balances[_to] += _value;
    _balances[msg.sender] -= _value;

    // Emit events

    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  // Tranfer on behalf of a user, from one address to another
  function transferFrom(address _from, address _to, uint256 _amount)
    external
    returns (bool)
  {
    require(_amount > 0, 'Cannot transfer amount <= 0, Token.transferFrom()');
    require(_amount <= _balances[_from], 'From account has an insufficient balance, Token.transferFrom()');
    require(_amount <= _allowedToSpend[_from][msg.sender], 'msg.sender has insufficient allowance, Token.transferFrom()');

    _balances[_from] -= _amount; // NOTE underflow
    _balances[_to] += _amount;  // NOTE overflow

    _allowedToSpend[_from][msg.sender] -= _amount;  // NOTE underflow

    emit Transfer(_from, _to, _amount);

    return true;
  }

  // withdraw the ETH held by this contract
  function withdraw(address payable _wallet) external returns(bool) {
    // Confirm only the owner may withdraw
    require(msg.sender == _owner, "only the owner can withdraw");
    _wallet.transfer(address(msg.sender).balance);
    // Transfer the balance of the contract, this, to the wallet
    return true;
  }

  // @return the allowance the owner gave the spender
  function allowance(address owner, address spender)
    external
    view
    returns(uint256)
  {
    return _allowedToSpend[owner][spender];
  }

  // return the address' balance
  function balanceOf(
    address owner
  ) external
   view 
    returns (uint256)
  {
    return _balances[owner];
  }

  function totalSupply()
     public view
    returns (uint256)
  {
    return _totalSupply;
  }

  

  function send_collateral(uint256 amount, address provider) public{
      require(amount >= 10, "Cannot send less than 10 ST1");
      require(amount <= 1000, "Cannot send more than 1000 ST1");
      require(_balances[msg.sender] >= amount, "Sender has not enough ST1 to send");
      _balances[msg.sender] -= amount;
      _providers[provider].collateral  += amount;
      emit SendCollateral(msg.sender, provider, amount);
  }

  function service_payment()
      payable
      public
      limit_supply
      {
        require(msg.value >=1 ether, "not enough ETH for service");
        uint256 minted_coins = msg.value * _rate;
        emit ST1Minted(address(0), address(this), minted_coins);
        _totalSupply += minted_coins; 
        uint256 minted_ST1_per_provider = minted_coins / _providers_ids.length;
        address(0).transfer(1 ether);//burn the ETH
        for (uint i ; i<= _providers_ids.length; i++){
          _providers[_providers_ids[i]].collateral += minted_ST1_per_provider;
          emit Transfer(address(this), _providers_ids[i], minted_ST1_per_provider);
        }
      }

  function calculate_rewards() public{
      uint256 total_reward = address(this).balance * (_reward_rate/100);
      uint256 sum = 0;
      for (uint i ; i<= _providers_ids.length; i++){
        sum += _providers[_providers_ids[i]].collateral;
      } 
      for (uint i ; i<= _providers_ids.length; i++){
        _providers[_providers_ids[i]].reward = 
             total_reward * (_providers[_providers_ids[i]].collateral / sum);
      } 
  }

  function withdraw_reward(uint amount) public{
      require(amount <= _providers[msg.sender].reward, "provider has insufficient amount of reward");
      _providers[msg.sender].reward = 0;
      msg.sender.transfer(amount);
      emit Transfer(address(this), msg.sender, amount);
  }

  function add_token_to_collateral( uint amount) payable public{
            require(provider_exists(msg.sender) ==  true, "provider does not exist");
            require( _providers[msg.sender].balance  >=  amount, "provider does not have enough tokens");     
              _providers[msg.sender].collateral += amount;
             _providers[msg.sender].balance -=   amount;
  }

}