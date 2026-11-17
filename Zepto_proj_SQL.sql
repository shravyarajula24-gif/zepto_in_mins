CREATE DATABASE zepto_in_mins;
USE zepto_in_mins;

-- 1. dark_stores
CREATE TABLE dark_stores (
    store_id INT PRIMARY KEY,
    location_name VARCHAR(50),
    manager_name VARCHAR(50),
    capacity_per_day INT,
    opening_date DATE
);

-- 2. hub_staff (FK)
CREATE TABLE hub_staff (
    staff_id INT PRIMARY KEY,
    staff_name VARCHAR(50),
    role_type VARCHAR(20),
    store_id INT,
    hired_on DATE,
    rating DECIMAL(2 , 1 ),
    FOREIGN KEY (store_id)
        REFERENCES dark_stores (store_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- 3. inventory_items
CREATE TABLE inventory_items (
    item_id INT PRIMARY KEY,
    item_title VARCHAR(50),
    category VARCHAR(30),
    vendor_name VARCHAR(50),
    unit_price DECIMAL(10 , 2 ),
    stock_qty INT
);

-- 4. instant_orders (3 FKs)
CREATE TABLE instant_orders (
    order_ref_id INT PRIMARY KEY,
    buyer_name VARCHAR(50),
    buyer_locality VARCHAR(50),
    store_id INT,
    item_id INT,
    staff_id INT,
    order_value INT,
    ordered_at DATETIME,
    promised_minutes INT,
    actual_minutes INT,
    delivery_status VARCHAR(20),
    payment_mode VARCHAR(10),
    FOREIGN KEY (store_id)
        REFERENCES dark_stores (store_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (item_id)
        REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (staff_id)
        REFERENCES hub_staff (staff_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

SELECT 
    *
FROM
    dark_stores;
SELECT 
    *
FROM
    hub_staff;
SELECT 
    *
FROM
    instant_orders;
SELECT 
    *
FROM
    inventory_items;

-- Q1. Calculate the total revenue generated from all successfully delivered orders?
SELECT 
    SUM(order_value) AS total_revenue
FROM
    instant_orders
WHERE
    delivery_status = 'Delivered';
-- Q2. How many orders were cancelled?
SELECT 
    COUNT(*) AS cancelled_orders
FROM
    instant_orders
WHERE
    delivery_status = 'Cancelled';
-- Q3. Show all dark stores details.
SELECT 
    *
FROM
    dark_stores;
-- Q4. List items with stock less than 50 (Low Stock Alert)?
SELECT 
    item_title, category, stock_qty
FROM
    inventory_items
WHERE
    stock_qty < 50
ORDER BY stock_qty ASC;
-- Q5. How many orders were paid using COD?
SELECT 
    COUNT(*) AS cod_orders
FROM
    instant_orders
WHERE
    payment_mode = 'COD';
-- Q6. How many orders did each store receive?

SELECT 
    ds.location_name, COUNT(o.order_ref_id) AS total_orders
FROM
    dark_stores ds
        LEFT JOIN
    instant_orders o ON ds.store_id = o.store_id
GROUP BY ds.location_name;
-- Q7. Category-wise item count and average price?
SELECT 
    category,
    COUNT(*) AS total_items,
    ROUND(AVG(unit_price), 0) AS avg_price
FROM
    inventory_items
GROUP BY category;
-- Q8. How many deliveries did each rider complete?
SELECT 
    hs.staff_name, COUNT(o.order_ref_id) AS deliveries
FROM
    hub_staff hs
        JOIN
    instant_orders o ON hs.staff_id = o.staff_id
WHERE
    hs.role_type = 'Rider'
GROUP BY hs.staff_name
ORDER BY deliveries DESC;
-- Q9. What are the total sales by payment mode?
SELECT
    payment_mode,
    SUM(order_value) AS total_revenue
FROM instant_orders
GROUP BY payment_mode
HAVING SUM(order_value) >
(
    SELECT AVG(payment_revenue)
    FROM
    (
        SELECT SUM(order_value) AS payment_revenue
        FROM instant_orders
        GROUP BY payment_mode
    ) AS temp
);
-- Q10. What is the daily order count?
SELECT 
    DATE(ordered_at) AS order_date, COUNT(*) AS daily_orders
FROM
    instant_orders
GROUP BY DATE(ordered_at)
ORDER BY order_date;
-- Q11. Which orders were delivered faster than average delivery time?
SELECT 
    *
FROM
    instant_orders
WHERE
    actual_minutes < (SELECT 
            AVG(actual_minutes)
        FROM
            instant_orders
        WHERE
            delivery_status = 'Delivered')
        AND delivery_status = 'Delivered';
-- Q12. Find the top five localities based on average order value.
SELECT
    locality,
    orders,
    avg_value
FROM
(
    SELECT
        buyer_locality AS locality,
        COUNT(*) AS orders,
        ROUND(AVG(order_value), 2) AS avg_value
    FROM instant_orders
    GROUP BY buyer_locality
) AS locality_data
ORDER BY avg_value DESC
LIMIT 5;	
-- Q13. Show delayed orders with store and rider details?
SELECT 
    o.order_ref_id,
    ds.location_name,
    hs.staff_name,
    o.promised_minutes,
    o.actual_minutes,
    (o.actual_minutes - o.promised_minutes) AS delay
FROM
    instant_orders o
        JOIN
    dark_stores ds ON o.store_id = ds.store_id
        JOIN
    hub_staff hs ON o.staff_id = hs.staff_id
WHERE
    o.actual_minutes > o.promised_minutes
        AND o.delivery_status = 'Delivered'
ORDER BY delay DESC;
-- Q14. What are the top 5 most ordered products?
SELECT
    item_title,
    times_ordered,
    product_rank
FROM
(
    SELECT
        ii.item_title,
        COUNT(o.order_ref_id) AS times_ordered,
        RANK() OVER (
            ORDER BY COUNT(o.order_ref_id) DESC
        ) AS product_rank
    FROM inventory_items ii
    JOIN instant_orders o
        ON ii.item_id = o.item_id
    GROUP BY ii.item_id, ii.item_title
) AS ranked_products
WHERE product_rank <= 5;
-- Q15. What is the store-wise delay percentage?
SELECT 
    ds.location_name,
    COUNT(o.order_ref_id) AS total,
    SUM(CASE
        WHEN o.actual_minutes > o.promised_minutes THEN 1
        ELSE 0
    END) AS delay,
    ROUND(SUM(CASE
                WHEN o.actual_minutes > o.promised_minutes THEN 1
                ELSE 0
            END) * 100.0 / COUNT(*),
            1) AS delay_percent
FROM
    dark_stores ds
        JOIN
    instant_orders o ON ds.store_id = o.store_id
GROUP BY ds.location_name
ORDER BY delay_percent DESC;

-- Q16. Rank the best riders by average delivery time using window function?
SELECT hs.staff_name, ROUND(AVG(o.actual_minutes),1) AS avg_time, RANK() OVER (ORDER BY AVG(o.actual_minutes) ASC) AS best_rank 
FROM hub_staff hs JOIN instant_orders o ON hs.staff_id=o.staff_id 
WHERE hs.role_type='Rider' AND o.delivery_status='Delivered' 
GROUP BY hs.staff_name ORDER BY best_rank;
-- Q17. What is the best-selling category in each store?
WITH category_sales AS (
    SELECT
        ds.location_name,
        ii.category,
        COUNT(*) AS total_orders,
        RANK() OVER (
            PARTITION BY ds.location_name
            ORDER BY COUNT(*) DESC
        ) AS rnk
    FROM instant_orders o
    JOIN dark_stores ds ON o.store_id = ds.store_id
    JOIN inventory_items ii ON o.item_id = ii.item_id
    GROUP BY ds.location_name, ii.category
)
SELECT
    location_name,
    category,
    total_orders
FROM category_sales
WHERE rnk = 1;
-- Q18. When is the business peak - Morning, Afternoon, or Evening?
SELECT 
    CASE
        WHEN HOUR(ordered_at) BETWEEN 6 AND 12 THEN 'Morning'
        WHEN HOUR(ordered_at) BETWEEN 13 AND 17 THEN 'Afternoon'
        WHEN HOUR(ordered_at) BETWEEN 18 AND 22 THEN 'Evening'
        ELSE 'Night'
    END AS time_slot,
    COUNT(*) AS orders,
    SUM(order_value) AS revenue
FROM
    instant_orders
GROUP BY time_slot
ORDER BY revenue DESC;
-- Q19. What is the average delivery time of high-rated staff (4.5+ rating)?
CREATE VIEW monthly_trends AS
SELECT
    YEAR(ordered_at) AS order_year,
    MONTH(ordered_at) AS order_month,
    COUNT(*) AS total_orders,
    SUM(order_value) AS total_revenue
FROM instant_orders
GROUP BY YEAR(ordered_at), MONTH(ordered_at);

SELECT *
FROM monthly_trends
ORDER BY order_year, order_month;

-- Q20. Who are the top 10 most valuable customers?
DELIMITER //

CREATE PROCEDURE sp_revenue_by_status(
    IN p_status VARCHAR(30)
)
BEGIN
    SELECT
        p_status AS delivery_status,
        COUNT(*) AS total_orders,
        COALESCE(SUM(order_value), 0) AS total_revenue
    FROM instant_orders
    WHERE delivery_status = p_status;
END //

DELIMITER ;

CALL sp_revenue_by_status('Delivered');