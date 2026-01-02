-- ============================================================================
-- LUCKIN COFFEE USA - GRAFANA ALERT RULES
-- Alert Queries and Thresholds
-- ============================================================================

-- ============================================================================
-- ALERT 1: Payment Success Rate < 95%
-- Severity: Critical
-- Evaluation: Every 1 minute for 5 minutes
-- ============================================================================
-- Name: Payment Success Rate Critical
-- Condition: WHEN last() OF query IS BELOW 95

SELECT
  CAST(metric_count_comment AS DECIMAL(5,2)) AS "value"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'all_tenant_payment_success'
ORDER BY insert_time DESC
LIMIT 1;

-- Alert Configuration:
-- Condition: value < 95
-- For: 5m
-- Severity: critical
-- Summary: Payment success rate dropped below 95% (Current: {{ $value }}%)
-- Description: The payment success rate has fallen to {{ $value }}%. This may indicate payment gateway issues.
-- Runbook URL: [Link to payment troubleshooting runbook]


-- ============================================================================
-- ALERT 2: Force Closed Stores > 0
-- Severity: Warning
-- Evaluation: Every 1 minute for 5 minutes
-- ============================================================================
-- Name: Store Force Closed Alert
-- Condition: WHEN last() OF query IS ABOVE 0

SELECT
  metric_count AS "value"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_forced_off'
ORDER BY insert_time DESC
LIMIT 1;

-- Alert Configuration:
-- Condition: value > 0
-- For: 5m
-- Severity: warning
-- Summary: {{ $value }} store(s) are force closed
-- Description: One or more stores have been force closed. Check store operations dashboard for details.


-- ============================================================================
-- ALERT 3: No Orders from Store (30 min)
-- Severity: Warning
-- Evaluation: Every 5 minutes
-- ============================================================================
-- Name: Store No Orders Alert
-- Condition: WHEN count() OF query IS ABOVE 0

SELECT
  s.shop_name AS store,
  TIMESTAMPDIFF(MINUTE,
    (SELECT MAX(o.create_time) FROM luckyus_sales_order.t_order o
     WHERE o.shop_id = s.id AND o.tenant = 'LKUS'),
    NOW()
  ) AS minutes_since_last_order
FROM luckyus_opshop.t_shop_info s
WHERE s.tenant = 'LKUS'
  AND s.status = 1
  AND TIMESTAMPDIFF(MINUTE,
    (SELECT MAX(o.create_time) FROM luckyus_sales_order.t_order o
     WHERE o.shop_id = s.id AND o.tenant = 'LKUS'),
    NOW()
  ) > 30
  AND HOUR(CONVERT_TZ(NOW(), '+00:00', '-05:00')) BETWEEN 7 AND 22;

-- Alert Configuration:
-- Condition: rows returned > 0
-- For: 5m
-- Severity: warning
-- Summary: Store {{ $labels.store }} has no orders for {{ $values.minutes_since_last_order }} minutes
-- Description: The store has not received any orders in the past 30+ minutes during business hours.
-- Note: Only fires during EST business hours (7 AM - 10 PM)


-- ============================================================================
-- ALERT 4: Pending Payments > 10 for 30+ minutes
-- Severity: Warning
-- Evaluation: Every 5 minutes
-- ============================================================================
-- Name: High Pending Payments Alert
-- Condition: WHEN last() OF query IS ABOVE 10

SELECT
  SUM(metric_count) AS "value"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'order_payment_pending_30m'
  AND insert_time >= NOW() - INTERVAL 5 MINUTE;

-- Alert Configuration:
-- Condition: value > 10
-- For: 10m
-- Severity: warning
-- Summary: {{ $value }} payments pending for >30 minutes
-- Description: There are {{ $value }} payments stuck in pending state for more than 30 minutes. This may indicate payment processing issues.


-- ============================================================================
-- ALERT 5: Order Volume Drop > 50% vs Hourly Average
-- Severity: Critical
-- Evaluation: Every 5 minutes
-- ============================================================================
-- Name: Order Volume Drop Alert
-- Condition: WHEN last() OF query IS BELOW 50

SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE insert_time >= NOW() - INTERVAL 1 HOUR
     AND metric_name = 'order_all_create' AND metric_value = 0) /
    NULLIF((SELECT AVG(hourly_orders) FROM (
      SELECT SUM(metric_count) AS hourly_orders
      FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 7 DAY
        AND HOUR(insert_time) = HOUR(NOW())
        AND metric_name = 'order_all_create'
        AND metric_value = 0
      GROUP BY DATE(insert_time)
    ) AS hourly_avg), 0) * 100,
    1
  ) AS "value";

-- Alert Configuration:
-- Condition: value < 50
-- For: 15m
-- Severity: critical
-- Summary: Order volume is only {{ $value }}% of normal hourly average
-- Description: Current hour orders are significantly below the 7-day hourly average. This may indicate system issues or unusual business conditions.


-- ============================================================================
-- ALERT 6: Refund Rate > 5%
-- Severity: Warning
-- Evaluation: Every 15 minutes
-- ============================================================================
-- Name: High Refund Rate Alert
-- Condition: WHEN last() OF query IS ABOVE 5

SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_payment_inter
     WHERE insert_time >= NOW() - INTERVAL 1 DAY AND metric_name = 'order_refund_all') /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE insert_time >= NOW() - INTERVAL 1 DAY AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "value";

-- Alert Configuration:
-- Condition: value > 5
-- For: 30m
-- Severity: warning
-- Summary: Refund rate is {{ $value }}% (above 5% threshold)
-- Description: The refund rate over the last 24 hours exceeds 5%. Investigate product quality or customer satisfaction issues.


-- ============================================================================
-- ALERT 7: Shop Availability Rate < 90%
-- Severity: Warning
-- Evaluation: Every 5 minutes
-- ============================================================================
-- Name: Low Shop Availability Alert
-- Condition: WHEN last() OF query IS BELOW 90

SELECT
  ROUND(
    (SELECT metric_count FROM luckyus_iluckyhealth.t_collect_shop_inter
     WHERE metric_name = 'shop_all_now_opening' ORDER BY insert_time DESC LIMIT 1) /
    NULLIF((SELECT metric_count FROM luckyus_iluckyhealth.t_collect_shop_inter
     WHERE metric_name = 'shop_all_plan_opening' ORDER BY insert_time DESC LIMIT 1), 0) * 100,
    2
  ) AS "value";

-- Alert Configuration:
-- Condition: value < 90
-- For: 10m
-- Severity: warning
-- Summary: Shop availability is {{ $value }}% (below 90% threshold)
-- Description: More than 10% of planned-open shops are currently not operating. Check for force closures or technical issues.


-- ============================================================================
-- ALERT 8: Cancellation Rate > 10%
-- Severity: Warning
-- Evaluation: Every 15 minutes
-- ============================================================================
-- Name: High Cancellation Rate Alert
-- Condition: WHEN last() OF query IS ABOVE 10

SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE insert_time >= NOW() - INTERVAL 1 HOUR AND metric_name = 'order_all_cancel' AND metric_value = 0) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE insert_time >= NOW() - INTERVAL 1 HOUR AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "value";

-- Alert Configuration:
-- Condition: value > 10
-- For: 30m
-- Severity: warning
-- Summary: Order cancellation rate is {{ $value }}% (above 10% threshold)
-- Description: More than 10% of orders in the last hour were cancelled. Investigate causes such as out-of-stock items, long wait times, or payment issues.


-- ============================================================================
-- ALERT 9: 3rd Party Orders Spike (> 2x normal)
-- Severity: Info
-- Evaluation: Every 30 minutes
-- ============================================================================
-- Name: 3rd Party Orders Spike
-- Condition: WHEN last() OF query IS ABOVE 200

SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE insert_time >= NOW() - INTERVAL 1 HOUR
     AND metric_name = 'order_channel_create' AND metric_value IN (8, 9, 10)) /
    NULLIF((SELECT AVG(hourly_3p) FROM (
      SELECT SUM(metric_count) AS hourly_3p
      FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 7 DAY
        AND HOUR(insert_time) = HOUR(NOW())
        AND metric_name = 'order_channel_create'
        AND metric_value IN (8, 9, 10)
      GROUP BY DATE(insert_time)
    ) AS avg_3p), 0) * 100,
    1
  ) AS "value";

-- Alert Configuration:
-- Condition: value > 200
-- For: 30m
-- Severity: info
-- Summary: 3rd party orders are {{ $value }}% of normal (2x+ spike)
-- Description: 3rd party delivery orders (DoorDash, Uber Eats, Grubhub) are significantly higher than usual. Ensure stores can handle increased demand.


-- ============================================================================
-- ALERT 10: New Member Registration Drop > 50%
-- Severity: Info
-- Evaluation: Every 1 hour
-- ============================================================================
-- Name: Member Registration Drop Alert
-- Condition: WHEN last() OF query IS BELOW 50

SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_crm_inter
     WHERE DATE(insert_time) = CURDATE() AND metric_name = 'crm_member_append') /
    NULLIF((SELECT AVG(daily_members) FROM (
      SELECT SUM(metric_count) AS daily_members
      FROM luckyus_iluckyhealth.t_collect_crm_inter
      WHERE insert_time >= NOW() - INTERVAL 7 DAY
        AND metric_name = 'crm_member_append'
      GROUP BY DATE(insert_time)
    ) AS avg_members), 0) * 100,
    1
  ) AS "value";

-- Alert Configuration:
-- Condition: value < 50
-- For: 2h
-- Severity: info
-- Summary: New member registrations are {{ $value }}% of average (50%+ drop)
-- Description: New member registrations today are significantly below the 7-day average. This may indicate app issues or marketing campaign changes.


-- ============================================================================
-- ALERT NOTIFICATION CHANNELS
-- ============================================================================

/*
Recommended notification channels:

1. Critical Alerts (Payment, Order Volume Drop):
   - Slack: #ops-critical
   - PagerDuty: On-call rotation
   - Email: ops-team@luckin.com

2. Warning Alerts (Store issues, High refunds):
   - Slack: #ops-alerts
   - Email: store-ops@luckin.com

3. Info Alerts (Spikes, Drops):
   - Slack: #ops-monitoring
   - Email: analytics@luckin.com

Contact Points Configuration:
- Slack webhook integration
- PagerDuty integration for critical
- Email notifications for all
*/


-- ============================================================================
-- ALERT RULE GROUPS
-- ============================================================================

/*
Organize alerts into these groups:

1. Payment Alerts (Folder: Payment Monitoring)
   - Payment Success Rate Critical
   - High Pending Payments

2. Store Alerts (Folder: Store Operations)
   - Store Force Closed
   - Store No Orders
   - Low Shop Availability

3. Order Alerts (Folder: Order Monitoring)
   - Order Volume Drop
   - High Cancellation Rate
   - High Refund Rate

4. Growth Alerts (Folder: Business Intelligence)
   - 3rd Party Orders Spike
   - Member Registration Drop
*/


-- ============================================================================
-- SILENCE RULES (During Maintenance)
-- ============================================================================

/*
Create silences for:
- Scheduled maintenance windows
- Store closures (holidays)
- Known payment gateway maintenance
- App update deployments

Example silence matchers:
- alertname = "Store No Orders Alert" AND store =~ ".*"
  Duration: 2h (during store maintenance)
*/


-- ============================================================================
-- END OF ALERTS
-- ============================================================================
