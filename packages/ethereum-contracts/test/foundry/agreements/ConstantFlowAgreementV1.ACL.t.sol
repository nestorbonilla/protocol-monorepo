// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.19;

import { ISuperToken, SuperToken } from "../../../contracts/superfluid/SuperToken.sol";
import { IConstantFlowAgreementV1 } from "../../../contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { ISuperfluidToken } from "../../../contracts/interfaces/superfluid/ISuperfluidToken.sol";
import { FoundrySuperfluidTester } from "../FoundrySuperfluidTester.sol";
import { SuperTokenV1Library } from "../../../contracts/apps/SuperTokenV1Library.sol";

contract ConstantFlowAgreementV1ACLTest is FoundrySuperfluidTester {
    using SuperTokenV1Library for ISuperToken;

    struct AssertFlowOperator {
        ISuperfluidToken superToken;
        bytes32 flowOperatorId;
        uint8 expectedPermissions;
        int96 expectedFlowRateAllowance;
    }

    constructor() FoundrySuperfluidTester(3) { }

    function testIncreaseFlowRateAllowance(int96 flowRateAllowanceDelta) public {
        vm.assume(flowRateAllowanceDelta > 0);

        bytes32 flowOperatorId = _getFlowOperatorId(alice, bob);
        (uint8 oldPermissions, int96 oldFlowRateAllowance) = sf.cfa.getFlowOperatorDataByID(superToken, flowOperatorId);

        vm.startPrank(alice);
        superToken.increaseFlowRateAllowance(bob, flowRateAllowanceDelta);
        vm.stopPrank();

        _assertFlowOperatorData(
            AssertFlowOperator({
                superToken: superToken,
                flowOperatorId: flowOperatorId,
                expectedPermissions: oldPermissions,
                expectedFlowRateAllowance: oldFlowRateAllowance + flowRateAllowanceDelta
            })
        );
    }

    function testDecreaseFlowRateAllowance(int96 flowRateAllowanceIncreaseDelta, int96 flowRateAllowanceDecreaseDelta)
        public
    {
        vm.assume(flowRateAllowanceIncreaseDelta > 0);
        vm.assume(flowRateAllowanceDecreaseDelta > 0);
        vm.assume(flowRateAllowanceDecreaseDelta <= flowRateAllowanceIncreaseDelta);

        (bytes32 oldFlowOperatorId, uint8 oldPermissions, int96 oldFlowRateAllowance) =
            sf.cfa.getFlowOperatorData(superToken, alice, bob);

        vm.startPrank(alice);
        superToken.increaseFlowRateAllowance(bob, flowRateAllowanceIncreaseDelta);
        superToken.decreaseFlowRateAllowance(bob, flowRateAllowanceDecreaseDelta);
        vm.stopPrank();

        _assertFlowOperatorData(
            AssertFlowOperator({
                superToken: superToken,
                flowOperatorId: oldFlowOperatorId,
                expectedPermissions: oldPermissions,
                expectedFlowRateAllowance: oldFlowRateAllowance + flowRateAllowanceIncreaseDelta
                    - flowRateAllowanceDecreaseDelta
            })
        );
    }

    function testIncreaseFlowRateAllowanceWithPreSetPermissions(int96 flowRateAllowanceDelta) public {
        vm.assume(flowRateAllowanceDelta > 0);

        vm.startPrank(alice);
        superToken.setFlowPermissions(bob, true, true, true, 0);

        (bytes32 oldFlowOperatorId, uint8 oldPermissions, int96 oldFlowRateAllowance) =
            sf.cfa.getFlowOperatorData(superToken, alice, bob);

        superToken.increaseFlowRateAllowance(bob, flowRateAllowanceDelta);
        vm.stopPrank();

        _assertFlowOperatorData(
            AssertFlowOperator({
                superToken: superToken,
                flowOperatorId: oldFlowOperatorId,
                expectedPermissions: oldPermissions,
                expectedFlowRateAllowance: oldFlowRateAllowance + flowRateAllowanceDelta
            })
        );
    }

    function testDecreaseFlowRateAllowanceWithPreSetPermissions(
        int96 flowRateAllowanceIncreaseDelta,
        int96 flowRateAllowanceDecreaseDelta
    ) public {
        vm.assume(flowRateAllowanceIncreaseDelta > 0);
        vm.assume(flowRateAllowanceDecreaseDelta > 0);
        vm.assume(flowRateAllowanceDecreaseDelta <= flowRateAllowanceIncreaseDelta);

        vm.startPrank(alice);
        superToken.setFlowPermissions(bob, true, true, true, 0);

        (bytes32 oldFlowOperatorId, uint8 oldPermissions, int96 oldFlowRateAllowance) =
            sf.cfa.getFlowOperatorData(superToken, alice, bob);

        superToken.increaseFlowRateAllowance(bob, flowRateAllowanceIncreaseDelta);
        superToken.decreaseFlowRateAllowance(bob, flowRateAllowanceDecreaseDelta);
        vm.stopPrank();

        _assertFlowOperatorData(
            AssertFlowOperator({
                superToken: superToken,
                flowOperatorId: oldFlowOperatorId,
                expectedPermissions: oldPermissions,
                expectedFlowRateAllowance: oldFlowRateAllowance + flowRateAllowanceIncreaseDelta
                    - flowRateAllowanceDecreaseDelta
            })
        );
    }

    function testIncreaseFlowRateAllowanceAndACLCreateFlow(uint32 flowRateAllowanceDelta) public {
        vm.assume(flowRateAllowanceDelta > 0);
        vm.assume(flowRateAllowanceDelta <= uint32(type(int32).max));
        int96 flowRate = int96(int32(flowRateAllowanceDelta));
        vm.assume(flowRateAllowanceDelta > 0);

        vm.startPrank(alice);
        superToken.setFlowPermissions(bob, true, true, true, 0);
        superToken.increaseFlowRateAllowance(bob, flowRate);
        vm.stopPrank();

        _helperCreateFlowFrom(superToken, bob, alice, bob, flowRate);
    }

    function testRevertIfDecreaseFlowRateAllowanceAndACLCreateFlow(int96 flowRateAllowanceIncreaseDelta) public {
        vm.assume(flowRateAllowanceIncreaseDelta > 0);

        vm.startPrank(alice);
        superToken.setFlowPermissions(bob, true, true, true, 0);

        superToken.increaseFlowRateAllowance(bob, flowRateAllowanceIncreaseDelta);
        superToken.decreaseFlowRateAllowance(bob, flowRateAllowanceIncreaseDelta);

        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(IConstantFlowAgreementV1.CFA_ACL_FLOW_RATE_ALLOWANCE_EXCEEDED.selector);
        superToken.createFlowFrom(alice, bob, flowRateAllowanceIncreaseDelta);
    }

    function testRevertIfIncreaseFlowRateAllowanceOverflows() public {
        vm.startPrank(alice);
        superToken.increaseFlowRateAllowance(bob, type(int96).max);
        vm.expectRevert("CallUtils: target panicked: 0x11");
        superToken.increaseFlowRateAllowance(bob, 1);
        vm.stopPrank();
    }

    function testRevertIfDecreaseFlowRateAllowanceUnderflows() public {
        // @note this is done prior to the actual call to save addresses to the cache
        // and so that this is skipped when we execute the actual call
        // this fixes the issue where expect revert fails because it expects getHost to revert
        superToken.decreaseFlowRateAllowance(bob, 0);

        vm.startPrank(alice);
        vm.expectRevert(IConstantFlowAgreementV1.CFA_ACL_NO_NEGATIVE_ALLOWANCE.selector);
        superToken.decreaseFlowRateAllowance(bob, 10);
        vm.stopPrank();
    }

    function _assertFlowOperatorData(AssertFlowOperator memory data) internal {
        (uint8 newPermissions, int96 newFlowRateAllowance) =
            sf.cfa.getFlowOperatorDataByID(data.superToken, data.flowOperatorId);

        assertEq(newPermissions, data.expectedPermissions, "CFAv1 ACL: permissions not equal");
        assertEq(newFlowRateAllowance, data.expectedFlowRateAllowance, "CFAv1 ACL: flow rate allowance not equal");
    }

    function _getFlowOperatorId(address sender, address flowOperator) private pure returns (bytes32 id) {
        return keccak256(abi.encode("flowOperator", sender, flowOperator));
    }
}
