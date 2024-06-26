# 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT market 
FROM gdb023.dim_customer
WHERE customer="Atliq Exclusive" AND region="APAC"
GROUP BY market

# =================================================

# 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,

# unique_products_2020
# unique_products_2021
# percentage_chg

WITH ProductCounts AS (
    SELECT
        f.fiscal_year,
        COUNT(DISTINCT d.product_code) AS unique_products
    FROM 
        gdb023.dim_product d
    JOIN 
        fact_gross_price f ON d.product_code = f.product_code
    WHERE 
        f.fiscal_year IN (2020, 2021)
    GROUP BY 
        f.fiscal_year
)
SELECT 
    pc2020.unique_products AS unique_products_2020,
    pc2021.unique_products AS unique_products_2021,
    ROUND(((pc2021.unique_products - pc2020.unique_products) / pc2020.unique_products) * 100, 2) AS percentage_change
FROM 
    ProductCounts pc2020
JOIN 
    ProductCounts pc2021 ON pc2020.fiscal_year = 2020 AND pc2021.fiscal_year = 2021;
    
# =================================================

# 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
# The final output contains 2 fields, 
# segment 
# product_count

SELECT 
  segment, 
  COUNT(product_code) as product_count 
FROM gdb023.dim_product
GROUP BY segment
ORDER BY product_count DESC

# =================================================

# 4. Follow-up: Which segment had the most increase in unique products in
# 2021 vs 2020? The final output contains these fields,

# segment
# product_count_2020
# product_count_2021
# difference

WITH segment AS (
    SELECT 
        d.segment, 
        COUNT(DISTINCT CASE WHEN f.fiscal_year = 2020 THEN d.product_code END) AS product_count_2020,
        COUNT(DISTINCT CASE WHEN f.fiscal_year = 2021 THEN d.product_code END) AS product_count_2021
    FROM 
        dim_product d
    JOIN 
        fact_sales_monthly f ON d.product_code = f.product_code
    WHERE 
        f.fiscal_year IN (2020, 2021)
    GROUP BY 
        d.segment
)
SELECT
    s.segment,
    s.product_count_2020,
    s.product_count_2021,
    (s.product_count_2021 - s.product_count_2020) AS difference
FROM 
    segment s
ORDER BY 
    difference DESC

# =================================================

# 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,

# product_code
# product
# manufacturing_cost

(SELECT 
  'Highest Manufacturing Cost' AS description, 
  product_code, 
  product,
  manufacturing_cost 
FROM gdb023.dim_product
JOIN fact_manufacturing_cost USING (product_code)
ORDER BY manufacturing_cost DESC
LIMIT 1)

UNION ALL

(SELECT 'Lowest Manufacturing Cost' AS description, product_code, product, manufacturing_cost 
FROM gdb023.dim_product
JOIN fact_manufacturing_cost USING (product_code)
ORDER BY manufacturing_cost ASC
LIMIT 1)

# =================================================

# 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the
# Indian market. The final output contains these fields,

# customer_code
# customer
# average_discount_percentage

SELECT 
  customer_code,
  customer,
  pre_invoice_discount_pct as average_discount_percentage 
FROM gdb023.dim_customer
JOIN fact_pre_invoice_deductions using (customer_code)
WHERE market="India" AND fiscal_year=2021
ORDER BY pre_invoice_discount_pct DESC
LIMIT 5

# =================================================

# 8. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and
# high-performing months and take strategic decisions. The final report contains these columns:

# Month
# Year
# Gross sales Amount

SELECT
    monthname(date) as Months,
    year(date) as Year,
    concat(round(sum((gross.gross_price*sales.sold_quantity))/1000000,2),"M") as Gross_sales_amount
FROM fact_sales_monthly sales
JOIN fact_gross_price gross on sales.product_code=gross.product_code
JOIN dim_customer c ON sales.customer_code=c.customer_code
WHERE customer="Atliq exclusive"
GROUP BY year, months
ORDER BY year, month(date)

# =================================================

# 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,

# Quarter
# total_sold_quantity

WITH TEMP_TABLE AS ( 
SELECT
  date, 
  month(date_add(date, interval 4 month)) as period,
  fiscal_year,
  sold_quantity
FROM fact_sales_monthly 
)
SELECT
	CASE 
		WHEN period/3 <= 1 THEN "Q1"
		WHEN period/3 <= 2 AND period/3 > 1 THEN "Q2"
		WHEN period/3 <=3 AND period/3 > 2 THEN "Q3"
		WHEN period/3 <=4 AND period/3 > 3 THEN "Q4" 
    END AS Quarter,
    CONCAT(round(sum(sold_quantity/1000000),2),"M") as total_sold_quantity_millions 
FROM TEMP_TABLE
WHERE fiscal_year=2020
GROUP BY quarter
ORDER BY total_sold_quantity_millions DESC

# =================================================

# 9. Which channel helped to bring more gross sales in the fiscal year 2021
# and the percentage of contribution? The final output contains these fields,

# channel
# gross_sales_mln
# percentage

WITH temp_table as (
SELECT 
  c.channel, 
  sum(s.sold_quantity*g.gross_price) as total_sales
FROM gdb023.fact_sales_monthly s
JOIN dim_customer c using (customer_code)
JOIN fact_gross_price g using (product_code)
WHERE s.fiscal_year=2021
GROUP BY c.channel
ORDER BY total_sales desc
)
SELECT
	channel,
  ROUND(total_sales/1000000,2) as gross_sales_in_millions,
  ROUND(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM TEMP_TABLE;

# =================================================

# 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields,

# division
# product_code
# product
# total_sold_quantity
# rank_order

WITH temp_table AS (
SELECT 
	  division,
    s.product_code,
    concat(p.product," (",p.variant,")") as product,
    sum(sold_quantity) as total_sold_quantity,
    RANK() OVER (partition by division order by sum(sold_quantity) desc) as rank_order
FROM
 fact_sales_monthly s
 JOIN dim_product p
 ON s.product_code = p.product_code
 WHERE fiscal_year = 2021
 GROUP BY product_code
)
SELECT * FROM temp_table
WHERE rank_order IN (1,2,3);

