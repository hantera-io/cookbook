# App Template: commerce-kustom-nshift-checkout

A **copy-and-customize app template** that exposes the [Kustom Shipping
Assistant (KSA) callback API](https://docs.kustom.co/) backed by **nShift
Checkout**, for a Hantera Commerce cart paid via **Kustom Payments**.

> This is a **template**, not a published app. Every integration has merchant-
> specific quirks (nShift carrier id ↔ KSA carrier mapping, request shape,
> tax-rate fallback). Copy this folder into your own app repo, rename it, and
> edit the clearly-marked customization seams.

## What it glues

- **`apps.nshift-checkout`** — provides the public `nshift.module.hrc`
  module (`getOptions`), the `OnNShiftCheckoutVariables` hook, the
  `nShiftCheckoutSession` ticket type, and the rules and jobs that handle
  selection bridging and shipment dispatch. This template consumes the module
  via `requires.modules` in `h_app.yaml`.

- **`apps.commerce`** — owns the cart, the `deliveryDynamicFields` convention
  that copies cart-level dynamic fields onto the order's delivery at
  cart-to-order conversion.

- **`apps.psp.kustom`** — owns Kustom Payments integration. Must have the
  cart's channel configured with **`kustomUsesShippingAssistant: true`**
  (see "Companion `apps.psp.kustom` changes" below) so the Kustom Payments
  order is built without shipping and KSS owns the shipping line.

## Endpoint surface

All routes are namespaced under `/kustom/nshift/` to leave room for other TMS
integrations side-by-side.

| KSA route                                | Hantera route                                    |
| ---------------------------------------- | ------------------------------------------------ |
| `POST /auth`                             | `POST /kustom/nshift/auth`                       |
| `POST /shippingoptions`                  | `POST /kustom/nshift/shippingoptions`            |
| `POST /shipment`                         | `POST /kustom/nshift/shipment`                   |
| `GET /shipment/{shipment_id}`            | `GET  /kustom/nshift/shipment/{shipmentId}`      |
| `PUT /shipment/{shipment_id}`            | `PUT  /kustom/nshift/shipment/{shipmentId}`      |

KSA's `POST /shipment/{shipment_id}/confirm` is **not** implemented. The nShift
shipment is created at order creation by `apps.nshift-checkout`'s bridge rule
and `createPartialShipment` job, so the confirmation hook is unnecessary.

The `shipment_id` exposed to KSS is the `nShiftCheckoutSession` ticket's actor
id, so the GET/PUT lookups are direct.

## Auth (TMS handshake → JWT bearer)

The KSA `/auth` flow is implemented as the canonical SHA-256-nonce digest with
HS256-signed bearer JWT.

1. Configure the merchant identifier + key in this app's settings:

   ```
   apps/commerce-kustom-nshift-checkout/settings/identifier  →  <identifier>
   apps/commerce-kustom-nshift-checkout/settings/key         →  <shared secret>
   ```

2. On `POST /auth`, the ingress validates `sha256(nonce + key)` against the
   digest in the body. On success it returns a HS256-signed JWT signed with the
   same `key`, valid for one hour.

3. Subsequent KSA calls carry `Authorization: Bearer <jwt>`. The ingresses
   verify the JWT locally (no shared state). Expired/invalid → `401`, and KSS
   automatically re-auths.

If a merchant needs separate test/production credentials, install the app
twice with different settings.

## Cart resolution

KSA's `order.id` is the Kustom order id. `apps.psp.kustom` writes that id onto
the cart as `dynamic.field:kustomOrderId` at order creation, and (via
`registryEntries`) registers it as the typed graph field
`ticket.cart.kustomOrderId` so it's filterable. This template's
`helpers/cart-resolution.module.hrc` resolves the cart with a single graph
query:

```filtrera
query carts(cartId)
filter $'kustomOrderId == "{kustomOrderId}"'
```

The `requires.graph.nodes.ticket.cart.fields.kustomOrderId` block in
`h_app.yaml` makes the dependency on that field explicit and gates activation
on it being available.

## Companion `apps.psp.kustom` changes

This template **does not** work in isolation. `apps.psp.kustom` must be
extended to:

1. Expose a per-channel registry flag `channels/<channelKey>.kustomUsesShippingAssistant`
   (boolean, default false).
2. In `ingresses/checkout.hrc` and `rules/cart-kustom-sync.hrl`, when the flag
   is true:
   - Subtract `sum(deliveries.shippingTotal)` from `order_amount`.
   - Subtract `sum(deliveries.shippingTax)` from `order_tax_amount`.

   The order lines themselves are untouched (in Hantera, shipping is system
   fields on `Delivery`, not order lines).

This decoupling means the customer pays subtotal + shipping (KSS adds the
shipping line on Kustom's side), with no double-counting, and lets Hantera's
promotion engine continue to operate on the cart's *non*-shipping totals.

> **Known constraint.** When the flag is on, promotions must not discount
> shipping. KSS owns the shipping line and any Hantera-side discount on
> shipping would be silently overridden. Make sure your promotions don't touch
> `Delivery.ShippingPrice`/`ShippingTotal`/`ShippingTax`.

## Selection key conventions

The template writes two field names into the cart's `deliveryDynamicFields` to
signal a selection. These match the convention `apps.nshift-checkout`'s bridge
rule expects:

| Field                            | Type | Meaning                                                                       |
| -------------------------------- | ---- | ----------------------------------------------------------------------------- |
| `nShiftCheckoutSessionActorId`   | uuid | The `nShiftCheckoutSession` ticket actor id.                                  |
| `nShiftCheckoutOptionId`         | text | nShift's own unique id for the selected option (`option.optionId`).           |
| `shippingProductNumber`          | text | The carrier-product combo string from the selected option (informational).    |

## Tax model

KSA expects `shipping_option.tax_rate` to be a non-negative integer with two
implicit decimals (e.g. `2500` = 25.00%). nShift's `option.taxRate` is a
single configured number that the merchant set up in the nShift portal, so it
doesn't know about cart contents.

The mapping helper uses:

1. `option.taxRate` from nShift when present;
2. Otherwise the constant `DefaultShippingTaxRate` (defaults to `25%`).

Customize `DefaultShippingTaxRate` in `helpers/mapping.module.hrc` for your
market.

## Prerequisites

The following apps must be installed and activated in the tenant:

- `nshift-checkout` (with `clientId` / `clientSecret` settings configured)
- `commerce`
- `kustom` (with the channel-level `kustomUsesShippingAssistant: true` and the
  shipping-strip patch in checkout + sync; see "Companion changes" above)

Each channel used must have:

- `channels/{channelKey}.nshiftCheckoutConfigurationId` — the nShift Checkout
  configuration id, **or** the mapping module must inject the configuration id
  explicitly into `variables.nshiftCheckoutConfigurationId`.
- `channels/{channelKey}.kustomUsesShippingAssistant: true`.
- `channels/{channelKey}.kustomAccountKey` — the Kustom account key.

## Installation

1. Copy this folder into your own app repository and rename it (the `id` in
   `h_app.yaml` must be unique in the tenant).
2. Set this app's `identifier` + `key` settings to match the values you
   configured on the Kustom side.
3. Review and edit the **customization seams** below.
4. Install it as an app:

   ```
   > h_ app install
   ```

   (or use your normal app deployment flow — `h_ app dev` while iterating.)

## Customization seams

| File                                            | What to customize                                                                                                                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `components/helpers/mapping.module.hrc`         | KSA ⇄ nShift mapping. The `pickCarrier` function in particular needs your nShift→KSA carrier-enum mapping. `DefaultShippingTaxRate` is the shipping-tax-rate fallback.                     |
| `components/helpers/cart-resolution.module.hrc` | The cart graph query. Replace with your own lookup if you don't want to rely on `apps.psp.kustom`'s `ticket.cart.kustomOrderId` field.                                                     |
| `components/ingresses/shippingoptions.hrc`      | The nShift `variables` record. Must include `channelKey` so the nShift module can resolve the checkout configuration id. Add merchant-specific variables (warehouse, split, etc.) here.   |
| `h_app.yaml`                                    | App `id`, routes, ACLs, settings, and the `requires.modules` type (keep in sync with the nShift app's actual export type).                                                                |

## Required ACLs

The `shippingoptions` ingress must grant `actors/ticket:create` in addition to
the usual `:query` / `:applyCommands` / `:complete`. The nShift module's
`getOptions` creates an `nShiftCheckoutSession` ticket actor the first time
it's called for a cart; without `:create` permission the actor is silently
rejected with `UNAUTHORIZED_MESSAGE` and the cart ends up pointing at a
session that doesn't exist. The same applies to any other ingress in your app
that calls `getOptions`.

## nShift `variables`

Implement an `OnNShiftCheckoutVariables` listener rule (in this app or
elsewhere) to inject warehouse/split/etc. variables. The resolved variables
are merged into the request and end up persisted on the session ticket's
`request` payload for debugging.

## Related

- nShift module API: see the [nShift Checkout app docs](https://developer.hantera.io/official-apps/shipping/nshift-checkout/)
  for the `requires.modules` contract, the `OnNShiftCheckoutVariables` hook,
  and the session-ticket model.
- `deliveryDynamicFields` copy convention: `apps.commerce` cart-to-order rule.
- Kustom Shipping Assistant API: <https://docs.kustom.co/contents/api/shipping-service-callback/>
