-- ============================================================================
-- LUCKIN COFFEE USA - MASTER OPERATIONS DASHBOARD
-- All SQL Queries for Grafana Panels
-- Generated: 2025-12-27
-- ============================================================================

-- ============================================================================
-- ROW 1: EXECUTIVE SUMMARY (6 Stats)
-- ============================================================================

-- 1.1 Orders Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Orders Today"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE metric_name = 'order_all_create'
  AND metric_value = 0
  AND DATE(insert_time) = CURDATE();

-- 1.2 Revenue Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  ROUND(SUM(pay_money), 2) AS "Revenue Today"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = CURDATE();

-- 1.3 Average Order Value
-- Panel Type: Stat
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  ROUND(AVG(pay_money), 2) AS "Avg Order Value"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = CURDATE()
  AND pay_money > 0;

-- 1.4 Active Stores
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_count AS "Active Stores"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_now_opening'
ORDER BY insert_time DESC
LIMIT 1;

-- 1.5 Payment Success Rate
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CAST(metric_count_comment AS DECIMAL(5,2)) AS "Success Rate %"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'all_tenant_payment_success'
ORDER BY insert_time DESC
LIMIT 1;

-- 1.6 New Members Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "New Members"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE metric_name = 'crm_member_append'
  AND DATE(insert_time) = CURDATE();


-- ============================================================================
-- ROW 2: REAL-TIME ORDER MONITORING
-- ============================================================================

-- 2.1 Live Order Trend (1-min buckets)
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_all_create'
  AND metric_value = 0
GROUP BY insert_time
ORDER BY insert_time;

-- 2.2 Orders by Channel (Real-time Stacked)
-- Panel Type: Time Series (Stacked)
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
    ELSE CONCAT('Channel-', metric_value)
  END AS metric,
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
GROUP BY insert_time, metric_value
ORDER BY insert_time;

-- 2.3 Current Channel Distribution (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Channel",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 2.4 Orders Last Hour vs Previous Hour
-- Panel Type: Stat with comparison
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  'Last Hour' as period,
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE insert_time >= NOW() - INTERVAL 1 HOUR
  AND metric_name = 'order_all_create'
  AND metric_value = 0
UNION ALL
SELECT
  'Previous Hour' as period,
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE insert_time >= NOW() - INTERVAL 2 HOUR
  AND insert_time < NOW() - INTERVAL 1 HOUR
  AND metric_name = 'order_all_create'
  AND metric_value = 0;


-- ============================================================================
-- ROW 3: ORDER LIFECYCLE FUNNEL
-- ============================================================================

-- 3.1 Order Funnel (Created→Paid→Done→Cancel)
-- Panel Type: Bar Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_name
    WHEN 'order_all_create' THEN '1. Created'
    WHEN 'order_all_pay' THEN '2. Paid'
    WHEN 'order_all_done' THEN '3. Completed'
    WHEN 'order_all_cancel' THEN '4. Cancelled'
  END AS "Stage",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name IN ('order_all_create', 'order_all_pay', 'order_all_done', 'order_all_cancel')
  AND metric_value = 0
GROUP BY metric_name
ORDER BY 1;

-- 3.2 Conversion Rate (Paid/Created)
-- Panel Type: Gauge 0-100%
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_pay' AND metric_value = 0) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "Conversion Rate %";

-- 3.3 Completion Rate (Done/Paid)
-- Panel Type: Gauge 0-100%
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_done' AND metric_value = 0) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_pay' AND metric_value = 0), 0) * 100,
    2
  ) AS "Completion Rate %";

-- 3.4 Cancellation Rate
-- Panel Type: Gauge with alert if >5%
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_cancel' AND metric_value = 0) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "Cancellation Rate %";

-- 3.5 Funnel Trend Over Time
-- Panel Type: Multi-line Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  CASE metric_name
    WHEN 'order_all_create' THEN 'Created'
    WHEN 'order_all_pay' THEN 'Paid'
    WHEN 'order_all_done' THEN 'Completed'
    WHEN 'order_all_cancel' THEN 'Cancelled'
  END AS metric,
  SUM(metric_count) AS value
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name IN ('order_all_create', 'order_all_pay', 'order_all_done', 'order_all_cancel')
  AND metric_value = 0
GROUP BY insert_time, metric_name
ORDER BY insert_time;


-- ============================================================================
-- ROW 4: STORE PERFORMANCE - ORDERS (from t_order)
-- ============================================================================

-- 4.1 Orders by Store (Ranking)
-- Panel Type: Horizontal Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 4.2 Store Performance Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  COUNT(*) AS "Orders",
  ROUND(SUM(pay_money), 2) AS "Revenue",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 4.3 Store Orders Over Time
-- Panel Type: Multi-line Time Series
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  shop_name AS metric,
  COUNT(*) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY DATE(create_time), shop_name
ORDER BY DATE(create_time);

-- 4.4 Top 5 Stores Trend
-- Panel Type: Line Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  shop_name AS metric,
  COUNT(*) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
  AND shop_name IN (
    SELECT shop_name FROM luckyus_sales_order.t_order
    WHERE tenant = 'LKUS' AND status = 90 AND $__timeFilter(create_time)
    GROUP BY shop_name ORDER BY COUNT(*) DESC LIMIT 5
  )
GROUP BY DATE(create_time), shop_name
ORDER BY DATE(create_time);


-- ============================================================================
-- ROW 5: STORE PERFORMANCE - REVENUE (from t_order)
-- ============================================================================

-- 5.1 Revenue by Store (Ranking)
-- Panel Type: Horizontal Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY SUM(pay_money) DESC;

-- 5.2 Store Revenue Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(SUM(pay_money), 2) AS "Revenue",
  COUNT(*) AS "Orders",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY SUM(pay_money) DESC;

-- 5.3 Store Revenue Trend
-- Panel Type: Multi-line Time Series
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  shop_name AS metric,
  ROUND(SUM(pay_money), 2) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY DATE(create_time), shop_name
ORDER BY DATE(create_time);

-- 5.4 Revenue Heatmap (Store x Hour)
-- Panel Type: Heatmap
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name, HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY shop_name, 2;


-- ============================================================================
-- ROW 6: STORE CHANNEL ANALYSIS (from t_order)
-- ============================================================================

-- 6.1 Channel Mix by Store
-- Panel Type: Stacked Bar (per store)
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  CASE channel
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Channel",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name, channel
ORDER BY shop_name, COUNT(*) DESC;

-- 6.2 Store Channel % Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  COUNT(*) AS "Total Orders",
  ROUND(SUM(CASE WHEN channel = 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "Mobile %",
  ROUND(SUM(CASE WHEN channel = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "In-Store %",
  ROUND(SUM(CASE WHEN channel IN (8,9,10) THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "3rd Party %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 6.3 3rd Party Orders by Store
-- Panel Type: Grouped Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  CASE channel
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Platform",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY shop_name, channel
ORDER BY shop_name, COUNT(*) DESC;

-- 6.4 Store with Highest 3P Share
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(SUM(CASE WHEN channel IN (8,9,10) THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "3P Share %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
HAVING COUNT(*) >= 10
ORDER BY 2 DESC;


-- ============================================================================
-- ROW 7: OVERALL CHANNEL ANALYSIS
-- ============================================================================

-- 7.1 Channel Distribution (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Channel",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 7.2 In-House vs 3rd Party (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE
    WHEN metric_value IN (1, 2, 3) THEN 'In-House (App/Web/POS)'
    WHEN metric_value IN (8, 9, 10) THEN '3rd Party (DoorDash/Uber/Grubhub)'
  END AS "Category",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
GROUP BY CASE
    WHEN metric_value IN (1, 2, 3) THEN 'In-House (App/Web/POS)'
    WHEN metric_value IN (8, 9, 10) THEN '3rd Party (DoorDash/Uber/Grubhub)'
  END
ORDER BY SUM(metric_count) DESC;

-- 7.3 Channel Trend (Stacked Area)
-- Panel Type: Time Series (Stacked Area)
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS metric,
  SUM(metric_count) AS value
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
GROUP BY DATE(insert_time), metric_value
ORDER BY DATE(insert_time);

-- 7.4 Channel Growth Comparison (WoW)
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Channel",
  SUM(CASE WHEN insert_time >= NOW() - INTERVAL 7 DAY THEN metric_count ELSE 0 END) AS "This Week",
  SUM(CASE WHEN insert_time >= NOW() - INTERVAL 14 DAY AND insert_time < NOW() - INTERVAL 7 DAY THEN metric_count ELSE 0 END) AS "Last Week"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE insert_time >= NOW() - INTERVAL 14 DAY
  AND metric_name = 'order_channel_create'
GROUP BY metric_value
ORDER BY SUM(CASE WHEN insert_time >= NOW() - INTERVAL 7 DAY THEN metric_count ELSE 0 END) DESC;


-- ============================================================================
-- ROW 8: 3RD PARTY DELIVERY DEEP DIVE
-- ============================================================================

-- 8.1 3P Platform Distribution (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_value
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Platform",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
  AND metric_value IN (8, 9, 10)
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 8.2 3P Platform Trend
-- Panel Type: Multi-line Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  CASE metric_value
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS metric,
  SUM(metric_count) AS value
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_channel_create'
  AND metric_value IN (8, 9, 10)
GROUP BY insert_time, metric_value
ORDER BY insert_time;

-- 8.3 3P Orders by Store
-- Panel Type: Horizontal Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  COUNT(*) AS "3P Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 8.4 3P Platform AOV Comparison
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  CASE channel
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Platform",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND pay_money > 0
  AND $__timeFilter(create_time)
GROUP BY channel
ORDER BY AVG(pay_money) DESC;

-- 8.5 3P Peak Hours
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "3P Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY 1;

-- 8.6 3P Revenue Comparison
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  CASE channel
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Platform",
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY channel
ORDER BY SUM(pay_money) DESC;


-- ============================================================================
-- ROW 9: ORDER TYPE ANALYSIS (Pickup vs Delivery)
-- ============================================================================

-- 9.1 Pickup vs Delivery (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE metric_value
    WHEN 1 THEN 'Pickup'
    WHEN 2 THEN 'Delivery'
  END AS "Order Type",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_type_create'
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 9.2 Pickup vs Delivery Trend
-- Panel Type: Stacked Area
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  CASE metric_value
    WHEN 1 THEN 'Pickup'
    WHEN 2 THEN 'Delivery'
  END AS metric,
  SUM(metric_count) AS value
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_type_create'
GROUP BY DATE(insert_time), metric_value
ORDER BY DATE(insert_time);

-- 9.3 Delivery Rate by Hour
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  ROUND(SUM(CASE WHEN order_type = 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "Delivery Rate %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY 1;

-- 9.4 Delivery Rate by Store
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(SUM(CASE WHEN order_type = 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "Delivery Rate %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
HAVING COUNT(*) >= 10
ORDER BY 2 DESC;


-- ============================================================================
-- ROW 10: COFFEE VOUCHER ORDERS
-- ============================================================================

-- 10.1 Coffee Voucher Orders Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Voucher Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE metric_name = 'order_coffee_create'
  AND metric_value = 0
  AND DATE(insert_time) = CURDATE();

-- 10.2 Coffee Voucher Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  SUM(metric_count) AS "Voucher Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_coffee_create'
  AND metric_value = 0
GROUP BY insert_time
ORDER BY insert_time;

-- 10.3 Voucher Conversion Rate
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_coffee_pay' AND metric_value = 0) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_coffee_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "Voucher Conversion %";

-- 10.4 Voucher vs Regular Orders
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  'Regular Orders' AS "Type",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_shop_create'
  AND metric_value = 0
UNION ALL
SELECT
  'Voucher Orders' AS "Type",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_coffee_create'
  AND metric_value = 0;


-- ============================================================================
-- ROW 11: HOURLY PATTERNS
-- ============================================================================

-- 11.1 Orders by Hour (EST)
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY 1;

-- 11.2 Revenue by Hour (EST)
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY 1;

-- 11.3 Day x Hour Heatmap
-- Panel Type: Heatmap
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DAYNAME(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Day",
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY DAYNAME(CONVERT_TZ(create_time, '+00:00', '-05:00')),
         HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY FIELD(DAYNAME(CONVERT_TZ(create_time, '+00:00', '-05:00')),
               'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'), 2;

-- 11.4 Weekday vs Weekend Pattern
-- Panel Type: Dual Line
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  CASE
    WHEN DAYOFWEEK(CONVERT_TZ(create_time, '+00:00', '-05:00')) IN (1, 7) THEN 'Weekend'
    ELSE 'Weekday'
  END AS metric,
  COUNT(*) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')),
         CASE WHEN DAYOFWEEK(CONVERT_TZ(create_time, '+00:00', '-05:00')) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END
ORDER BY 1;

-- 11.5 Peak Hours Ranking
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "Orders",
  ROUND(SUM(pay_money), 2) AS "Revenue",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY COUNT(*) DESC;


-- ============================================================================
-- ROW 12: STORE PEAK HOURS (from t_order)
-- ============================================================================

-- 12.1 Store Peak Hours Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  (SELECT HOUR(CONVERT_TZ(o2.create_time, '+00:00', '-05:00'))
   FROM luckyus_sales_order.t_order o2
   WHERE o2.shop_name = o.shop_name AND o2.tenant = 'LKUS' AND o2.status = 90 AND $__timeFilter(o2.create_time)
   GROUP BY HOUR(CONVERT_TZ(o2.create_time, '+00:00', '-05:00'))
   ORDER BY COUNT(*) DESC LIMIT 1) AS "Peak Hour 1 (EST)",
  COUNT(*) AS "Total Orders"
FROM luckyus_sales_order.t_order o
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 12.2 Store x Hour Heatmap
-- Panel Type: Heatmap
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name, HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY shop_name, 2;

-- 12.3 Store Busiest Day
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  DAYNAME(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Busiest Day",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name, DAYNAME(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY shop_name, COUNT(*) DESC;

-- 12.4 Store Average Orders by Hour
-- Panel Type: Multi-line
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "time",
  shop_name AS metric,
  ROUND(COUNT(*) / COUNT(DISTINCT DATE(create_time)), 1) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')), shop_name
ORDER BY 1;


-- ============================================================================
-- ROW 13: GROWTH & TRENDS
-- ============================================================================

-- 13.1 WoW Order Growth %
-- Panel Type: Stat with Trend
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    ((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 7 DAY AND metric_name = 'order_all_create' AND metric_value = 0) -
     (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 14 DAY AND insert_time < NOW() - INTERVAL 7 DAY
      AND metric_name = 'order_all_create' AND metric_value = 0)) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 14 DAY AND insert_time < NOW() - INTERVAL 7 DAY
      AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    1
  ) AS "WoW Growth %";

-- 13.2 MoM Order Growth %
-- Panel Type: Stat with Trend
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    ((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 30 DAY AND metric_name = 'order_all_create' AND metric_value = 0) -
     (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 60 DAY AND insert_time < NOW() - INTERVAL 30 DAY
      AND metric_name = 'order_all_create' AND metric_value = 0)) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
      WHERE insert_time >= NOW() - INTERVAL 60 DAY AND insert_time < NOW() - INTERVAL 30 DAY
      AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    1
  ) AS "MoM Growth %";

-- 13.3 WoW Revenue Growth %
-- Panel Type: Stat with Trend
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  ROUND(
    ((SELECT SUM(pay_money) FROM luckyus_sales_order.t_order
      WHERE create_time >= NOW() - INTERVAL 7 DAY AND tenant = 'LKUS' AND status = 90) -
     (SELECT SUM(pay_money) FROM luckyus_sales_order.t_order
      WHERE create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY
      AND tenant = 'LKUS' AND status = 90)) /
    NULLIF((SELECT SUM(pay_money) FROM luckyus_sales_order.t_order
      WHERE create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY
      AND tenant = 'LKUS' AND status = 90), 0) * 100,
    1
  ) AS "WoW Revenue Growth %";

-- 13.4 30-Day Order Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  SUM(metric_count) AS "Orders"
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE insert_time >= NOW() - INTERVAL 30 DAY
  AND metric_name = 'order_all_create'
  AND metric_value = 0
GROUP BY DATE(insert_time)
ORDER BY DATE(insert_time);

-- 13.5 30-Day Revenue Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE create_time >= NOW() - INTERVAL 30 DAY
  AND tenant = 'LKUS'
  AND status = 90
GROUP BY DATE(create_time)
ORDER BY DATE(create_time);


-- ============================================================================
-- ROW 14: STORE GROWTH RANKING
-- ============================================================================

-- 14.1 Store WoW Growth Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  SUM(CASE WHEN create_time >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) AS "This Week",
  SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) AS "Last Week",
  ROUND(
    (SUM(CASE WHEN create_time >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) -
     SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END)) /
    NULLIF(SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END), 0) * 100,
    1
  ) AS "Growth %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND create_time >= NOW() - INTERVAL 14 DAY
GROUP BY shop_name
ORDER BY 4 DESC;

-- 14.2 Top 3 Growing Stores
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(
    (SUM(CASE WHEN create_time >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) -
     SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END)) /
    NULLIF(SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END), 0) * 100,
    1
  ) AS "Growth %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND create_time >= NOW() - INTERVAL 14 DAY
GROUP BY shop_name
HAVING SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) >= 10
ORDER BY 2 DESC
LIMIT 3;

-- 14.3 Bottom 3 Declining Stores
-- Panel Type: Bar Chart (Alert)
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(
    (SUM(CASE WHEN create_time >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) -
     SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END)) /
    NULLIF(SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END), 0) * 100,
    1
  ) AS "Growth %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND create_time >= NOW() - INTERVAL 14 DAY
GROUP BY shop_name
HAVING SUM(CASE WHEN create_time >= NOW() - INTERVAL 14 DAY AND create_time < NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) >= 10
ORDER BY 2 ASC
LIMIT 3;

-- 14.4 Store Growth Trend
-- Panel Type: Multi-line
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  shop_name AS metric,
  COUNT(*) AS value
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY DATE(create_time), shop_name
ORDER BY DATE(create_time);


-- ============================================================================
-- ROW 15: AVERAGE ORDER VALUE ANALYSIS
-- ============================================================================

-- 15.1 Overall AOV
-- Panel Type: Stat
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  ROUND(AVG(pay_money), 2) AS "Overall AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
  AND $__timeFilter(create_time);

-- 15.2 AOV by Store
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY AVG(pay_money) DESC;

-- 15.3 AOV by Channel
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  CASE channel
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Channel",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
  AND $__timeFilter(create_time)
GROUP BY channel
ORDER BY AVG(pay_money) DESC;

-- 15.4 AOV by Hour
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
  AND $__timeFilter(create_time)
GROUP BY HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY 1;

-- 15.5 AOV Trend (30 days)
-- Panel Type: Time Series
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  DATE(create_time) AS "time",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE create_time >= NOW() - INTERVAL 30 DAY
  AND tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
GROUP BY DATE(create_time)
ORDER BY DATE(create_time);

-- 15.6 AOV: In-House vs 3P
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  CASE
    WHEN channel IN (1, 2, 3) THEN 'In-House'
    WHEN channel IN (8, 9, 10) THEN '3rd Party'
  END AS "Category",
  ROUND(AVG(pay_money), 2) AS "AOV"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND pay_money > 0
  AND $__timeFilter(create_time)
GROUP BY CASE WHEN channel IN (1, 2, 3) THEN 'In-House' WHEN channel IN (8, 9, 10) THEN '3rd Party' END
ORDER BY AVG(pay_money) DESC;


-- ============================================================================
-- ROW 16: PERIOD COMPARISONS
-- ============================================================================

-- 16.1 Today vs Yesterday (Orders)
-- Panel Type: Stat with Comparison
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  'Today' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = CURDATE()
UNION ALL
SELECT
  'Yesterday' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = DATE_SUB(CURDATE(), INTERVAL 1 DAY);

-- 16.2 Today vs Same Day Last Week
-- Panel Type: Stat with Comparison
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  'Today' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = CURDATE()
UNION ALL
SELECT
  'Last Week Same Day' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = DATE_SUB(CURDATE(), INTERVAL 7 DAY);

-- 16.3 This Week vs Last Week
-- Panel Type: Stat with Comparison
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  'This Week' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND YEARWEEK(create_time, 1) = YEARWEEK(CURDATE(), 1)
UNION ALL
SELECT
  'Last Week' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND YEARWEEK(create_time, 1) = YEARWEEK(DATE_SUB(CURDATE(), INTERVAL 7 DAY), 1);

-- 16.4 This Month vs Last Month
-- Panel Type: Stat with Comparison
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  'This Month' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND YEAR(create_time) = YEAR(CURDATE())
  AND MONTH(create_time) = MONTH(CURDATE())
UNION ALL
SELECT
  'Last Month' AS period,
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND YEAR(create_time) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
  AND MONTH(create_time) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));

-- 16.5 Revenue Comparisons (Today vs Yesterday)
-- Panel Type: Stat with Comparison
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  'Today' AS period,
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = CURDATE()
UNION ALL
SELECT
  'Yesterday' AS period,
  ROUND(SUM(pay_money), 2) AS "Revenue"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND DATE(create_time) = DATE_SUB(CURDATE(), INTERVAL 1 DAY);


-- ============================================================================
-- ROW 17: SHOP STATUS MONITORING
-- ============================================================================

-- 17.1 Shops Currently Open
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_count AS "Shops Open"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_now_opening'
ORDER BY insert_time DESC
LIMIT 1;

-- 17.2 Shops Planned to Open
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_count AS "Planned Open"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_plan_opening'
ORDER BY insert_time DESC
LIMIT 1;

-- 17.3 Availability Rate %
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT metric_count FROM luckyus_iluckyhealth.t_collect_shop_inter
     WHERE metric_name = 'shop_all_now_opening' ORDER BY insert_time DESC LIMIT 1) /
    NULLIF((SELECT metric_count FROM luckyus_iluckyhealth.t_collect_shop_inter
     WHERE metric_name = 'shop_all_plan_opening' ORDER BY insert_time DESC LIMIT 1), 0) * 100,
    2
  ) AS "Availability %";

-- 17.4 Force Closed Stores (ALERT)
-- Panel Type: Stat (Alert if > 0)
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_count AS "Force Closed"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_forced_off'
ORDER BY insert_time DESC
LIMIT 1;

-- 17.5 Shop Status Timeline
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  CASE metric_name
    WHEN 'shop_all_now_opening' THEN 'Open'
    WHEN 'shop_all_plan_opening' THEN 'Planned'
    WHEN 'shop_all_forced_off' THEN 'Force Closed'
  END AS metric,
  metric_count AS value
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE $__timeFilter(insert_time)
  AND metric_name IN ('shop_all_now_opening', 'shop_all_plan_opening', 'shop_all_forced_off')
ORDER BY insert_time;

-- 17.6 Dispatching Shops
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_count AS "Dispatching Shops"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'shop_all_dispatching'
ORDER BY insert_time DESC
LIMIT 1;


-- ============================================================================
-- ROW 18: SHOP STATUS BY TENANT
-- ============================================================================

-- 18.1 LKUS Shops Open
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "LKUS Shops Open"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'tenant_shop_now_opening'
  AND metric_name_comment = 'LKUS'
  AND insert_time >= NOW() - INTERVAL 5 MINUTE;

-- 18.2 LKUS Force Closed
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "LKUS Force Closed"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name = 'tenant_shop_forced_off'
  AND metric_name_comment = 'LKUS'
  AND insert_time >= NOW() - INTERVAL 5 MINUTE;

-- 18.3 Tenant Comparison
-- Panel Type: Table
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_name_comment AS "Tenant",
  SUM(CASE WHEN metric_name = 'tenant_shop_now_opening' THEN metric_count ELSE 0 END) AS "Open",
  SUM(CASE WHEN metric_name = 'tenant_shop_plan_opening' THEN metric_count ELSE 0 END) AS "Planned",
  SUM(CASE WHEN metric_name = 'tenant_shop_forced_off' THEN metric_count ELSE 0 END) AS "Force Closed"
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name IN ('tenant_shop_now_opening', 'tenant_shop_plan_opening', 'tenant_shop_forced_off')
  AND insert_time >= NOW() - INTERVAL 5 MINUTE
GROUP BY metric_name_comment
ORDER BY 2 DESC;


-- ============================================================================
-- ROW 19: PAYMENT ANALYTICS
-- ============================================================================

-- 19.1 Current Success Rate
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CAST(metric_count_comment AS DECIMAL(5,2)) AS "Success Rate %"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'all_tenant_payment_success'
ORDER BY insert_time DESC
LIMIT 1;

-- 19.2 Success Rate Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  insert_time AS "time",
  CAST(metric_count_comment AS DECIMAL(5,2)) AS "Success Rate %"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'all_tenant_payment_success'
ORDER BY insert_time;

-- 19.3 Failed Payments
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Failed Payments"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_payment_fail';

-- 19.4 Pending Payments
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Pending Payments"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_payment_pending';

-- 19.5 Pending >30min (ALERT)
-- Panel Type: Stat (Alert if high)
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Pending >30min"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_payment_pending_30m';

-- 19.6 Payment Amount
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Payment Amount"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_payment_amount';


-- ============================================================================
-- ROW 20: PAYMENT PROVIDER ANALYSIS
-- ============================================================================

-- 20.1 Payment by Provider (Pie)
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_name_comment AS "Provider",
  SUM(metric_count) AS "Transactions"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_pay_channel_success'
GROUP BY metric_name_comment
ORDER BY SUM(metric_count) DESC;

-- 20.2 Provider Success Rates (Table)
-- Panel Type: Table
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_name_comment AS "Provider",
  AVG(CAST(metric_count_comment AS DECIMAL(5,2))) AS "Avg Success Rate %"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_pay_channel_success_rate'
GROUP BY metric_name_comment
ORDER BY 2 DESC;

-- 20.3 Apple Pay vs Card vs Google Pay
-- Panel Type: Grouped Bar
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE
    WHEN metric_name_comment LIKE '%Apple%' THEN 'Apple Pay'
    WHEN metric_name_comment LIKE '%Card%' THEN 'Card'
    WHEN metric_name_comment LIKE '%Google%' THEN 'Google Pay'
    ELSE metric_name_comment
  END AS "Method",
  SUM(metric_count) AS "Transactions"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_pay_channel_success'
  AND (metric_name_comment LIKE '%Apple%' OR metric_name_comment LIKE '%Card%' OR metric_name_comment LIKE '%Google%')
GROUP BY CASE
    WHEN metric_name_comment LIKE '%Apple%' THEN 'Apple Pay'
    WHEN metric_name_comment LIKE '%Card%' THEN 'Card'
    WHEN metric_name_comment LIKE '%Google%' THEN 'Google Pay'
    ELSE metric_name_comment
  END
ORDER BY SUM(metric_count) DESC;

-- 20.4 Stripe vs Adyen vs PayPal
-- Panel Type: Grouped Bar
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CASE
    WHEN metric_name_comment LIKE 'Stripe%' THEN 'Stripe'
    WHEN metric_name_comment LIKE 'Adyen%' THEN 'Adyen'
    WHEN metric_name_comment LIKE 'PayPal%' THEN 'PayPal'
    ELSE 'Other'
  END AS "Provider",
  SUM(metric_count) AS "Transactions"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_pay_channel_success'
GROUP BY CASE
    WHEN metric_name_comment LIKE 'Stripe%' THEN 'Stripe'
    WHEN metric_name_comment LIKE 'Adyen%' THEN 'Adyen'
    WHEN metric_name_comment LIKE 'PayPal%' THEN 'PayPal'
    ELSE 'Other'
  END
ORDER BY SUM(metric_count) DESC;

-- 20.5 Provider Trend
-- Panel Type: Stacked Area
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  metric_name_comment AS metric,
  SUM(metric_count) AS value
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_pay_channel_success'
GROUP BY DATE(insert_time), metric_name_comment
ORDER BY DATE(insert_time);


-- ============================================================================
-- ROW 21: REFUND ANALYTICS
-- ============================================================================

-- 21.1 Total Refunds Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Refunds Today"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'order_refund_all'
  AND DATE(insert_time) = CURDATE();

-- 21.2 Successful Refunds
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Successful Refunds"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_refund_success';

-- 21.3 Refund Amount Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Refund Amount"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'order_refund_amount'
  AND DATE(insert_time) = CURDATE();

-- 21.4 Refund Rate %
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_payment_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_refund_all') /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_order_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'order_all_create' AND metric_value = 0), 0) * 100,
    2
  ) AS "Refund Rate %";

-- 21.5 Refund Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  SUM(metric_count) AS "Refunds"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_refund_all'
GROUP BY DATE(insert_time)
ORDER BY DATE(insert_time);

-- 21.6 Cumulative Refunds
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Cumulative Refund Amount"
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'order_refund_amount_accu';


-- ============================================================================
-- ROW 22: MEMBER/CRM ANALYTICS
-- ============================================================================

-- 22.1 New Members Today
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "New Members Today"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE metric_name = 'crm_member_append'
  AND DATE(insert_time) = CURDATE();

-- 22.2 New Members This Week
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "New Members This Week"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE metric_name = 'crm_member_append'
  AND insert_time >= NOW() - INTERVAL 7 DAY;

-- 22.3 Daily Registration Trend
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  SUM(metric_count) AS "New Members"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'crm_member_append'
GROUP BY DATE(insert_time)
ORDER BY DATE(insert_time);

-- 22.4 Day of Week Pattern
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DAYNAME(insert_time) AS "Day",
  SUM(metric_count) AS "New Members"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'crm_member_append'
GROUP BY DAYNAME(insert_time)
ORDER BY FIELD(DAYNAME(insert_time), 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');

-- 22.5 Cumulative Growth (Running Total)
-- Panel Type: Time Series
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  DATE(insert_time) AS "time",
  SUM(SUM(metric_count)) OVER (ORDER BY DATE(insert_time)) AS "Cumulative Members"
FROM luckyus_iluckyhealth.t_collect_crm_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'crm_member_append'
GROUP BY DATE(insert_time)
ORDER BY DATE(insert_time);

-- 22.6 WoW Member Growth %
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    ((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_crm_inter
      WHERE insert_time >= NOW() - INTERVAL 7 DAY AND metric_name = 'crm_member_append') -
     (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_crm_inter
      WHERE insert_time >= NOW() - INTERVAL 14 DAY AND insert_time < NOW() - INTERVAL 7 DAY
      AND metric_name = 'crm_member_append')) /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_crm_inter
      WHERE insert_time >= NOW() - INTERVAL 14 DAY AND insert_time < NOW() - INTERVAL 7 DAY
      AND metric_name = 'crm_member_append'), 0) * 100,
    1
  ) AS "WoW Growth %";


-- ============================================================================
-- ROW 23: MARKETING & COUPONS
-- ============================================================================

-- 23.1 Coupons Claimed
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Coupons Claimed"
FROM luckyus_iluckyhealth.t_collect_marketing_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'marketing_coupon_get';

-- 23.2 Coupons Redeemed
-- Panel Type: Stat
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  SUM(metric_count) AS "Coupons Redeemed"
FROM luckyus_iluckyhealth.t_collect_marketing_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'marketing_coupon_use';

-- 23.3 Redemption Rate %
-- Panel Type: Gauge
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  ROUND(
    (SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_marketing_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'marketing_coupon_use') /
    NULLIF((SELECT SUM(metric_count) FROM luckyus_iluckyhealth.t_collect_marketing_inter
     WHERE $__timeFilter(insert_time) AND metric_name = 'marketing_coupon_get'), 0) * 100,
    2
  ) AS "Redemption Rate %";

-- 23.4 User Segments
-- Panel Type: Pie Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CONCAT('Segment ', metric_value) AS "Segment",
  SUM(metric_count) AS "Users"
FROM luckyus_iluckyhealth.t_collect_marketing_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'group_user_normal'
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 23.5 User Types
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  CONCAT('Type ', metric_value) AS "User Type",
  SUM(metric_count) AS "Users"
FROM luckyus_iluckyhealth.t_collect_marketing_inter
WHERE $__timeFilter(insert_time)
  AND metric_name = 'group_user_type'
GROUP BY metric_value
ORDER BY SUM(metric_count) DESC;

-- 23.6 Campaign Activity
-- Panel Type: Table
-- Data Source: aws-luckyus-iluckyhealth-rw
SELECT
  metric_name AS "Campaign Metric",
  metric_value AS "Status",
  SUM(metric_count) AS "Count"
FROM luckyus_iluckyhealth.t_collect_marketing_inter
WHERE $__timeFilter(insert_time)
  AND metric_name LIKE 'contact_activity%'
GROUP BY metric_name, metric_value
ORDER BY metric_name, metric_value;


-- ============================================================================
-- ROW 24: STORES WITH NO ORDERS (ALERT)
-- ============================================================================

-- 24.1 Stores with 0 Orders (30 min)
-- Panel Type: Stat (Alert)
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  COUNT(*) AS "Stores with 0 Orders"
FROM luckyus_opshop.t_shop_info s
WHERE s.tenant = 'LKUS'
  AND s.status = 1
  AND NOT EXISTS (
    SELECT 1 FROM luckyus_sales_order.t_order o
    WHERE o.shop_id = s.id
      AND o.tenant = 'LKUS'
      AND o.create_time >= NOW() - INTERVAL 30 MINUTE
  );

-- 24.2 Store Order Alert Table
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  s.shop_name AS "Store",
  s.shop_number AS "Store #",
  (SELECT MAX(o.create_time) FROM luckyus_sales_order.t_order o
   WHERE o.shop_id = s.id AND o.tenant = 'LKUS') AS "Last Order Time"
FROM luckyus_opshop.t_shop_info s
WHERE s.tenant = 'LKUS'
  AND s.status = 1
  AND NOT EXISTS (
    SELECT 1 FROM luckyus_sales_order.t_order o
    WHERE o.shop_id = s.id
      AND o.tenant = 'LKUS'
      AND o.create_time >= NOW() - INTERVAL 30 MINUTE
  )
ORDER BY 3 DESC;

-- 24.3 Order Gap Duration
-- Panel Type: Table
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  s.shop_name AS "Store",
  TIMESTAMPDIFF(MINUTE,
    (SELECT MAX(o.create_time) FROM luckyus_sales_order.t_order o
     WHERE o.shop_id = s.id AND o.tenant = 'LKUS'),
    NOW()
  ) AS "Minutes Since Last Order"
FROM luckyus_opshop.t_shop_info s
WHERE s.tenant = 'LKUS'
  AND s.status = 1
ORDER BY 2 DESC;


-- ============================================================================
-- ROW 25: DELIVERY HOTSPOTS
-- ============================================================================

-- 25.1 Top Delivery Stores
-- Panel Type: Horizontal Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  COUNT(*) AS "Delivery Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY shop_name
ORDER BY COUNT(*) DESC;

-- 25.2 Delivery by Platform by Store
-- Panel Type: Grouped Horizontal Bar
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  CASE channel
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS "Platform",
  COUNT(*) AS "Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY shop_name, channel
ORDER BY shop_name, COUNT(*) DESC;

-- 25.3 Delivery % by Store
-- Panel Type: Bar Chart
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  ROUND(SUM(CASE WHEN channel IN (8,9,10) THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS "Delivery %"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND $__timeFilter(create_time)
GROUP BY shop_name
HAVING COUNT(*) >= 10
ORDER BY 2 DESC;

-- 25.4 Delivery Hours by Store
-- Panel Type: Heatmap
-- Data Source: aws-luckyus-salesorder-rw
SELECT
  shop_name AS "Store",
  HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00')) AS "Hour (EST)",
  COUNT(*) AS "Delivery Orders"
FROM luckyus_sales_order.t_order
WHERE tenant = 'LKUS'
  AND status = 90
  AND channel IN (8, 9, 10)
  AND $__timeFilter(create_time)
GROUP BY shop_name, HOUR(CONVERT_TZ(create_time, '+00:00', '-05:00'))
ORDER BY shop_name, 2;


-- ============================================================================
-- END OF QUERIES
-- ============================================================================
