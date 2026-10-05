# Churn Risk Segmentation: Findings & Recommendations

## The Question

Who's most likely to leave, and what should be done about it?

## Summary

26.5% out of 7,043 customers have churned. Among the 5,174 remaining customers, a logistic regression model (ROC-AUC 0.867) estimates $738,721 in expected annual revenue at risk (about 19.4% of the company's $3.80M in active annualized revenue). Churn risk is concentrated in specific identifiable segments and the data points to clear low-effort actions for addressing it.

## Key Findings

1. Contract length is the single strongest driver of churn and holds at every value level. Month-to-month customers churn at 45.8% on average, and at 58.2% among high-value customers, versus 20.1% (one-year) and 6.1% (two-year). Every customer on this project's top-25 priority list (high-value, high-risk, ranked by revenue at risk) is month-to-month without exception.
2. The largest pocket of dollar-weighted risk is at the Q3 value tier. High-value (Q4) customers carry $41,931 in expected revenue at risk from their High Risk segment. The Q3 tier (high-spending but not the highest-spending) carries more: $66,147. Q4 is comparatively well-protected: 967 of 1,178 active high-value customers (82%) are Low Risk.
3. Medium Risk customers represent the largest total exposure across the business, which is nearly half of all revenue at risk. Across all value tiers Medium Risk customers account for roughly $320,925 of the $738,721 total, which is more than the High Risk tier. These are customers who haven't fully decided to leave, which typically makes them more responsive to retention outreach than customers who are already at high risk.
4. Tenure and referrals are strong, low-cost signals of loyalty. Churn drops from 53.3% in the first 6 months to 9.5% after 49+ months. Customers who stayed averaged 2.47 referrals versus 0.52 for those who churned.
5. Promotional offers are not an independent retention driver but contract length is. Offer A appeared to have the best raw churn rate (6.7%) of any offer, but 78% of Offer A customers were already on two-year contracts. Once contract type is controlled for, the offer itself shows no protective effect. This indicates that the company should not expect switching customers onto Offer A, on its own, to reduce churn.
6. Competitive pressure is the leading reason customers leave. "Competitor" is the top churn category (841 of 1,869 churned customers), ahead of Dissatisfaction (321) and Attitude (314). The two most common individual reasons are "Competitor had better devices" and "Competitor made better offer."

## Recommendations

1. Launch a targeted contract-conversion offer for the top-25 (and broader high-value, high-risk) month-to-month list. This is the highest-leverage, most specific action available: a defined, rankable list of real customers, each with a known dollar value and churn probability, all sharing the one factor (no contract) most strongly tied to retention. Moving even a fraction of this list to a one- or two-year contract should produce a measurable, attributable reduction in churn.
2. Build a Medium Risk retention motion, not just a High Risk one. Because Medium Risk customers represent the largest total exposure and are easier to retain than customers who are at high risk, a proactive outreach or incentive program aimed at this tier rather than only seeking out the highest-risk names likely has the best return on effort.
3. Don't rely on promotional offers alone as a retention lever. Since Offer A's apparent benefit was fully explained by contract mix, offer design should be evaluated by whether it moves customers toward longer contracts, not by its raw associated churn rate.
4. Treat competitive positioning (device selection, pricing offers) as a retention issue, not only a sales issue. With "competitor" reasons outweighing dissatisfaction reasons by roughly 2.5x, retention strategy should include competitive intelligence (device lineup, offer positioning) and not just service-quality fixes.
5. Use tenure and referral count as early-warning signals. Both are simple, already-collected data points that could feed a lightweight early-warning flag for new customers (low tenure) or disengaged ones (few or no referrals), ahead of a full model refresh.

## Caveats & Limitations

- The model catches roughly 62% of actual churners in advance, with 64% precision on its "will churn" predictions.
- Two data quality issues were identified and corrected during cleaning: 120 customers (1.7%) had negative Monthly Charge values; an initial fix (absolute value) produced implausible results (for example some internet customers had a $1/month fee) and was replaced with segment-median imputation, flagged by the `monthly_charge_imputed` column.
- "High value" was redefined during the project. Total Revenue, the initial value measure, is confounded with tenure (it accumulates over time), making long-tenured customers look artificially low-risk. Monthly Charge (current spend which is independent of tenure) was adopted as the primary value definition after this was identified. The two definitions agree on only 62% of customers.
- Offer's relationship to churn is confounded with contract type. It should not be read as a causal, standalone effect.