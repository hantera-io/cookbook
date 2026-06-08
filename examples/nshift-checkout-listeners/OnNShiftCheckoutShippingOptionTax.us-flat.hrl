import 'iterators'

// =============================================================================
// Example: flat 8 % US shipping tax via OnNShiftCheckoutShippingOptionTax
//
// `apps.nshift-checkout`'s default shipping tax is `max(line.taxFactor)`,
// which is appropriate for European VAT markets where shipping inherits the
// highest line tax rate. For US destinations we want a flat factor instead.
//
// The hook is fired once per `getOptions` call with the full delivery context
// + every option. Emit one `shippingTaxFactor` (or `shippingTax`) effect per
// option you want to override; options you don't emit for fall back to the
// default.
// =============================================================================

param input: {
  delivery: {
    deliveryAddress: Address
  }
  options: [{
    optionId: uuid
    carrierId: text
    name: text
    price: number
    nShiftTaxRate: number | nothing
  }]
}

let isUs = input.delivery.deliveryAddress.countryCode match
  'US' |> true
  |> false

from isUs match
  true |>
    input.options
    select o => {
      effect = 'custom'
      type = 'shippingTaxFactor'
      optionId = o.optionId
      value = 0.08
    }
    buffer
  |> []
