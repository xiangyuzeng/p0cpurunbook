-- ============================================================================
-- LUCKIN COFFEE USA - GRAFANA DASHBOARD VARIABLES
-- Variable Queries for Dropdown Filters
-- ============================================================================

-- ============================================================================
-- VARIABLE: $store (Multi-select Store Dropdown)
-- ============================================================================
-- Name: store
-- Type: Query
-- Multi-value: true
-- Include All option: true
-- Data Source: aws-luckyus-opshop-rw

SELECT
  shop_name AS __text,
  shop_id AS __value
FROM luckyus_opshop.t_shop_info
WHERE tenant = 'LKUS'
  AND status = 1
ORDER BY shop_name;

-- Alternative using shop_number:
SELECT
  CONCAT(shop_name, ' (', shop_number, ')') AS __text,
  shop_number AS __value
FROM luckyus_opshop.t_shop_info
WHERE tenant = 'LKUS'
  AND status = 1
ORDER BY shop_name;


-- ============================================================================
-- VARIABLE: $channel (Multi-select Channel Dropdown)
-- ============================================================================
-- Name: channel
-- Type: Query
-- Multi-value: true
-- Include All option: true
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_value AS __value,
  CASE metric_value
    WHEN 1 THEN 'In-Store/POS'
    WHEN 2 THEN 'Mobile App'
    WHEN 3 THEN 'Mini Program/Web'
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
    ELSE CONCAT('Channel-', metric_value)
  END AS __text
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE metric_name = 'order_channel_create'
ORDER BY metric_value;


-- ============================================================================
-- VARIABLE: $channel_category (In-House vs 3rd Party)
-- ============================================================================
-- Name: channel_category
-- Type: Custom
-- Values: In-House : 1,2,3 | 3rd Party : 8,9,10 | All : 1,2,3,8,9,10

-- For Custom variable, use these options:
-- In-House : 1,2,3
-- 3rd Party : 8,9,10
-- All : 1,2,3,8,9,10


-- ============================================================================
-- VARIABLE: $order_type (Pickup vs Delivery)
-- ============================================================================
-- Name: order_type
-- Type: Query
-- Multi-value: true
-- Include All option: true
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_value AS __value,
  CASE metric_value
    WHEN 1 THEN 'Pickup'
    WHEN 2 THEN 'Delivery'
    ELSE CONCAT('Type-', metric_value)
  END AS __text
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE metric_name = 'order_type_create'
ORDER BY metric_value;


-- ============================================================================
-- VARIABLE: $tenant (Tenant/Region Dropdown)
-- ============================================================================
-- Name: tenant
-- Type: Query
-- Multi-value: false
-- Include All option: false
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_value_comment AS __value,
  metric_value_comment AS __text
FROM luckyus_iluckyhealth.t_collect_order_tenant_inter
WHERE metric_value_comment IS NOT NULL
  AND metric_value_comment != ''
ORDER BY 1;


-- ============================================================================
-- VARIABLE: $payment_provider (Payment Provider Dropdown)
-- ============================================================================
-- Name: payment_provider
-- Type: Query
-- Multi-value: true
-- Include All option: true
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_name_comment AS __value,
  metric_name_comment AS __text
FROM luckyus_iluckyhealth.t_collect_payment_inter
WHERE metric_name = 'order_pay_channel_success'
  AND metric_name_comment IS NOT NULL
ORDER BY 1;


-- ============================================================================
-- VARIABLE: $payment_gateway (Payment Gateway: Stripe/Adyen/PayPal)
-- ============================================================================
-- Name: payment_gateway
-- Type: Custom
-- Values: Stripe | Adyen | PayPal | All

-- For Custom variable, use these options:
-- Stripe
-- Adyen
-- PayPal
-- All


-- ============================================================================
-- VARIABLE: $payment_method (Payment Method: Apple/Card/Google)
-- ============================================================================
-- Name: payment_method
-- Type: Custom
-- Values: Apple Pay | Card | Google Pay | All

-- For Custom variable, use these options:
-- Apple Pay
-- Card
-- Google Pay
-- All


-- ============================================================================
-- VARIABLE: $3p_platform (3rd Party Platform Dropdown)
-- ============================================================================
-- Name: platform_3p
-- Type: Query
-- Multi-value: true
-- Include All option: true
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT
  metric_value AS __value,
  CASE metric_value
    WHEN 8 THEN 'DoorDash'
    WHEN 9 THEN 'Grubhub'
    WHEN 10 THEN 'Uber Eats'
  END AS __text
FROM luckyus_iluckyhealth.t_collect_order_inter
WHERE metric_name = 'order_channel_create'
  AND metric_value IN (8, 9, 10)
GROUP BY metric_value
ORDER BY metric_value;


-- ============================================================================
-- VARIABLE: $interval (Time Aggregation Interval)
-- ============================================================================
-- Name: interval
-- Type: Interval
-- Values: 1m, 5m, 15m, 30m, 1h, 6h, 12h, 1d
-- Auto: true (or set specific values)

-- For Interval variable, use these values:
-- 1m,5m,15m,30m,1h,6h,12h,1d


-- ============================================================================
-- VARIABLE: $metric_name (Order Metric Name)
-- ============================================================================
-- Name: metric_name
-- Type: Query
-- Multi-value: false
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_name AS __value,
  CASE metric_name
    WHEN 'order_all_create' THEN 'All Orders - Created'
    WHEN 'order_all_pay' THEN 'All Orders - Paid'
    WHEN 'order_all_done' THEN 'All Orders - Completed'
    WHEN 'order_all_cancel' THEN 'All Orders - Cancelled'
    WHEN 'order_channel_create' THEN 'By Channel - Created'
    WHEN 'order_channel_pay' THEN 'By Channel - Paid'
    WHEN 'order_channel_done' THEN 'By Channel - Completed'
    WHEN 'order_type_create' THEN 'By Type - Created'
    WHEN 'order_type_pay' THEN 'By Type - Paid'
    WHEN 'order_type_done' THEN 'By Type - Completed'
    WHEN 'order_coffee_create' THEN 'Voucher - Created'
    WHEN 'order_coffee_pay' THEN 'Voucher - Paid'
    WHEN 'order_shop_create' THEN 'Shop Orders - Created'
    WHEN 'order_shop_pay' THEN 'Shop Orders - Paid'
    ELSE metric_name
  END AS __text
FROM luckyus_iluckyhealth.t_collect_order_inter
ORDER BY metric_name;


-- ============================================================================
-- VARIABLE: $shop_metric (Shop Status Metric)
-- ============================================================================
-- Name: shop_metric
-- Type: Query
-- Multi-value: false
-- Data Source: aws-luckyus-iluckyhealth-rw

SELECT DISTINCT
  metric_name AS __value,
  CASE metric_name
    WHEN 'shop_all_now_opening' THEN 'Currently Open'
    WHEN 'shop_all_plan_opening' THEN 'Planned Open'
    WHEN 'shop_all_dispatching' THEN 'Dispatching'
    WHEN 'shop_all_forced_off' THEN 'Force Closed'
    WHEN 'shop_all_forced_off_dispatch' THEN 'Force Stop Dispatch'
    ELSE metric_name
  END AS __text
FROM luckyus_iluckyhealth.t_collect_shop_inter
WHERE metric_name LIKE 'shop_all%'
ORDER BY metric_name;


-- ============================================================================
-- VARIABLE: $day_of_week (Day of Week Filter)
-- ============================================================================
-- Name: day_of_week
-- Type: Custom
-- Values: Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday

-- For Custom variable, use these options:
-- Monday
-- Tuesday
-- Wednesday
-- Thursday
-- Friday
-- Saturday
-- Sunday


-- ============================================================================
-- VARIABLE: $hour_range (Business Hours Filter)
-- ============================================================================
-- Name: hour_range
-- Type: Custom
-- Values: All Hours : 0-23 | Morning (6-11) : 6-11 | Lunch (11-14) : 11-14 | Afternoon (14-17) : 14-17 | Evening (17-22) : 17-22

-- For Custom variable, use these options:
-- All Hours : 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23
-- Morning (6-11) : 6,7,8,9,10,11
-- Lunch (11-14) : 11,12,13,14
-- Afternoon (14-17) : 14,15,16,17
-- Evening (17-22) : 17,18,19,20,21,22


-- ============================================================================
-- VARIABLE: $comparison_period (Period Comparison)
-- ============================================================================
-- Name: comparison_period
-- Type: Custom
-- Values: Yesterday | Last Week | Last Month

-- For Custom variable, use these options:
-- Yesterday : 1 DAY
-- Last Week Same Day : 7 DAY
-- Last Month : 30 DAY


-- ============================================================================
-- USAGE EXAMPLES IN QUERIES
-- ============================================================================

-- Using $store variable in WHERE clause:
-- WHERE shop_name IN ($store)

-- Using $channel variable:
-- WHERE channel IN ($channel)

-- Using $order_type variable:
-- WHERE order_type IN ($order_type)

-- Using $tenant variable:
-- WHERE tenant = '$tenant'

-- Using $interval for time grouping:
-- GROUP BY $__timeGroup(insert_time, $interval)

-- Using time filter with Grafana macro:
-- WHERE $__timeFilter(insert_time)

-- Combined example:
/*
SELECT
  $__timeGroup(insert_time, $interval) AS time,
  shop_name,
  COUNT(*) AS orders
FROM luckyus_sales_order.t_order
WHERE $__timeFilter(create_time)
  AND tenant = '$tenant'
  AND shop_name IN ($store)
  AND channel IN ($channel)
GROUP BY 1, 2
ORDER BY 1
*/


-- ============================================================================
-- CHAINED VARIABLES (Dependent Dropdowns)
-- ============================================================================

-- Store dropdown filtered by tenant:
-- Name: store_by_tenant
-- Depends on: $tenant

SELECT
  shop_name AS __text,
  shop_id AS __value
FROM luckyus_opshop.t_shop_info
WHERE tenant = '$tenant'
  AND status = 1
ORDER BY shop_name;


-- ============================================================================
-- END OF VARIABLES
-- ============================================================================
