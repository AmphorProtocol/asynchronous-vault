//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// abstract contract Assertions {
//     /*//////////////////////////////////////////////////////////////////////////
//                                        EVENTS
//     //////////////////////////////////////////////////////////////////////////*/

//     /*//////////////////////////////////////////////////////////////////////////
//                                      ASSERTIONS
//     //////////////////////////////////////////////////////////////////////////*/

//     /// @dev Compares two {IERC20} values.
//     function assertEq(IERC20 a, IERC20 b) internal {
//         assertEq(address(a), address(b));
//     }

//     /// @dev Compares two {IERC20} values.
//     function assertEq(IERC20 a, IERC20 b, string memory err) internal {
//         assertEq(address(a), address(b), err);
//     }

//     /// @dev Compares two `uint128` numbers.
//     function assertEqUint128(uint128 a, uint128 b) internal {
//         if (a != b) {
//             emit Log("Error: a == b not satisfied [uint128]");
//             emit LogNamedUint128("   Left", b);
//             emit LogNamedUint128("  Right", a);
//             fail();
//         }
//     }

//     /// @dev Compares two `uint128` numbers.
//     function assertEqUint128(uint128 a, uint128 b, string memory err)
//         internal
//     {
//         if (a != b) {
//             emit LogNamedString("Error", err);
//             assertEqUint128(a, b);
//         }
//     }

//     /// @dev Compares two `uint40` numbers.
//     function assertEqUint40(uint40 a, uint40 b) internal {
//         if (a != b) {
//             emit Log("Error: a == b not satisfied [uint40]");
//             emit LogNamedUint40("   Left", b);
//             emit LogNamedUint40("  Right", a);
//             fail();
//         }
//     }

//     /// @dev Compares two `uint40` numbers.
//     function assertEqUint40(uint40 a, uint40 b, string memory err) internal {
//         if (a != b) {
//             emit LogNamedString("Error", err);
//             assertEqUint40(a, b);
//         }
//     }

//     /// @dev Compares two {Lockup.Status} enum values.
//     function assertNotEq(Lockup.Status a, Lockup.Status b) internal {
//         assertNotEq(uint256(a), uint256(b), "status");
//     }

//     /// @dev Compares two {Lockup.Status} enum values.
//     function assertNotEq(Lockup.Status a, Lockup.Status b, string memory err)
//         internal
//     {
//         assertNotEq(uint256(a), uint256(b), err);
//     }
// }
