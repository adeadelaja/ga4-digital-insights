# UTM naming standard

Campaign tags decide which channel gets the credit in GA4. One badly tagged link sends a campaign's results to "Unassigned" or splits one channel across several rows. These rules keep every report comparable.

## Rules

1. **Lower case only.** GA4 treats `Email` and `email` as different values.
2. **No spaces.** Use underscores: `paid_social`, not `paid social`.
3. **Medium comes from the approved list below.** Nothing else. The list lines up with GA4's default channel groups, so every tagged link lands in a known channel.
4. **Never tag internal links.** A UTM on a link inside the site starts a new session and overwrites the real source.
5. **Every paid, email, social and partner link is tagged.** Organic search and direct traffic are never tagged.
6. **Links are built in the shared builder sheet,** not by hand, and the sheet keeps a record of every live campaign.

## Approved values

| Parameter | Rule | Examples |
| --- | --- | --- |
| `utm_medium` | One of: `cpc`, `display`, `paid_social`, `social`, `email`, `affiliate`, `referral` | `email` |
| `utm_source` | The platform or sender, lower case | `google`, `bing`, `linkedin`, `meta`, `newsletter`, `partner_name` |
| `utm_campaign` | `yyyy_mm_objective_audience_offer` | `2026_11_leadgen_brokers_cyber_guide` |
| `utm_content` | The creative or variant, so versions can be compared | `carousel_v2`, `cta_button_top` |
| `utm_term` | Paid search keyword only | `cyber_insurance_broker` |
| `utm_id` | The campaign ID from the ad platform or campaign tracker | `cmp_0142` |

## How each medium maps to a GA4 channel

| utm_medium | GA4 default channel group |
| --- | --- |
| `cpc` | Paid Search (search engine sources) or Paid Social / Paid Other |
| `display` | Display |
| `paid_social` | Paid Social (social sources) |
| `social` | Organic Social |
| `email` | Email |
| `affiliate` | Affiliates |
| `referral` | Referral |

## Governance

1. `sql/06_utm_audit.sql` runs monthly and flags upper case values, spaces and mediums outside the approved list.
2. Every flagged value is traced to its campaign owner and fixed in the builder sheet.
3. New mediums are added to this standard first, then used.
