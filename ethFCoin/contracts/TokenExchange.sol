pragma solidity ^0.4.24;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract TokenExchange is Ownable, Pausable {

    /**  
   * @dev Details of each transfer * @param contract_ contract address of ER20 token to transfer * @param to_ receiving account * @param amount_ number of tokens to transfer to_ account * @param failed_ if transfer was successful or not */
    struct Transfer {
        address contract_;
        address to_;
        uint amount_;
        bool failed_;
    }
    /**  
   * @dev a mapping from transaction ID's to the sender address * that initiates them. Owners can create several transactions */
    mapping(address => uint[]) public transactionIndexesToSender;


    /**  
   * @dev a list of all transfers successful or unsuccessful */
    Transfer[] public transactions;

    address public owner;

    /**  
   * @dev list of all supported tokens for transfer * @param string token symbol * @param address contract address of token */
    mapping(bytes32 => address) public tokens;

    ERC20 public ERC20Interface;

    /**  
   * @dev Event to notify if transfer successful or failed * after account approval verified */
    event TransferSuccessful(address indexed from_, address indexed to_, uint256 amount_);

    event TransferFailed(address indexed from_, address indexed to_, uint256 amount_);

    constructor() public {
        owner = msg.sender;
    }
    /**  
   * @dev add address of token to list of supported tokens using * token symbol as identifier in mapping */
    function addNewToken(bytes32 symbol_, address address_) public onlyOwner returns(bool) {
        tokens[symbol_] = address_;

        return true;
    }
    /**  
   * @dev remove address of token we no more support */
    function removeToken(bytes32 symbol_) public onlyOwner returns(bool) {
        require(tokens[symbol_] != 0x0);

        delete (tokens[symbol_]);

        return true;
    }

    
    /**  
   * @dev method that handles transfer of ERC20 tokens to other address * it assumes the calling address has approved this contract * as spender * @param symbol_ identifier mapping to a token contract address * @param to_ beneficiary address * @param amount_ numbers of token to transfer */
    function transferTokens(bytes32 symbol_, address to_, uint256 amount_) public whenNotPaused{
        require(tokens[symbol_] != 0x0);
        require(amount_ > 0);

        address contract_ = tokens[symbol_];
        address from_ = msg.sender;

        ERC20Interface = ERC20(contract_);

        uint256 transactionId = transactions.push(
            Transfer({
                contract_: contract_,
                to_: to_,
                amount_: amount_,
                failed_: true
            })
        );
        transactionIndexesToSender[from_].push(transactionId - 1);

        if (amount_ > ERC20Interface.allowance(from_, address(this))) {
            emit TransferFailed(from_, to_, amount_);
            revert();
        }
        ERC20Interface.transferFrom(from_, to_, amount_);

        transactions[transactionId - 1].failed_ = false;

        emit TransferSuccessful(from_, to_, amount_);
    }
    
    
    function exchangeToken(bytes32 fromSymbol_, bytes32 toSymbol_, address toUser_, uint256 fromAmount_, uint256 toAmount_ ) public whenNotPaused{
        require(tokens[fromSymbol_] != 0x0 && tokens[toSymbol_] != 0x0, "Token Address Error" );
        require(fromAmount_ > 0, "From Amount <= 0");

        address fromToken_ = tokens[fromSymbol_];
        address toToken_ = tokens[toSymbol_];
        address fromUser_ = msg.sender;

        ERC20Interface = ERC20(fromToken_);

        uint256 fromTxID= transactions.push(
            Transfer({
                contract_: fromToken_,
                to_: toUser_,
                amount_: fromAmount_,
                failed_: true
            })
        );
        transactionIndexesToSender[fromUser_].push(fromTxID - 1);

        if (fromAmount_ > ERC20Interface.allowance(fromUser_, address(this))) {
            emit TransferFailed(fromUser_, toUser_, fromAmount_);
            revert("Allowence Error");
        }
        ERC20Interface.transferFrom(fromUser_, toUser_, fromAmount_);

        transactions[fromTxID - 1].failed_ = false;

        ERC20Interface = ERC20(toToken_);

        uint256 toTxID = transactions.push(
            Transfer({
                contract_: toToken_,
                to_: fromUser_,
                amount_: toAmount_,
                failed_: true
            })
        );
        transactionIndexesToSender[toUser_].push(toTxID - 1);

        if (fromAmount_ > ERC20Interface.allowance(toUser_, address(this))) {
            emit TransferFailed(toUser_, fromUser_, toAmount_);
            revert("Allowence Error");
        }
        ERC20Interface.transferFrom(toUser_, fromUser_, toAmount_);
        transactions[toTxID - 1].failed_ = false;

        emit TransferSuccessful(fromUser_, toUser_, fromAmount_);
    }
    /**  
   * @dev allow contract to receive funds */
    function() public payable { }

    /**  
   * @dev withdraw funds from this contract * @param beneficiary address to receive ether */
    function withdraw(address beneficiary) public payable onlyOwner whenNotPaused {
        beneficiary.transfer(address(this).balance);
    }
}