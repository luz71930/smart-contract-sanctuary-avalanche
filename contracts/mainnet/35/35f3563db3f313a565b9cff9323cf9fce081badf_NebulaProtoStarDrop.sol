/**
 *Submitted for verification at snowtrace.io on 2022-09-04
*/

/**
 *Submitted for verification at snowtrace.io on 2022-08-30
*/

/**
 *Submitted for verification at snowtrace.io on 2022-08-30
*/

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor() {
        _transferOwnership(_msgSender());
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
library nebuLib {
		function addressInList(address[] memory _list, address _account) internal pure returns (bool){
			for(uint i=0;i<_list.length;i++){
				if(_account == _list[i]){
					return true;
				}
			}
			return false;
		}
		
		function mainBalance(address _account) internal view returns (uint256){
			uint256 _balance = _account.balance;
			return _balance;
		}
		function getMultiple(uint256 _x,uint256 _y)internal pure returns(uint256){
			uint256 Zero = 0;
			if (_y == Zero || _x == Zero || _x > _y){
				return Zero;
			}
			uint256 z = _y;
			uint256 i = 0;
			while(z >= _x){
				z -=_x;
				i++;			
			}
			return i;
		}
}
abstract contract feeManager is Context {
    function isInsolvent(address _account,string memory _name) external virtual view returns(bool);
    function simpleQuery(address _account) external virtual returns(uint256);
    function createProtos(address _account,string memory _name) external virtual;
    function collapseProto(address _account,string memory _name) external virtual;
    function payFee(uint256 _intervals,address _account) payable virtual external;
    function changeName(string memory _name,string memory new_name) external virtual;
    function viewFeeInfo(address _account,string memory _name) external virtual view returns(uint256,uint256,bool,bool,bool,bool);
    function getPeriodInfo() external  virtual returns (uint256,uint256,uint256);
    function getAccountsLength() external virtual view returns(uint256);
    function accountExists(address _account) external virtual view returns (bool);
    function MGRrecPayFees(address _account) external virtual;
    }
abstract contract ProtoManager is Context {
    function addProto(address _account, string memory _name) external virtual;
    function getProtoAccountsLength() external virtual view returns(uint256);
    function getProtoAddress(uint256 _x) external virtual view returns(address);
    function getProtoStarsLength(address _account) external virtual view returns(uint256);
}
abstract contract dropMGR is Context {
	struct DROPS{
	uint256 amount;
	}
	mapping(address => DROPS) public airdrop;
	address[] public protoOwners;
}
abstract contract overseer is Context {
	 function getMultiplier(uint256 _x) external virtual returns(uint256);
	 function getBoostPerMin(uint256 _x) external virtual view returns(uint256);
	 function getRewardsPerMin() external virtual view returns (uint256);
	 function getCashoutRed(uint256 _x) external virtual view returns (uint256);
	 function getNftTimes(address _account, uint256 _id,uint256 _x) external virtual view returns(uint256);
	 function isStaked(address _account) internal virtual returns(bool);
	 function getNftAmount(address _account, uint256 _id) external view virtual returns(uint256);
	 function getFee() external virtual view returns(uint256);
	 function getModFee(uint256 _val) external virtual view returns(uint256);
	 function getNftPrice(uint _val) external virtual view returns(uint256);
	 function getEm() external virtual view returns (uint256);  
} 
contract NebulaProtoStarDrop is Ownable{
	using SafeMath for uint256;
	struct DROPS{
	uint256 dropped;
	uint256 claimed;
	
	}
	mapping(address => DROPS) public airdrop;
	address[] public Managers;
	address[] public protoOwners;
	address[] public transfered; 
	address payable treasury;
	address oldDrop = 0x93363e831b56E6Ad959a85F61DfCaa01F82164bb;
	ProtoManager public protoMGR;
	feeManager public feeMGR;
	overseer public over;
	modifier managerOnly() {require(nebuLib.addressInList(Managers,msg.sender)== true); _;}
	constructor(address[] memory _addresses,address payable _treasury){
		feeMGR = feeManager(_addresses[0]);
		protoMGR = ProtoManager(_addresses[1]);
		over = overseer(_addresses[2]);
		treasury = _treasury;
		Managers.push(owner());
		transferOldDrops();

	}
	function payFee(uint256 _intervals) payable external {
		address _account = msg.sender;
		uint256 sent = msg.value;
		uint256 fee = over.getFee();
		require(feeMGR.simpleQuery(_account) > 0,"doesnt look like you owe any fees, you're either maxed out, or i glitched :0");
		require(feeMGR.simpleQuery(_account) >= _intervals,"looks like youre attempting to overpay, less intervals next time please");
		require(sent >= fee.mul(_intervals),"you have not sent enough to pay the amount of fees you are seeking to pay");
		uint256 returnBalance = sent;
		for(uint i=0;i<_intervals;i++){
		    	treasury.transfer(fee);
		    	uint256 returnBalance = sent - fee;
			feeMGR.MGRrecPayFees(_account);	
		}
		if(returnBalance > 0){
			payable(_account).transfer(returnBalance);
		}
	}
	
	function createProto(string memory _name) payable external {
		address _account = msg.sender;
		if(nebuLib.addressInList(protoOwners,_account) == false){
			protoOwners.push(_account);
		}
		DROPS storage drop = airdrop[_account];
		uint256 left = drop.dropped - drop.claimed;
		require(left > 0,"you have already claimed all of your protos");
		uint256 sent = msg.value;
		uint256 fee = over.getFee();
	    	require(sent >= fee,"you have not sent enough to pay a fee");
	    	treasury.transfer(fee);
	    	uint256 returnBalance = sent - fee;
        	if(returnBalance > 0){
			payable(_account).transfer(returnBalance);
		}
		feeMGR.MGRrecPayFees(_account);
		protoMGR.addProto(_account,_name);
		drop.claimed += 1;
		
	}
	function addAirDrops(address[] memory _accounts,uint256[] memory _amounts,bool _neg) external managerOnly() {
		for(uint i=0;i<_accounts.length;i++){
			DROPS storage drop = airdrop[_accounts[i]];
			if(_neg == false){
				drop.dropped += _amounts[i];
			}else{
				if(drop.dropped != 0){
					drop.dropped -= _amounts[i];
				}
			}
		}
	}
	function transferOldDrops() internal {
	
		uint length = protoMGR.getProtoAccountsLength();
		

		for(uint i=0;i<length;i++){
		
			address _account =protoMGR.getProtoAddress(uint256(i));
			
			if(nebuLib.addressInList(transfered,_account) == false){
			
				DROPS storage drop = airdrop[_account];
					
    				drop.claimed += protoMGR.getProtoStarsLength(protoMGR.getProtoAddress(uint256(i)));
    				drop.dropped += protoMGR.getProtoStarsLength(protoMGR.getProtoAddress(uint256(i)));
    				
			}
			
		}
		
	}
	function updateManagers(address newVal) external onlyOwner {
    		if(nebuLib.addressInList(Managers,newVal) ==false){
        		Managers.push(newVal); //token swap address
        	}
    	}
    	function updateProtoManager(address newVal) external onlyOwner {
    		address _protoManager = newVal;
    		protoMGR = ProtoManager(_protoManager);
    	}
	function updateFeeManager(address newVal) external onlyOwner {
		address _feeManager = newVal;
    		feeMGR = feeManager(_feeManager);
    	}
    	function updateTreasury(address payable newVal) external onlyOwner {
    		treasury = newVal;
    	}
    	function updateOverseer(address newVal) external onlyOwner {
    		address _overseer = newVal;
    		over = overseer(_overseer);
    	}
}