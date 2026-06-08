# nShift Checkout — listener rule examples

`apps.nshift-checkout` exposes two hooks that let tenants inject custom
variables and override shipping-tax calculations without forking the app:

- **`OnNShiftCheckoutVariables`** — runs before nShift is called. Useful for
  warehouse selection, split-shipment rules, configuration overrides, etc.
- **`OnNShiftCheckoutShippingOptionTax`** — runs once per `getOptions` call,
  after nShift returns options. Use it to override the default
  `max(line.taxFactor)` shipping tax rate (or to provide an absolute amount)
  for markets where tax depends on destination/carrier rather than the cart.

The example listeners in this folder show typical patterns. Copy them into
your own app, adjust the predicates, and install via your normal app
deployment.

For the published Kustom-+-nShift integration that wires these hooks into the
KSA callback API, see [`apps.commerce-kustom-nshift-checkout`](https://developer.hantera.io/official-apps/commerce/commerce-kustom-nshift-checkout/).

## Files

- `OnNShiftCheckoutVariables.warehouse.hrl` — pick a warehouse based on the
  delivery address country code.
- `OnNShiftCheckoutShippingOptionTax.us-flat.hrl` — apply a flat 8 % factor
  for US addresses; leave other markets to the default.
