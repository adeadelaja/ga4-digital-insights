# Tracking plan: GA4 through Google Tag Manager

This is the measurement plan behind the analysis: which events the site sends, how Google Tag Manager (GTM) sends them, and the checks that keep the data trustworthy. It follows the GA4 recommended ecommerce events, so the export matches what the SQL in this repo expects. The last section applies the same plan to a B2B lead generation site.

## 1. What we measure and why

| Business question | Measured by | Key event |
| --- | --- | --- |
| Which channels bring buyers, not just visitors? | Session source and medium on every event; `purchase` revenue | `purchase` |
| Where do shoppers drop out? | `view_item` to `purchase` funnel events | none (diagnostic) |
| Which pages start good journeys? | First `page_view` in each session, with engagement and conversion | none |
| Which campaigns work? | UTM tags on every paid, email and social link (see `utm_naming_standard.md`) | `purchase` |
| Do changes we test make a difference? | `experiment_id` and `experiment_variant` parameters | primary metric of the test |

Key events (GA4's name for conversions) are kept to real outcomes: `purchase` on the shop, `generate_lead` on a lead site, and `sign_up`. Every other event is diagnostic. Marking too many events as key events makes reports and bidding chase activity instead of value.

The full event list, triggers and parameters are in `event_dictionary.csv`.

## 2. GTM setup

**Container structure**

| Type | Name | Fires on |
| --- | --- | --- |
| Google tag | `GA4 \| Config \| all pages` | Initialization, all pages (consent aware) |
| GA4 event tag | `GA4 \| Event \| ecommerce` | Custom event trigger `CE \| ecommerce events` |
| GA4 event tag | `GA4 \| Event \| generate_lead` | Custom event trigger `CE \| generate_lead` |
| Trigger | `CE \| ecommerce events` | Custom event, regex `^(view_item_list\|select_item\|view_item\|add_to_cart\|remove_from_cart\|view_cart\|begin_checkout\|add_shipping_info\|add_payment_info\|purchase)$` |
| Variable | `DLV \| ecommerce` | Data layer variable `ecommerce` |
| Variable | `DLV \| experiment_variant` | Data layer variable `experiment_variant` |

The ecommerce tag uses the event name `{{Event}}` and has "Send ecommerce data" switched on with the data layer as the source, so one tag covers the whole funnel.

**Naming rule:** `Tool | Type | What`, for example `GA4 | Event | purchase`. Anyone opening the container can tell what a tag does without opening it.

**Publishing:** every change goes through a workspace, is tested in Preview, and is published as a version with a note saying what changed and why.

## 3. Data layer specification

Clear the previous ecommerce object before every push, so values from one event never leak into the next.

**add_to_cart**

```js
window.dataLayer = window.dataLayer || [];
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: "add_to_cart",
  ecommerce: {
    currency: "GBP",
    value: 22.00,
    items: [{
      item_id: "GGOEGXXX0906",
      item_name: "Google Cloud Tee",
      item_category: "Apparel",
      item_variant: "Blue / M",
      price: 22.00,
      quantity: 1
    }]
  }
});
```

**purchase** (fires once, on the confirmation page, after payment succeeds)

```js
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: "purchase",
  ecommerce: {
    transaction_id: "T_20261116_000123",
    value: 49.99,
    tax: 8.33,
    shipping: 5.99,
    currency: "GBP",
    coupon: "WINTER10",
    items: [{ item_id: "GGOEGXXX0906", item_name: "Google Cloud Tee", item_category: "Apparel", price: 22.00, quantity: 2 }]
  }
});
```

**generate_lead** (B2B form, fires only after the server confirms the submission)

```js
dataLayer.push({
  event: "generate_lead",
  form_id: "contact_underwriter",
  form_name: "Contact an underwriter",
  lead_type: "broker_enquiry",
  product_line: "cyber",
  value: 1,
  currency: "GBP"
});
```

## 4. Consent

UK and EU visitors must agree before analytics or advertising cookies are set. Consent Mode is set to denied by default for `analytics_storage`, `ad_storage`, `ad_user_data` and `ad_personalization`, and updated from the cookie banner when the visitor accepts. When consent is refused GA4 receives cookieless pings and models part of the gap, so GA4 totals and back end totals (orders, CRM leads) will not match exactly. That gap is reported and explained, not hidden.

## 5. Quality checks before and after every release

1. **GTM Preview and GA4 DebugView:** each funnel event fires once, with the right name and parameters.
2. **No duplicate purchases:** reloading the confirmation page must not send a second `purchase`. GA4 deduplicates on `transaction_id`, so every purchase must carry one.
3. **Values are numbers:** `value` and `price` are sent as numbers, not strings, and `currency` is always set.
4. **Form events fire on success only:** never on the button click, or failed submissions count as leads.
5. **Unwanted referrals:** payment providers (for example `paypal.com`) and the site's own subdomains are listed as unwanted referrals, or they steal the credit for purchases.
6. **Cross domain:** if checkout runs on another domain, cross domain measurement is configured so the session survives the jump.
7. **Monthly UTM audit:** `sql/06_utm_audit.sql` lists source and medium values that break the naming standard.
8. **Reconciliation:** GA4 purchases and revenue are compared with the order system every month; a gap above 10% is investigated.

## 6. Applying this plan to a B2B lead generation site

On a B2B site the outcome is not on the website. A form fill only becomes valuable when sales qualifies it and it turns into revenue, sometimes months later. Web analytics on its own credits the form, not the business. The plan closes that gap:

1. **One lead event:** every enquiry form sends `generate_lead` with `form_id`, `lead_type` and `product_line`. It is the only lead key event.
2. **Capture the source with the lead:** hidden form fields store the UTM values, the landing page and the GA4 client ID (and the Google click ID when present). They are written into the CRM record when the lead is created.
3. **Guard the CRM end:** validation rules stop a lead being saved without a lead source, so attribution cannot silently break at the handoff.
4. **Report on outcomes:** channel and campaign performance is judged on qualified leads and closed revenue from the CRM, joined back to GA4 on the client ID, not on form fills alone.
5. **Send the outcome back:** qualified leads are imported into Google Ads as offline conversions, so bidding optimises for leads sales wants, not for anyone who fills in a form.
