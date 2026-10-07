SELECT *
FROM production.categories

SELECT *
FROM production.brands

SELECT *
FROM production.products

SELECT *
FROM production.stocks

SELECT *
FROM sales.customers

SELECT *
FROM sales.stores


SELECT *
FROM sales.staffs
-- 10 staff members, 1 NULL for manager_id

SELECT *
FROM sales.orders

SELECT *
FROM sales.order_items

-- Important database: production.stocks, production.products, sales.orders, sales.order_items
-- 1. STOCKS DATABASE
SELECT *
FROM production.stocks

SELECT
    store_id, product_id, SUM(quantity) AS total_quantity
FROM production.stocks
GROUP BY store_id, product_id;

SELECT
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    COUNT(*) AS total_stocks,
    COUNT(DISTINCT store_id) AS total_stores,
    COUNT(DISTINCT product_id) AS total_distinct_products,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_null
FROM production.stocks

SELECT
    store_id, product_id, quantity
FROM production.stocks
WHERE quantity = 0

-- 2. Products database
SELECT *
FROM production.products

SELECT
    MIN(list_price) AS min_list_price,
    MAX(list_price) AS max_list_price,
    COUNT(*) AS total_products,
    COUNT(*) FILTER (WHERE list_price IS NULL) AS price_null,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_null,
    COUNT(*) FILTER (WHERE brand_id IS NULL) AS brand_null,
    COUNT(*) FILTER (WHERE category_id IS NULL) AS category_null,
    COUNT(*) FILTER (WHERE model_year IS NULL) AS model_year_null,
    COUNT(DISTINCT product_id) AS total_distinct_products
FROM production.products;

-- 3. Orders database
SELECT*
FROM sales.orders;

SELECT
    COUNT(*) AS total_orders
FROM sales.orders;

SELECT
    MIN(order_date) AS min_date,
    MAX(order_date) AS max_date
FROM sales.orders;

SELECT
    COUNT(*) AS total_orders,
    COUNT(customer_id) AS total_customers_not_null,
    COUNT(*) - COUNT(customer_id) AS customers_null
FROM sales.orders;
    

--4. Order items database
SELECT *
FROM sales.order_items;

SELECT
    SUM(quantity) AS total_quantity,
    SUM(list_price) AS total_list_price,
    SUM(discount) AS total_discount
FROM sales.order_items
GROUP BY order_id,item_id,product_id;

SELECT
    MIN(list_price) AS min_list_price,
    MAX(list_price) AS max_list_price,
    MIN(discount) AS min_discount,
    MAX(discount) AS max_discount,
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    COUNT(*) AS total_order_items,
    COUNT(*) FILTER (WHERE discount IS NULL) AS discount_null,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_null
FROM sales.order_items
WHERE list_price IS NOT NULL
  AND discount IS NOT NULL;

-- After aggregating, the table is unchanged so the data was already aggregated

SELECT o.customer_id
FROM sales.orders o
LEFT JOIN sales.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Verify again whether every order has a valid customer
SELECT orders.order_id, orders.customer_id
FROM sales.orders orders
LEFT JOIN sales.customers customers ON orders.customer_id = customers.customer_id
WHERE customers.customer_id IS NULL;
-- Verify again whether every order item has a valid order
SELECT order_items.order_id, order_items.item_id
FROM sales.order_items order_items
LEFT JOIN sales.orders orders ON order_items.order_id = orders.order_id
WHERE orders.order_id IS NULL;
-- Verify whether every order item has a valid product
SELECT order_items.order_id, order_items.item_id, order_items.product_id
FROM sales.order_items order_items
LEFT JOIN production.products products ON order_items.product_id = products.product_id
WHERE products.product_id IS NULL;
-- Verify whether every order has a valid store
SELECT orders.order_id, orders.store_id
FROM sales.orders orders
LEFT JOIN sales.stores stores ON orders.store_id = stores.store_id
WHERE stores.store_id IS NULL;


/*
STANDARDIZE THE DATA
In the customers database, the input are standardized. first_name and last_name have the first capital letter, phone numbers are standardized to the format (XXX) XXX-XXXX, and email addresses are converted to lowercase.
In the products database, product names are standardized to have the first letter of each word capitalized.
In the orders database, order dates are standardized to the format YYYY-MM-DD.
In the order_items database, list prices and discounts are standardized to two decimal places.
*/

-- Which products generate the highest gross and net sales
SELECT
    product_id,
    SUM(quantity * list_price) AS total_gross_sales,
    SUM(quantity * list_price * discount) AS total_discount,
    SUM(quantity * list_price * (1 - discount)) AS total_net_sales
FROM sales.order_items
GROUP BY product_id
ORDER BY total_net_sales DESC, total_gross_sales DESC
LIMIT 10;

-- How does discount % impact sales ?
SELECT
    CASE 
        WHEN discount = 0 THEN '0% (No Discount)'
        WHEN discount > 0 AND discount <= 0.05 THEN '1% - 5%'
        WHEN discount > 0.05 AND discount <= 0.10 THEN '6% - 10%'
        WHEN discount > 0.10 AND discount <= 0.20 THEN '11% - 20%'
        ELSE 'Over 20%'
    END AS discount_tier,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_units_sold,
    ROUND(AVG(quantity), 2) AS avg_units_per_order,
    ROUND(SUM(quantity * list_price), 2) AS total_gross_sales,
    ROUND(SUM(quantity * list_price * discount), 2) AS total_discount_given,
    ROUND(SUM(quantity * list_price * (1 - discount)), 2) AS total_net_sales
FROM sales.order_items
GROUP BY 1
ORDER BY MIN(discount);


-- DimCustomer
DROP TABLE IF EXISTS public.DimCustomer CASCADE;

SELECT *
INTO public.DimCustomer
FROM sales.customers;
ALTER TABLE public.DimCustomer
ADD CONSTRAINT PK_DimCustomer PRIMARY KEY (customer_id);

SELECT *
FROM public.DimCustomer;

-- DimProduct
-- 1. Create table
DROP TABLE IF EXISTS public.DimProduct CASCADE;
CREATE TABLE public.DimProduct
(
    Product_ID INTEGER PRIMARY KEY,
    Product_Name VARCHAR(255),
    Brand_ID INTEGER,
    Brand_Name VARCHAR(255),
    Category_ID INTEGER,
    Category_Name VARCHAR(255),
    Model_Year INTEGER,
    List_Price DECIMAL(10,2)
);
-- 2. Load data
INSERT INTO public.DimProduct
(
    Product_ID,
    Product_Name,
    Brand_ID,
    Brand_Name,
    Category_ID,
    Category_Name,
    Model_Year,
    List_Price
)
SELECT
    p.product_id,
    p.product_name,
    p.brand_id,
    b.brand_name,
    p.category_id,
    c.category_name,
    p.model_year,
    p.list_price
FROM production.products p
LEFT JOIN production.brands b ON p.brand_id = b.brand_id
LEFT JOIN production.categories c ON p.category_id = c.category_id;

SELECT *
FROM public.DimProduct;
-- I join categories and brands table into products table
-- DimStore
-- 1. Create table
DROP TABLE IF EXISTS public.DimStore CASCADE;

SELECT *
INTO public.DimStore
FROM sales.stores;

ALTER TABLE public.DimStore
ADD CONSTRAINT PK_DimStore PRIMARY KEY (store_id);

SELECT *
FROM public.DimStore;
-- DimStaff
DROP TABLE IF EXISTS public.DimStaff CASCADE;

CREATE TABLE public.DimStaff
(
    Staff_ID INTEGER PRIMARY KEY,
    Full_Name VARCHAR(255),
    Email VARCHAR(255),
    Phone VARCHAR(20),
    Active SMALLINT NOT NULL,
    Store_ID INT,
    Store_Adress VARCHAR(500),
    Store_Name VARCHAR(255),
    Manager_ID INT
);
INSERT INTO public.DimStaff
(
    Staff_ID,
    Full_Name,
    Email,
    Phone,
    Active,
    Store_ID,
    Store_Name,
    Store_Adress,
    Manager_ID
)
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name AS Full_Name,
    s.email,
    s.phone,
    s.active,
    s.store_id,
    st.store_name,
    CONCAT(st.street, ', ', st.city, ', ', st.state, ' ', st.zip_code) AS Store_Adress,
    s.manager_id
FROM sales.staffs s
LEFT JOIN sales.stores st ON s.store_id = st.store_id;

SELECT *
FROM public.DimStaff;

SELECT *
FROM sales.stores

SELECT *
FROM sales.staffs
-- Fabiola has not been assigned a manager
-- DimDate
DROP TABLE IF EXISTS public.DimDate CASCADE;
CREATE TABLE public.DimDate
(
    Date DATE PRIMARY KEY,
    Year INTEGER,
    Quarter INTEGER,
    Month_number INTEGER,
    Month_name VARCHAR(20),
    Year_month VARCHAR(20),
    Weekday VARCHAR(10),
    Day_of_month INTEGER,
    Day_of_week INTEGER,
    Day_name VARCHAR(20)
);
INSERT INTO public.DimDate
SELECT
    d::DATE,
    EXTRACT(YEAR FROM d)::INTEGER,
    EXTRACT(QUARTER FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    TRIM(TO_CHAR(d, 'Month')),
    TO_CHAR(d, 'YYYY-MM'),
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN 'Weekend' ELSE 'Weekday' END,
    EXTRACT(DAY FROM d)::INTEGER,
    EXTRACT(ISODOW FROM d)::INTEGER,
    TRIM(TO_CHAR(d, 'Day'))
FROM generate_series(
        (SELECT MIN(order_date) FROM sales.orders)::DATE,
        (SELECT MAX(order_date) FROM sales.orders)::DATE,
        INTERVAL '1 day'
     ) AS d;
SELECT *
FROM public.DimDate;
-- FactSales table
DROP TABLE IF EXISTS public.FactSales CASCADE;
CREATE TABLE public.FactSales
(
    SalesKey BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    Order_ID INTEGER NOT NULL,

    Date DATE NOT NULL,
    Customer_ID INTEGER NOT NULL,
    Product_ID INTEGER NOT NULL,
    Store_ID INTEGER NOT NULL,
    Staff_ID INTEGER NOT NULL,

    Quantity INTEGER NOT NULL,

    Unit_Price NUMERIC(18,2),
    Discount_Rate NUMERIC(5,4),

    Gross_Sales NUMERIC(18,2),
    Discount_Amount NUMERIC(18,2),
    Sales_Amount NUMERIC(18,2)
);

INSERT INTO public.FactSales
(
    Order_ID,
    Date,
    Customer_ID,
    Product_ID,
    Store_ID,
    Staff_ID,
    Quantity,
    Unit_Price,
    Discount_Rate,
    Gross_Sales,
    Discount_Amount,
    Sales_Amount
)
SELECT
    o.order_id,
    o.order_date,
    dc.Customer_Id,
    dp.Product_Id,
    ds.Store_Id,
    dst.Staff_Id,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.quantity * oi.list_price AS Gross_Sales,
    oi.quantity * oi.list_price * oi.discount AS Discount_Amount,
    oi.quantity * oi.list_price * (1 - oi.discount) AS Sales_Amount

FROM sales.orders o

INNER JOIN sales.order_items oi
    ON o.order_id = oi.order_id

INNER JOIN public.DimCustomer dc
    ON o.customer_id = dc.Customer_Id

INNER JOIN public.DimProduct dp
    ON oi.product_id = dp.Product_Id

INNER JOIN public.DimStore ds
    ON o.store_id = ds.Store_Id

INNER JOIN public.DimStaff dst
    ON o.staff_id = dst.Staff_Id;

SELECT *
FROM public.FactSales;

-- Create FactInventory table
DROP TABLE IF EXISTS public.FactInventory CASCADE;
CREATE TABLE public.FactInventory
(
    Product_ID INT NOT NULL,
    Store_ID INT NOT NULL,
    Quantity INT NOT NULL,

    PRIMARY KEY (Product_ID, Store_ID), -- A product can exist in multiple stores, and each store can have multiple products. Neither Product_ID nor Store_ID is unique.

    FOREIGN KEY (Product_ID) REFERENCES public.DimProduct (Product_ID),
    FOREIGN KEY (Store_ID) REFERENCES public.DimStore (Store_ID)
);
INSERT INTO public.FactInventory (Product_ID, Store_ID, Quantity)
SELECT
    Product_ID,
    Store_ID,
    Quantity
FROM production.stocks;
SELECT *
FROM public.FactInventory;

-- Check tables
SELECT 'FactSales'     AS table_name, COUNT(*) FROM public.FactSales
UNION ALL
SELECT 'FactInventory', COUNT(*) FROM public.FactInventory
UNION ALL
SELECT 'DimCustomer',   COUNT(*) FROM public.DimCustomer
UNION ALL
SELECT 'DimProduct',    COUNT(*) FROM public.DimProduct
UNION ALL
SELECT 'DimStore',      COUNT(*) FROM public.DimStore
UNION ALL
SELECT 'DimStaff',      COUNT(*) FROM public.DimStaff
UNION ALL
SELECT 'DimDate',       COUNT(*) FROM public.DimDate;

SELECT relname AS table_name, n_live_tup AS approx_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY relname;

DROP TABLE dbo_dimcustomer,dim_date;