# Luckin Coffee USA - Master Operations Dashboard

## Overview

Comprehensive Grafana dashboard for Luckin Coffee USA operations analytics, covering:
- Real-time order monitoring
- Store performance analysis
- Payment analytics
- Member/CRM metrics
- 3rd party delivery platform tracking

## Files Included

| File | Description |
|------|-------------|
| `luckin_master_dashboard.json` | Complete Grafana dashboard (importable) |
| `all_queries.sql` | 100+ SQL queries organized by section |
| `variables.sql` | Grafana variable/dropdown queries |
| `alerts.sql` | Alert rule queries and configurations |
| `README.md` | This documentation |

## Prerequisites

### Required Data Sources

You need to configure 3 MySQL data sources in Grafana:

1. **aws-luckyus-iluckyhealth-rw** (Primary metrics database)
   - Database: `luckyus_iluckyhealth`
   - Tables: `t_collect_order_inter`, `t_collect_shop_inter`, `t_collect_payment_inter`, `t_collect_crm_inter`, `t_collect_marketing_inter`

2. **aws-luckyus-salesorder-rw** (Transactional order data)
   - Database: `luckyus_sales_order`
   - Tables: `t_order`

3. **aws-luckyus-opshop-rw** (Store master data)
   - Database: `luckyus_opshop`
   - Tables: `t_shop_info`

## Installation

### Step 1: Configure Data Sources

In Grafana, go to **Configuration > Data Sources** and add:

```
Name: aws-luckyus-iluckyhealth-rw
Type: MySQL
Host: <your-mysql-host>
Database: luckyus_iluckyhealth
User: <read-only-user>
```

Repeat for `salesorder` and `opshop` databases.

### Step 2: Import Dashboard

1. Go to **Dashboards > Import**
2. Upload `luckin_master_dashboard.json` or paste its contents
3. Select the appropriate data sources when prompted:
   - `DS_ILUCKYHEALTH` → aws-luckyus-iluckyhealth-rw
   - `DS_SALESORDER` → aws-luckyus-salesorder-rw
   - `DS_OPSHOP` → aws-luckyus-opshop-rw
4. Click **Import**

### Step 3: Configure Alerts (Optional)

1. Go to **Alerting > Alert Rules**
2. Create new alert rules using queries from `alerts.sql`
3. Configure notification channels (Slack, PagerDuty, Email)

## Dashboard Structure

### Row 1: Executive Summary
- Orders Today
- Revenue Today
- Average Order Value
- Active Stores
- Payment Success Rate (Gauge)
- New Members Today

### Row 2: Real-Time Order Monitoring
- Live Order Trend (1-minute resolution)
- Orders by Channel (Stacked)
- Channel Distribution (Pie)

### Row 3: Order Lifecycle Funnel
- Order Funnel (Created → Paid → Done → Cancel)
- Conversion Rate
- Completion Rate
- Cancellation Rate

### Row 4: Store Performance
- Top 10 Stores by Orders
- Store Performance Table
- Store Orders Over Time

### Row 5: 3rd Party Delivery Analysis
- Platform Distribution (DoorDash, Uber Eats, Grubhub)
- Platform Trend
- 3P Orders by Store

### Row 6: Shop Status Monitoring
- Shops Currently Open
- Shops Planned to Open
- Availability Rate
- Force Closed Stores (Alert)
- Shop Status Timeline

### Row 7: Payment Analytics
- Success Rate Trend
- Payment by Provider (Pie)
- Failed Payments
- Pending >30min (Alert)

### Row 8: Member Analytics
- Daily New Member Registrations
- New Members Today
- New Members This Week

## Key Metrics Reference

### Channel Codes
| Code | Channel |
|------|---------|
| 1 | In-Store/POS |
| 2 | Mobile App |
| 3 | Mini Program/Web |
| 8 | DoorDash |
| 9 | Grubhub |
| 10 | Uber Eats |

### Order Type Codes
| Code | Type |
|------|------|
| 1 | Pickup |
| 2 | Delivery |

### Order Status Codes
| Code | Status |
|------|--------|
| 0 | Cancelled/Unpaid |
| 10 | Created |
| 20 | Paid/Processing |
| 90 | Completed |

### Tenant Codes
| Code | Description |
|------|-------------|
| LKUS | Luckin USA (Production) |
| LKMY | Luckin Malaysia |
| IQA1/IQA2 | QA Environments |

## Query Patterns

### Time Filter (Grafana Macro)
```sql
WHERE $__timeFilter(insert_time)
```

### Channel Labels
```sql
CASE metric_value
  WHEN 1 THEN 'In-Store/POS'
  WHEN 2 THEN 'Mobile App'
  WHEN 3 THEN 'Mini Program/Web'
  WHEN 8 THEN 'DoorDash'
  WHEN 9 THEN 'Grubhub'
  WHEN 10 THEN 'Uber Eats'
END AS "Channel"
```

### Timezone Conversion (UTC to EST)
```sql
CONVERT_TZ(create_time, '+00:00', '-05:00')
```

### LKUS Filter
```sql
WHERE tenant = 'LKUS' AND status = 90
```

## Alert Thresholds

| Alert | Condition | Severity |
|-------|-----------|----------|
| Payment Success Rate | < 95% for 5m | Critical |
| Force Closed Stores | > 0 for 5m | Warning |
| No Orders from Store | 0 orders for 30m | Warning |
| Pending Payments | >10 pending >30m | Warning |
| Order Volume Drop | >50% below avg | Critical |
| Refund Rate | >5% of orders | Warning |

## Color Scheme

| Element | Color | Hex |
|---------|-------|-----|
| Mobile App | Blue | #3366CC |
| In-Store/POS | Green | #109618 |
| Mini Program/Web | Purple | #990099 |
| DoorDash | Red | #FF2D08 |
| Grubhub | Orange | #F26322 |
| Uber Eats | Black | #000000 |
| Success | Green | #73BF69 |
| Warning | Yellow | #FADE2A |
| Critical | Red | #F2495C |

## Refresh Intervals

| Section | Refresh Rate |
|---------|--------------|
| Executive Summary | 30 seconds |
| Real-Time Monitoring | 30 seconds |
| Store Performance | 5 minutes |
| Analytics | 5 minutes |
| Shop Status | 30 seconds |
| Payment Analytics | 30 seconds |
| Member Analytics | 5 minutes |

## Troubleshooting

### No Data Displayed
1. Verify data source connections
2. Check time range (default: Last 24 hours)
3. Ensure tables exist and have data
4. Check user permissions on MySQL databases

### Slow Queries
1. Add indexes on `insert_time`, `create_time` columns
2. Reduce time range
3. Increase query timeout in data source settings

### Alert Not Firing
1. Verify alert rule is enabled
2. Check evaluation interval
3. Verify notification channels are configured
4. Check alert query returns expected data

## Support

For issues or questions:
- Check Grafana logs for errors
- Verify MySQL connectivity
- Review query syntax in `all_queries.sql`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-27 | Initial release |

---

Generated by Claude Code
