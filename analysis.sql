/* =========================================================
   E-commerce Sales & Customer Retention Analysis (Olist)
   Database: MySQL 8+
   Time range: 2016-09 to 2018-10
========================================================= */

 /* =========================
    1) DATA EXPLORATION
 ========================= */

/* Total number of unique orders */
SELECT
    COUNT(DISTINCT order_id) AS total_orders
FROM orders;

/* Total number of unique customers */
SELECT
    COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers;

/* Total revenue */
SELECT
    ROUND(SUM(payment_value), 2) AS total_revenue
FROM order_payments;

/* Date range */
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM orders;



 /* =========================
    2) KPI ANALYSIS
 ========================= */

/* KPI 1: Monthly revenue */
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    ROUND(SUM(op.payment_value), 2) AS revenue
FROM orders o
JOIN order_payments op
    ON op.order_id = o.order_id
GROUP BY order_month
ORDER BY order_month;


/* KPI 2: Average Order Value (AOV) calculated at order level
   (Orders may contain multiple payments) */
SELECT
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT
        order_id,
        SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id
) t;


 /* =========================
    3) PRODUCT PERFORMANCE
 ========================= */

/* Top 10 product categories by revenue (translated to EN) */

WITH top_categories AS (
    SELECT
        p.product_category_name,
        SUM(oi.price) AS total_revenue
    FROM products p
    JOIN order_items oi
        ON oi.product_id = p.product_id
    GROUP BY p.product_category_name
    ORDER BY total_revenue DESC
    LIMIT 10
)
SELECT
    CASE
        WHEN tc.product_category_name = 'beleza_saude' THEN 'Health & Beauty'
        WHEN tc.product_category_name = 'relogios_presentes' THEN 'Watches & Gifts'
        WHEN tc.product_category_name = 'cama_mesa_banho' THEN 'Home & Living'
        WHEN tc.product_category_name = 'esporte_lazer' THEN 'Sports & Leisure'
        WHEN tc.product_category_name = 'informatica_acessorios' THEN 'IT Accessories'
        WHEN tc.product_category_name = 'moveis_decoracao' THEN 'Furniture & Decor'
        WHEN tc.product_category_name = 'cool_stuff' THEN 'Lifestyle Products'
        WHEN tc.product_category_name = 'utilidades_domesticas' THEN 'Home Essentials'
        WHEN tc.product_category_name = 'automotivo' THEN 'Automotive'
        WHEN tc.product_category_name = 'ferramentas_jardim' THEN 'Garden Tools'
        ELSE tc.product_category_name
    END AS product_category,
    ROUND(tc.total_revenue, 2) AS total_revenue
FROM top_categories tc
ORDER BY total_revenue DESC;


 /* =========================
    4) CUSTOMER BEHAVIOR & RETENTION
 ========================= */

/* Repeat customers rate (share of customers who made 2+ orders) */
SELECT
    customer_type,
    COUNT(*) AS total_customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
FROM (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
) t
GROUP BY customer_type
ORDER BY customer_percentage DESC;

/* Revenue share by customer type */
SELECT
    customer_type,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(100 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS revenue_percentage
FROM (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type,
        SUM(op.payment_value) AS total_revenue
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    JOIN order_payments op
        ON op.order_id = o.order_id
    GROUP BY c.customer_unique_id
) t
GROUP BY customer_type
ORDER BY revenue_percentage DESC;

/* Customer purchase frequency distribution (%) */
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN '1 order'
            WHEN COUNT(DISTINCT o.order_id) BETWEEN 2 AND 3 THEN '2-3 orders'
            ELSE '4+ orders'
        END AS customer_segment
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
) t
GROUP BY customer_segment
ORDER BY percentage DESC;

/* Average revenue per customer type */
SELECT
    customer_type,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer
FROM (
    SELECT
        c.customer_unique_id,
        CASE
            WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type,
        SUM(op.payment_value) AS total_revenue
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    JOIN order_payments op
        ON op.order_id = o.order_id
    GROUP BY c.customer_unique_id
) t
GROUP BY customer_type
ORDER BY avg_revenue_per_customer DESC;

/* Revenue concentration: Top 10% vs Bottom 90% customers */
WITH ranked_customers AS (
    SELECT
        c.customer_unique_id,
        SUM(op.payment_value) AS total_revenue,
        NTILE(10) OVER (ORDER BY SUM(op.payment_value) DESC) AS revenue_decile
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    JOIN order_payments op
        ON op.order_id = o.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN revenue_decile = 1 THEN 'Top 10%'
        ELSE 'Bottom 90%'
    END AS customer_group,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(100 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS revenue_percentage
FROM ranked_customers
GROUP BY customer_group
ORDER BY revenue_percentage DESC;