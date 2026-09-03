# nShift Checkout — listener rule examples

`apps.nshift-checkout` exposes a hook that lets tenants inject custom
variables without forking the app:

- **`OnNShiftCheckoutVariables`** — runs before nShift is called. Useful for
  warehouse selection, split-shipment rules, configuration overrides, etc.

The example listeners in this folder show typical patterns. Copy them into
your own app, adjust the predicates, and install via your normal app
deployment.

For the published Kustom-+-nShift integration that wires these hooks into the
KSA callback API, see [`apps.commerce-kustom-nshift-checkout`](https://developer.hantera.io/official-apps/commerce/commerce-kustom-nshift-checkout/).

## Files

- `OnNShiftCheckoutVariables.warehouse.hrl` — pick a warehouse based on the
  delivery address country code.
