// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";
import {CompositePricing} from "src/modules/pricing/CompositePricing.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceSetUp} from "test/common/NamespaceSetUp.sol";

contract CompositePricingTest is NamespaceSetUp {
    CompositePricing internal pricing;
    bytes32 internal activationId;

    function setUp() public override {
        super.setUp();
        pricing = CompositePricing(_deployModule(address(new CompositePricing())));
        activationId = keccak256("activation");
    }

    function test_quoteMint_addsClassFixedAndLengthAmounts() public {
        _configure();

        NamespaceTypes.Price memory price = pricing.quoteMint(
            _mintCtx("abcdef"),
            NamespaceTypes.Price({token: address(0), amount: 0}),
            ""
        );

        assertEq(price.token, address(token));
        assertEq(price.amount, 10 ether + 100 ether + 5 gwei * 365 days);
    }

    function test_quoteMint_usesExactLengthFixedOverride() public {
        _configure();

        NamespaceTypes.Price memory price = pricing.quoteMint(
            _mintCtx("abc"),
            NamespaceTypes.Price({token: address(0), amount: 0}),
            ""
        );

        assertEq(price.amount, 10 ether + 3 ether + 3 gwei * 365 days);
    }

    function _configure() private {
        CompositePricing.LengthPrice[] memory lengthPrices = new CompositePricing.LengthPrice[](5);
        uint128[] memory mintRates = new uint128[](5);
        uint128[] memory renewRates = new uint128[](5);
        for (uint256 i; i < 5;) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uint16 length = uint16(i + 1);
            lengthPrices[i] = CompositePricing.LengthPrice({
                length: length,
                mintAmount: uint128((i + 1) * 1 ether),
                renewAmount: uint128((i + 1) * 0.5 ether)
            });
            mintRates[i] = uint128((i + 1) * 1 gwei);
            renewRates[i] = uint128((i + 1) * 0.5 gwei);
            unchecked {
                ++i;
            }
        }

        vm.prank(address(controller));
        pricing.configure(
            activationId,
            abi.encode(
                CompositePricing.Params({
                    token: address(token),
                    labelClass: LabelClassPricing.LabelClass.LETTER,
                    classMintAmount: 10 ether,
                    classRenewAmount: 5 ether,
                    defaultMintAmount: 100 ether,
                    defaultRenewAmount: 50 ether,
                    lengthPrices: lengthPrices,
                    mintPricePerSecondByLength: mintRates,
                    renewPricePerSecondByLength: renewRates
                })
            )
        );
    }

    function _mintCtx(string memory label) private view returns (NamespaceTypes.MintContext memory ctx) {
        ctx.activationId = activationId;
        ctx.buyer = accounts.buyer.addr;
        ctx.payer = accounts.buyer.addr;
        ctx.label = label;
        ctx.labelHash = keccak256(bytes(label));
        ctx.duration = 365 days;
    }
}
