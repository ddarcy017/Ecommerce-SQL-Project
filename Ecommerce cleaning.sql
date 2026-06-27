CREATE DATABASE ecommerce_project;

USE ecommerce_project;
SHOW TABLES;

SELECT * 
FROM messy_ecommerce_sales_data;

-- CREATE STAGING TABLE --

CREATE TABLE `ecommerce_staging` (
  `ID` int DEFAULT NULL,
  `Customer_Name` text,
  `Order_ID` text,
  `Order_Date` text,
  `Product` text,
  `Category` text,
  `Quantity` int DEFAULT NULL,
  `Price` text,
  `Payment_Method` text,
  `Status` text,
  `Total` text,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Duplication checking --

SELECT *
FROM ecommerce_staging;

INSERT INTO ecommerce_staging
SELECT *,
	ROW_NUMBER() OVER(
	PARTITION BY ID, Customer_Name, Order_ID, Order_date, Product, Category,
				 Quantity, Price, Payment_Method, `Status`, Total ) AS row_num
FROM messy_ecommerce_sales_data;

SELECT *
FROM ecommerce_staging
WHERE row_num > 1;

DELETE 
FROM ecommerce_staging
WHERE row_num > 1;

SELECT *
FROM ecommerce_staging
WHERE ID = 146;

ALTER TABLE ecommerce_staging
DROP COLUMN row_num;

-- Standardize --
-- Order_Date 

SELECT Order_Date,
str_to_date(Order_Date, '%m/%d/%Y')
FROM ecommerce_staging;

SELECT Order_Date
FROM ecommerce_staging
WHERE str_to_date(Order_Date, '%m/%d/%Y') IS NULL;

UPDATE ecommerce_staging
SET Order_Date = '1/5/2023'
WHERE Order_Date = 'Jan 5 2023';

SELECT *
FROM ecommerce_staging
WHERE Order_Date = '1/5/2023';

UPDATE ecommerce_staging
SET Order_Date = STR_TO_DATE(Order_Date, '%m/%d/%Y');

SELECT *
FROM ecommerce_staging;

ALTER TABLE ecommerce_staging
MODIFY COLUMN Order_Date DATE;

-- Product
WITH product_clean AS(
	SELECT Product,
	CONCAT(
		UPPER(LEFT(TRIM(Product), 1)),
		LOWER(SUBSTRING(TRIM(Product),2))
	) AS Product_cleaned
FROM ecommerce_staging
)
SELECT DISTINCT Product, Product_cleaned
FROM product_clean
ORDER BY 1;

UPDATE ecommerce_staging
SET Product = CONCAT(
		UPPER(LEFT(TRIM(Product), 1)),
		LOWER(SUBSTRING(TRIM(Product),2))
	);
    
-- Category
WITH category_clean AS(
	SELECT Category,
	CONCAT(
		UPPER(LEFT(TRIM(Category), 1)),
		LOWER(SUBSTRING(TRIM(Category),2))
	) AS Category_cleaned
FROM ecommerce_staging
)
SELECT DISTINCT Category, Category_cleaned
FROM category_clean
ORDER BY 1;
    
UPDATE ecommerce_staging
SET Category = CONCAT(
		UPPER(LEFT(TRIM(Category), 1)),
		LOWER(SUBSTRING(TRIM(Category),2))
	);

UPDATE ecommerce_staging
SET Category = 'Electronics'
WHERE Category = 'Electronic';

SELECT DISTINCT Category 
FROM ecommerce_staging
ORDER BY 1;

-- NULL, '' and unusual variable

UPDATE ecommerce_staging
SET Category = NULL 
WHERE Category = 'Nan' OR 
	  Category = '';

SELECT DISTINCT Quantity
FROM ecommerce_staging;

SELECT * 
FROM ecommerce_staging
WHERE Quantity < 0 ;

SELECT * 
FROM ecommerce_staging
WHERE Product = 'T-shirt' AND Total = -2957.65;

SELECT DISTINCT Price
FROM ecommerce_staging;

ALTER TABLE ecommerce_staging
MODIFY COLUMN Price DECIMAL(10,2);

WITH price_clean AS (
SELECT Price,
       CAST(Price AS DECIMAL(10,2)) AS Price_num
FROM ecommerce_staging
)
SELECT *
FROM Price_clean;

ALTER TABLE ecommerce_staging
ADD COLUMN Price_num DECIMAL(10,2);

UPDATE ecommerce_staging
SET Price_num =
    CASE
        WHEN Price REGEXP '^[0-9]+(\\.[0-9]+)?$'
        THEN CAST(Price AS DECIMAL(10,2))
        ELSE NULL
    END;

SELECT DISTINCT Price, Price_num
FROM ecommerce_staging;

SELECT * 
FROM ecommerce_staging
WHERE Price_num IS NULL;

UPDATE ecommerce_staging
SET Price = 400
WHERE Price = 'four hundred';

UPDATE ecommerce_staging 
SET Price = 300
WHERE Price LIKE '300%';

UPDATE ecommerce_staging 
SET Price = NULL
WHERE Price = '' OR Price = 'abd';

UPDATE ecommerce_staging 
SET Price = Price_num;

ALTER TABLE ecommerce_staging
MODIFY COLUMN Price DECIMAL(10,2),
DROP COLUMN Price_num;

SELECT *
FROM ecommerce_staging;

SELECT DISTINCT `Status`
FROM ecommerce_staging;

SELECT DISTINCT Total
FROM ecommerce_staging;

ALTER TABLE ecommerce_staging
ADD COLUMN Total_num DECIMAL(10,2);

UPDATE ecommerce_staging
SET Total_num =
    CASE
        WHEN Total REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
        THEN CAST(Total AS DECIMAL(10,2))
        ELSE NULL
    END;

SELECT DISTINCT Total, Total_num
FROM ecommerce_staging;

SELECT * 
FROM ecommerce_staging
WHERE Total_num IS NULL;

UPDATE ecommerce_staging 
SET Total = Total_num;

SELECT *
FROM ecommerce_staging;

ALTER TABLE ecommerce_staging
MODIFY COLUMN Total DECIMAL(10,2),
DROP COLUMN Total_num;

-- Fill blanks Category --

SELECT *
FROM ecommerce_staging
WHERE Category IS NULL;

UPDATE ecommerce_staging
SET Category = 'Books'
WHERE Category IS NULL AND Product = 'Biography';

UPDATE ecommerce_staging
SET Category = 'Clothing' 
WHERE Category IS NULL AND Product IN ('Shoes', 'Jeans'); 

UPDATE ecommerce_staging
SET Category = 'Electronics' 
WHERE Category IS NULL AND Product IN ('Laptop', 'Smartphone', 'Headphones'); 

UPDATE ecommerce_staging
SET Category = 'Home' 
WHERE Category IS NULL AND Product = 'Vacuum'; 

-- Raise flag --alter

ALTER TABLE ecommerce_staging
ADD COLUMN Flag TEXT;

UPDATE ecommerce_staging
SET Flag =
	CASE 
		WHEN (Quantity < 0 OR Price < 0 OR Total < 0 )
			AND `Status` <> 'Cancelled'
			THEN 'Negative value'
        WHEN (Quantity IS NULL OR Price IS NULL OR Total IS NULL)
			AND `Status` <> 'Cancelled'
			THEN 'Missing value'
        ELSE ''
	END;

-- Final Review --
SELECT *
FROM ecommerce_staging;

-- EDA -- 

SELECT Product, 
	COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY Product
ORDER BY Number_of_Orders DESC;

-- Shoes is the most ordered product of 9, Football and Jacket are the least (2)

SELECT Category, 
	COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY Category
ORDER BY Number_of_Orders DESC;

-- Books is the most (22) while Electronics (21)

SELECT Product,
       SUM(Quantity) 
FROM ecommerce_staging
GROUP BY Product
ORDER BY 2 DESC;

-- Shoes is the most unit sold (33) while Comics, Science and Lamp all around 24. 

SELECT Product,
       SUM(Total) AS Revenue
FROM ecommerce_staging
GROUP BY Product
ORDER BY Revenue DESC;

-- Shoes (16.9k), Comics and Lamps(both ~14k) are most profitable products
-- T-shirts is the less profitable

-- Order_ID 117 need serious review 

SELECT Category,
       SUM(Total) AS Revenue
FROM ecommerce_staging
GROUP BY Category
ORDER BY Revenue DESC;

-- Books and Home are most profitable Category

SELECT * 
FROM ecommerce_staging
WHERE Product = 'Blender';

SELECT MONTH(Order_Date), 
COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY MONTH(Order_Date)
ORDER BY Number_of_Orders DESC;

-- Jul, Oct and Feb are highest order with 12 orders each month

SELECT *
FROM ecommerce_staging
WHERE `Status` = 'Returned'; 

SELECT `Status`, Product, 
	COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY Product, `Status`
ORDER BY `Status` DESC ;

-- Most Returned Lamp (3) and Fiction (4), Most Cancelled Blender, Smartphone, Comics (2)
 
SELECT `Status`,
       Category,
       COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY `Status`, Category
ORDER BY `Status`, Number_of_Orders DESC;

-- Books are the most cat returned (10) while Electronics is the most cat cancelled(4)

SELECT Payment_Method,
       COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY Payment_Method
ORDER BY Number_of_Orders DESC;

-- Most payment method is Cash on Delivery (32), other 3 are all around 21

SELECT `Status`,
       COUNT(*) AS Number_of_Orders
FROM ecommerce_staging
GROUP BY `Status`
ORDER BY Number_of_Orders DESC;
-- 25 Order is returend, while 24 processing and 15 cancelled

