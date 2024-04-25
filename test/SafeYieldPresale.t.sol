pragma solidity 0.8.21;
import {Test} from "forge-std/Test.sol";
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

    function testPresalePhase() public {
        vm.startPrank(owner);
        assertEq(uint(presale.presaleState()), uint(PresaleState.NotStarted));
        presale.startPresale();
        assertEq(uint(presale.presaleState()), uint(PresaleState.Live));
        presale.endPresale();
        assertEq(uint(presale.presaleState()), uint(PresaleState.Ended));
        vm.stopPrank();
    }

    function testBuy() public approved(alice) startPresale {
        vm.prank(alice);
        presale.buy(alice, oneThousandUsdc);

        uint128 expectedAllocation = getExpectedAllocation(
            oneThousandUsdc,
            _tokenPrice
        );

        uint128 aliceAllocation = presale.getTotalsafeTokensOwed(alice);
        assertEq(aliceAllocation, expectedAllocation);
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

        uint128 aliceAllocation = presale.getTotalsafeTokensOwed(alice);
        uint128 bobAllocation = presale.getTotalsafeTokensOwed(bob);
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

        uint128 aliceAllocation = presale.getTotalsafeTokensOwed(alice);
        assertEq(aliceAllocation, expectedAllocation);

        vm.startPrank(owner);
        presale.endPresale();
        IERC20(safeToken).transfer(address(presale), uint256(_maxSupply));
        vm.stopPrank();

        vm.prank(alice);
        presale.claim();

        uint256 aliceBalance = IERC20(safeToken).balanceOf(alice);
        assertEq(aliceBalance, expectedAllocation);
    }

    function getExpectedAllocation(
        uint128 usdcAmount,
        uint128 tokenPrice
    ) public view returns (uint128) {
        return (usdcAmount * tokenPrice) / 1e6;
    }
}
