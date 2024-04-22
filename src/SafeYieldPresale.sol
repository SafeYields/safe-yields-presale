pragma solidity "0.8.21";

contract SafeYieldPresale {
    IERC20 public safeToken;
    IERC20 public usdcToken;

    uint256 public maxSupply;
    uint256 public totalSold;
    uint256 public minAllocationPerWallet;
    uint256 public maxAllocationPerWallet;
    uint256 public tokenPrice; // Price per token in USDC

    mapping(address => uint256) public investments;
    mapping(bytes32 => uint256) public referrerVolume;


    event TokensPurchased(address indexed buyer, uint256 usdcAmount, address referrer);
    event TokensClaimed(address indexed claimer, uint256 tokenAmount);

    constructor(address _safeToken, address _usdcToken, uint256 _maxSupply, uint256 _minAllocationPerWallet, uint256 _maxAllocationPerWallet;, uint256 _tokenPrice) {
        safeToken = IERC20(_safeToken);
        usdcToken = IERC20(_usdcToken);
        maxSupply = _maxSupply;
        minAllocationPerWallet = _minAllocationPerWallet;
        maxAllocationPerWallet; = _maxAllocationPerWallet;;
        tokenPrice = _tokenPrice;
    }

    
    function setAllocations(uint256 _min, uint256 _max) public onlyOwner {
        minAllocationPerWallet = _min;
        maxAllocationPerWallet; = _max;
    }


    ///!@q are withdrawals allowed before the presale ends? / all tokens are sold?
    function withdrawUSDC() public onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        usdcToken.transfer(owner(), balance);
    }
}
