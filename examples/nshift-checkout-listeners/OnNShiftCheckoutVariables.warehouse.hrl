// =============================================================================
// Example: warehouse selection via OnNShiftCheckoutVariables
//
// Picks an nShift `fromwarehouse` variable based on the delivery address's
// country code, with a default for everything else. Place this rule in your
// own app and register it as a listener for `OnNShiftCheckoutVariables`.
//
// =============================================================================

param input: {
  delivery: {
    deliveryId: uuid | nothing
    deliveryAddress: Address
    dynamic: { text -> value }
    lines: [value]
    order: {
      channelKey: text
      currencyCode: text
      locale: text | nothing
      dynamic: { text -> value }
    }
  }
}

let warehouse = input.delivery.deliveryAddress.countryCode match
  'SE' |> 'STOCKHOLM'
  'NO' |> 'OSLO'
  'DK' |> 'COPENHAGEN'
  'FI' |> 'HELSINKI'
  |> 'STOCKHOLM'

from [{
  effect = 'custom'
  type = 'variable'
  key = 'fromwarehouse'
  value = warehouse
}]
