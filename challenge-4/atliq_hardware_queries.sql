USE `gdb023`;

SELECT * FROM dim_customer;
SELECT * FROM dim_product;
SELECT * FROM fact_gross_price;
SELECT * FROM fact_manufacturing_cost;
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM fact_sales_monthly;
SELECT * FROM dim_product;
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

CREATE VIEW REQ_1 AS 
SELECT distinct(market)
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

SELECT * FROM REQ_1;

-- 2. What is the percentage of unique product increase in 2021 vs. 2020?
CREATE VIEW REQ_2 AS (
WITH CTE_unique_product_2020 AS (

SELECT COUNT(DISTINCT(product_code)) AS unique_products_2020
FROM fact_sales_monthly
WHERE fiscal_year = 2020 
),
CTE_unique_product_2021 AS 
(
SELECT COUNT(DISTINCT(product_code)) AS unique_products_2021
FROM fact_sales_monthly
WHERE fiscal_year = 2021 
)
SELECT 
unique_products_2020, unique_products_2021, 
((unique_products_2021-unique_products_2020)/unique_products_2020)*100 AS PERCENTAGE_CHANGE
FROM CTE_unique_product_2020 , CTE_unique_product_2021
);

SELECT * FROM REQ_2;

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 

CREATE VIEW REQ_3 AS 
SELECT segment, count(DISTINCT product_code) AS PRODUCT_COUNT 
FROM dim_product
GROUP BY segment
ORDER BY PRODUCT_COUNT DESC;

SELECT * FROM REQ_3;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 

CREATE VIEW REQ_4 AS
(
WITH CTE_2020 AS 
(
SELECT prod.segment , count(DISTINCT prod.product_code) AS UNIQUE_PRODUCT_COUNT_2020 
FROM dim_product prod
INNER JOIN fact_sales_monthly  sm
ON prod.product_code = sm.product_code
WHERE fiscal_year = 2020
GROUP BY segment 
),
CTE_2021 AS 
(
SELECT prod.segment , count(DISTINCT prod.product_code) AS UNIQUE_PRODUCT_COUNT_2021 
FROM dim_product prod
INNER JOIN fact_sales_monthly  sm
ON prod.product_code = sm.product_code
WHERE fiscal_year = 2021
GROUP BY segment 
)
SELECT CTE_2020.segment,
UNIQUE_PRODUCT_COUNT_2020, UNIQUE_PRODUCT_COUNT_2021,
UNIQUE_PRODUCT_COUNT_2021-UNIQUE_PRODUCT_COUNT_2020 as Difference
from CTE_2020
JOIN CTE_2021 ON CTE_2020.segment = CTE_2021.segment
ORDER BY difference DESC
);
DROP VIEW REQ_4;
SELECT * FROM REQ_4;

-- 5. Get the products that have the highest and lowest manufacturing costs.

CREATE VIEW REQ_5 AS
SELECT dp.product_code , dp.product , manufacturing_cost 
FROM dim_product dp
INNER JOIN fact_manufacturing_cost mc
ON dp.product_code = mc.product_code
WHERE manufacturing_cost = (
  SELECT MAX(manufacturing_cost)
  FROM fact_manufacturing_cost
) OR manufacturing_cost = (
   SELECT MIN(manufacturing_cost)
   FROM fact_manufacturing_cost
);

SELECT * FROM REQ_5;


-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM dim_customer;

CREATE VIEW REQ_6 AS 
SELECT cust.customer_code , cust.customer , avg(pre_invoice_discount_pct) AS average_discount_percentage
FROM dim_customer cust
INNER JOIN fact_pre_invoice_deductions pi
ON cust.customer_code = pi.customer_code 
WHERE fiscal_year = 2021 AND market = 'India'
GROUP BY customer_code
ORDER BY average_discount_percentage DESC
LIMIT 5; 

SELECT * FROM REQ_6;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
SELECT * FROM dim_customer;
SELECT * FROM fact_sales_monthly;
SELECT * FROM fact_gross_price;

CREATE VIEW XYZ AS 
SELECT sm.*, cust.customer, gp.gross_price
FROM fact_sales_monthly sm
JOIN  dim_customer cust
ON sm.customer_code = cust.customer_code
JOIN fact_gross_price gp
ON sm.product_code = gp.product_code
HAVING cust.customer = "Atliq Exclusive";

drop view xyz;
select monthname(DATE) as months, year(date) as years, date, SUM(sold_quantity*gross_price) as gross_sales_amount  from xyz
group by months,years;


-- 8. In which quarter of 2020, got the maximum total_sold_quantity?
      
CREATE VIEW req_8 AS
(
WITH cte_monthly_sales as (SELECT date, MONTH(date) as month, sold_quantity 
							FROM fact_sales_monthly
								WHERE fiscal_year=2020)
					 SELECT CASE
							WHEN MONTH(date) in (9,10,11) THEN 'Q1'
							WHEN MONTH(date) in (12,1,2) THEN 'Q2'
							WHEN MONTH(date) in (3,4,5) THEN 'Q3'
							WHEN MONTH(date) in (6,7,8) THEN 'Q4' END AS Quarter, SUM(sold_quantity) AS total_sold_quantity
								FROM cte_monthly_sales
									GROUP BY Quarter
									ORDER BY total_sold_quantity DESC
                                    );
drop view req_8;
SELECT * FROM req_8;	

-- 	9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
SELECT * FROM dim_customer;
SELECT * FROM fact_sales_monthly;
SELECT * FROM fact_gross_price;

CREATE VIEW req_9 AS
(
WITH cte AS
(
SELECT 
    c.channel,
    SUM(s.sold_quantity * g.gross_price) AS total_sales
FROM
    dim_customer c
        INNER JOIN
    fact_sales_monthly s ON c.customer_code = s.customer_code
        INNER JOIN
    fact_gross_price g ON s.product_code = g.product_code
WHERE
    s.fiscal_year = 2021 and g.fiscal_year = 2021
GROUP BY c.channel
ORDER BY total_sales DESC
)
SELECT
   channel,
    round(total_sales/1000000,2) AS gross_sales_in_mln,
     round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM cte
) ;

SELECT * FROM REQ_9;



-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
SELECT * FROM fact_sales_monthly;
SELECT * FROM dim_product;

create view req_10 as
( 
with cte1 as
(
select p.division, p.product_code, concat(p.product,"(",p.variant,")") AS product, sum(s.sold_quantity) as total_sold_quantity
from dim_product p
inner join fact_sales_monthly s on p.product_code = s.product_code
where s.fiscal_year = 2021
group by p.product_code
),
cte2 as 
(
select *, dense_rank() over (partition by division order by total_sold_quantity desc) as rank_order 
from cte1
)
select *
from cte2
where rank_order <= 3
);

SELECT * FROM REQ_10;

						