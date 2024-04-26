pragma solidity 0.8.21;
import {Test, console2} from "forge-std/Test.sol";
import {SafeYieldPresale} from "src/SafeYieldPresale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockToken} from "./mocks/MockToken.sol";

contract SafeYieldPresaleTest is Test {
    SafeYieldPresale presale;

    enum PresaleState {
        NotStarted,
        Live,
        Ended
    }

    address public safeToken;
    address public usdcToken;
    uint128 public _maxSupply = 1000000e18;
    uint128 public _minAllocationPerWallet = 1e18;
    uint128 public _maxAllocationPerWallet = 100000e18;
    uint128 public _tokenPrice = 1.2e18;
    uint128 public _refererCommission = 10e17; // 10%

    uint128 oneThousandUsdc = 1000e6;
    uint128 oneHundredsUsdc = 100e6;

    address public owner = address(0x11);
    address public alice = address(0x22);
    address public bob = address(0x33);
    address public carol = address(0x44);

    function setUp() public {
        MockToken safeTokenContract = new MockToken("SafeToken", "SAFE", 18);
        MockToken usdcTokenContract = new MockToken("USDC", "USDC", 6);

        safeToken = address(safeTokenContract);
        usdcToken = address(usdcTokenContract);

        safeTokenContract.mint(owner, _maxSupply);
        usdcTokenContract.mint(alice, 1000_000e6);
        usdcTokenContract.mint(bob, 1000_000e6);
        usdcTokenContract.mint(carol, 1000_000e6);
        usdcTokenContract.mint(owner, 1000_000e6);

        vm.prank(owner);
        presale = new SafeYieldPresale(
            safeToken,
            usdcToken,
            _maxSupply,
            _minAllocationPerWallet,
            _maxAllocationPerWallet,
            _tokenPrice,
            _refererCommission
        );
    }

    modifier approved(address user) {
        vm.startPrank(user);
        IERC20(usdcToken).approve(address(presale), UINT256_MAX);
        vm.stopPrank();
        _;
    }

    modifier startPresale() {
        vm.startPrank(owner);
        presale.startPresale();
        vm.stopPrank();
        _;
    }

    modifier buyMultiple() {
        address[] memory users = new address[](10);

        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
        users[3] = address(0x55);
        users[4] = address(0x66);
        users[5] = address(0x77);
        users[6] = address(0x88);
        users[7] = address(0x99);
        users[8] = address(0x10);
        users[9] = address(0x12);

        uint128 allocation = (_maxAllocationPerWallet * 1e6) / _tokenPrice;
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            MockToken(usdcToken).mint(users[i], allocation);
            IERC20(usdcToken).approve(address(presale), UINT256_MAX);
            presale.buy(users[i], allocation);
            vm.stopPrank();
        }
        _;
    }

    function testPresalePhase() public {
        vm.startPrank(owner);
        assertEq(uint(presale.presaleState()), uint(PresaleState.NotStarted));
        presale.startPresale();
        assertEq(uint(presale.presaleState()), uint(PresaleState.Live));
        presale.endPresale();
        assertEq(uint(presale.presaleState()), uint(PresaleState.Ended));
        vm.stopPrank();
    }

    function testBuyCorrectAmount() public approved(alice) startPresale {
        vm.prank(alice);
        presale.buy(alice, oneThousandUsdc);

        uint128 expectedAllocation = getExpectedAllocation(
            oneThousandUsdc,
            _tokenPrice
        );

        uint128 aliceAllocation = presale.getTotalSafeTokensOwed(alice);
        assertEq(aliceAllocation, expectedAllocation);
    }

    function testBuyWithInvalidAmount_Failed()
        public
        approved(alice)
        startPresale
    {
        uint128 minAllocation = (_minAllocationPerWallet * 1e6) / _tokenPrice;
        uint128 maxAllocation = (_maxAllocationPerWallet * 1e6) / _tokenPrice;
        vm.prank(alice);
        vm.expectRevert(SafeYieldPresale.InvalidAllocation.selector);
        presale.buy(alice, minAllocation - 1);

        vm.prank(alice);
        vm.expectRevert(SafeYieldPresale.InvalidAllocation.selector);
        presale.buy(alice, maxAllocation + 1);
    }

    function testBuyFailNotInPresale() public approved(alice) {
        vm.prank(alice);
        vm.expectRevert(SafeYieldPresale.PresaleNotLive.selector);
        presale.buy(alice, oneThousandUsdc);

        vm.startPrank(owner);
        vm.expectRevert(SafeYieldPresale.PresaleNotLive.selector);
        presale.buyWithReferer(bob, oneThousandUsdc, alice);
    }

    function testBuyZeroAddress() public approved(alice) startPresale {
        vm.prank(alice);
        vm.expectRevert(SafeYieldPresale.InvalidUser.selector);
        presale.buy(address(0), oneThousandUsdc);
    }

    //test referrer id hash

    //
    function testMaxSupplyExceeded()
        public
        approved(owner)
        startPresale
        buyMultiple
    {
        uint128 amountLeft = presale.calculatesSafeTokensAvailable();
        console2.log("Amount left: ", amountLeft);
        uint128 safe = presale.calculatesSafeTokens(oneThousandUsdc);
        uint128 ownerInvestment = presale.investments(owner);
        vm.prank(owner);
        vm.expectRevert(SafeYieldPresale.MaxSupplyExceeded.selector);
        presale.buy(owner, 1000e6);
    }

    function testHashIsCorrect() public {
        bytes32 hash = _hashreferer(
            address(0xB232255EFc5F6f1c9408d9DB4e0Ee4072a96d467)
        );
        console2.logBytes32(hash);
        address referer = _retrievreferer(hash);
        console2.log(referer);
        assertEq(referer, address(0xB232255EFc5F6f1c9408d9DB4e0Ee4072a96d467));
    }

    function testBuyWithInvalidReferer_Failed()
        public
        approved(alice)
        startPresale
    {
        vm.prank(alice);
        vm.expectRevert();
        presale.buyWithReferer(alice, oneThousandUsdc, bob);
    }

    function testBuyWithReferer() public approved(alice) approved(bob) {
        vm.prank(owner);
        presale.startPresale();
        vm.prank(alice);
        presale.buy(alice, oneThousandUsdc);

        vm.prank(bob);
        presale.buyWithReferer(bob, oneHundredsUsdc, alice);

        uint128 expectedAllocation = getExpectedAllocation(
            oneHundredsUsdc,
            _tokenPrice
        );

        uint128 aliceAllocation = presale.getTotalSafeTokensOwed(alice);
        uint128 bobAllocation = presale.getTotalSafeTokensOwed(bob);
        uint128 aliceRefererCommission = presale.calculateRefererCommission(
            bobAllocation
        );
        assertEq(bobAllocation, expectedAllocation);
        assertGt(aliceAllocation, expectedAllocation + aliceRefererCommission);
    }

    function testClaim() public approved(alice) startPresale {
        vm.prank(alice);
        presale.buy(alice, oneThousandUsdc);

        uint128 expectedAllocation = getExpectedAllocation(
            oneThousandUsdc,
            _tokenPrice
        );

        uint128 aliceAllocation = presale.getTotalSafeTokensOwed(alice);
        assertEq(aliceAllocation, expectedAllocation);

        vm.startPrank(owner);
        presale.endPresale();
        IERC20(safeToken).transfer(address(presale), uint256(_maxSupply));
        vm.stopPrank();

        assertEq(IERC20(safeToken).balanceOf(address(presale)), _maxSupply);

        vm.prank(alice);
        presale.claim();

        uint256 aliceBalance = IERC20(safeToken).balanceOf(alice);
        assertEq(aliceBalance, expectedAllocation);

        vm.prank(alice);
        vm.expectRevert(SafeYieldPresale.ZeroBalance.selector);
        presale.claim();
    }

    function getExpectedAllocation(
        uint128 usdcAmount,
        uint128 tokenPrice
    ) public view returns (uint128) {
        return (usdcAmount * tokenPrice) / 1e6;
    }

    function _retrievreferer(bytes32 referer) private pure returns (address) {
        uint256 tempData = uint256(referer); // Convert bytes32 to uint256
        uint160 extractedAddress = uint160(tempData >> 96); // Remove padding zeros
        return address(extractedAddress);
    }
    function _hashreferer(address referer) private pure returns (bytes32) {
        return bytes32(abi.encodePacked(referer));
    }
}
