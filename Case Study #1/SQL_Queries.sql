-- 1. What is the total amount each customer spent at the restaurant?
SELECT dds.customer_id, SUM(ddm.price)
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddm ON (dds.product_id = ddm.product_id)
GROUP BY dds.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT dds.customer_id, COUNT(DISTINCT(dds.order_date))
FROM dannys_diner.sales dds
GROUP BY dds.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT DISTINCT ss.customer_id, ss.order_date, ss.product_name
FROM (
   SELECT dds.customer_id, dds.order_date, ddm.product_name
        , row_number() OVER (PARTITION BY dds.customer_id ORDER BY dds.order_date, dds.product_id ASC) AS row_number
   FROM dannys_diner.sales dds
   JOIN dannys_diner.menu ddm ON (dds.product_id = ddm.product_id)
   ) ss
WHERE ss.row_number = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT ddm.product_name, COUNT(*) as purchased
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddm ON (dds.product_id = ddm.product_id)
GROUP BY ddm.product_name
ORDER BY purchased DESC
LIMIT(1);

-- 5. Which item was the most popular for each customer?
SELECT ss.customer_id, ss.product_name, ss.purchased
FROM (
    SELECT dds.customer_id, ddm.product_name, count(*) as purchased
        , rank() OVER (PARTITION BY dds.customer_id ORDER BY count(*) DESC) AS rank
    FROM dannys_diner.sales dds
    JOIN dannys_diner.menu ddm ON (dds.product_id = ddm.product_id)
	GROUP BY dds.customer_id, ddm.product_name
   ) ss
WHERE ss.rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
-- Assumption: only for members of the loyalty program
SELECT ss.customer_id, coalesce('member since: ' || ss.join_date, 'Not a member yet') as "membership", ss.order_date, ss.product_name
FROM (
    SELECT dds.customer_id, dds.order_date, ddmu.product_name, ddme.join_date
        , row_number() OVER (PARTITION BY dds.customer_id ORDER BY dds.order_date ASC) AS row_number
    FROM dannys_diner.sales dds
    JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
	JOIN dannys_diner.members ddme ON (dds.customer_id = ddme.customer_id)
    WHERE dds.order_date >= ddme.join_date
   ) ss
WHERE ss.row_number = 1;

-- 7. Which item was purchased just before the customer became a member?
-- Assumption: only for members of the loyalty program
SELECT ss.customer_id,  'member since: ' || ss.join_date as "membership", ss.order_date, ss.product_name
FROM (
    SELECT dds.customer_id, dds.order_date, ddmu.product_name, ddme.join_date
        , row_number() OVER (PARTITION BY dds.customer_id ORDER BY dds.order_date DESC, dds.product_id DESC) AS row_number
    FROM dannys_diner.sales dds
    JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
	JOIN dannys_diner.members ddme ON (dds.customer_id = ddme.customer_id)
    WHERE dds.order_date < ddme.join_date
   ) ss 
WHERE ss.row_number = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
-- Assumption: only for members of the loyalty program
SELECT dds.customer_id,'member since: ' || ddme.join_date as "membership", count(*) as "items", sum(ddmu.price) as "amount spent"
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
WHERE dds.order_date < ddme.join_date
GROUP BY dds.customer_id, ddme.join_date
ORDER BY dds.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- Assumption: only for members of the loyalty program
SELECT dds.customer_id, 
	SUM(CASE 
		WHEN ddmu.product_name = 'sushi'
		THEN ddmu.price * 10 * 2
		ELSE ddmu.price * 10
		END) as points
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
GROUP BY dds.customer_id
ORDER BY dds.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT dds.customer_id, 
	SUM(CASE 
		WHEN ddmu.product_name = 'sushi' OR (dds.order_date >= ddme.join_date AND dds.order_date < ddme.join_date + INTERVAL '7 day')
		THEN ddmu.price * 10 * 2
		ELSE ddmu.price * 10
		END) as points,
	'2021-01-31' as "Evaluation date"
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
WHERE dds.order_date < '2021-02-01'
GROUP BY dds.customer_id
ORDER BY dds.customer_id;

-- Bonus: Join All The Things
SELECT dds.customer_id,	dds.order_date,	ddmu.product_name, ddmu.price, 
	CASE
	WHEN dds.order_date < ddme.join_date OR ddme.join_date is NULL
	THEN 'N'
	ELSE 'Y'
	END as member
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
LEFT JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
ORDER BY dds.customer_id, dds.order_date;

-- Bonus: Rank All The Things
SELECT dds.customer_id,	dds.order_date,	ddmu.product_name, ddmu.price, 'N' as member, NULL as ranking
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
LEFT JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
WHERE dds.order_date < ddme.join_date OR ddme.join_date is NULL
UNION ALL
SELECT dds.customer_id,	dds.order_date,	ddmu.product_name, ddmu.price, 'Y' as member, 
dense_rank() OVER (PARTITION BY dds.customer_id ORDER BY dds.order_date ASC) as ranking
FROM dannys_diner.sales dds
JOIN dannys_diner.menu ddmu ON (dds.product_id = ddmu.product_id)
LEFT JOIN dannys_diner.members ddme ON (ddme.customer_id = dds.customer_id)
WHERE dds.order_date >= ddme.join_date
ORDER BY customer_id, order_date, product_name;
