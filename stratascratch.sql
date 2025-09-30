-- EASY LEVEL QUESTIONS

/*
1. Salaries Differences

Task:
- Calculate the absolute difference between the highest salaries 
  in the Marketing and Engineering departments.

Tables:
- db_employee (salary, department_id, ...)
- db_dept (id, department)

Approach:
1. Join db_employee with db_dept using department_id = id.
2. Find MAX(salary) for Marketing.
3. Find MAX(salary) for Engineering.
4. Subtract the two values and wrap in ABS() to ensure a positive result.

Important Notes on Quoting in PostgreSQL:
- 'single quotes' → string literals (values). Example: 'Marketing'
- "double quotes" → identifiers (column names, table names). Example: "department"
  Using "Marketing" without single quotes will throw:
  ERROR: column "Marketing" does not exist
- Always use single quotes for text comparisons in WHERE clauses.
*/

SELECT ABS(
    (SELECT MAX(e.salary)
     FROM db_employee e
     JOIN db_dept d ON e.department_id = d.id
     WHERE d.department = 'Marketing')
  - (SELECT MAX(e.salary)
     FROM db_employee e
     JOIN db_dept d ON e.department_id = d.id
     WHERE d.department = 'Engineering')
) AS salary_difference;

/*
Note:
- The outer SELECT is required because every SQL query must begin with SELECT.
- ABS(...) is just a function call; the SELECT wrapper makes sure the result is returned.
*/



/*
2. Finding Updated Records

Task:
- Retrieve the most recent (highest) salary record for each employee.
- If multiple salary records exist for the same employee (id), keep only the top one.

Table:
- ms_employee_salary (id, first_name, last_name, department_id, salary, ...)

Approach:
1. Use a window function ROW_NUMBER() OVER (PARTITION BY id ORDER BY salary DESC, department_id DESC).
   - PARTITION BY id ensures numbering restarts for each employee.
   - ORDER BY salary DESC ranks highest salaries first; department_id DESC breaks ties.
2. Wrap this in a subquery that generates all rows with a new column "rn".
3. Filter the outer query with WHERE rn = 1 to keep only the top salary record per employee.
4. Alias the subquery as "s" (required in SQL). This allows us to treat the subquery as a table.
*/

SELECT id,
       first_name,
       last_name,
       department_id,
       salary
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY id
               ORDER BY salary DESC, department_id DESC
           ) AS rn
    FROM ms_employee_salary
) s
WHERE rn = 1
ORDER BY id ASC;

/*
Notes:
- The alias "s" is just a short name for the subquery result set.
  Without an alias, SQL will raise an error: "subquery in FROM must have an alias".
- "SELECT *," includes all original columns, and the comma allows us to add
  the new calculated column (rn).
- ROW_NUMBER() is a window function: it assigns a sequential rank within each partition
  without collapsing rows, unlike GROUP BY.
*/

/*
3. Workers With The Highest Salary

Task:
- Find the worker(s) with the maximum salary and display their job titles.

Tables:
- worker (worker_id, first_name, last_name, salary, ...)
- title (worker_ref_id, worker_title, ...)

Approach:
1. Use a subquery to get the maximum salary from the worker table.
2. Join worker with title on worker_id = worker_ref_id to attach job titles.
3. Filter to only those workers whose salary equals the maximum.
4. Return the job title(s) of the highest-paid employees.

Notes:
- INNER JOIN ensures only workers with a matching title appear.
- If a highest-paid worker has no title row, use LEFT JOIN to include them.
- If there are multiple workers with the same max salary, all their titles will be returned.
*/

-- Main solution: highest-paid worker(s) with their titles
SELECT t.worker_title
FROM worker w
INNER JOIN title t ON w.worker_id = t.worker_ref_id
WHERE w.salary = (SELECT MAX(a.salary) FROM worker a JOIN title b ON a.worker_id = b.worker_ref_id)

-- Below may not work
-- SELECT t.worker_title
-- FROM worker w
-- INNER JOIN title t ON w.worker_id = t.worker_ref_id
-- WHERE w.salary = (SELECT MAX(salary) FROM worker);
-- This is because the subquery computes the max salary across ALL workers,
-- but the INNER JOIN only keeps workers that HAVE a matching row in title.
-- If the top earner does NOT have a title row, the join drops that row,
-- so the query returns no results (empty set).


/*
4. Bikes Last Used

Task:
- For each bike in the DC bikeshare dataset, find the most recent trip (based on end_time).

Table:
- dc_bikeshare_q1_2012 (bike_number, start_time, end_time, ...)

Approach:
1. Use ROW_NUMBER() OVER (PARTITION BY bike_number ORDER BY end_time DESC).
   - PARTITION BY bike_number ensures numbering restarts per bike.
   - ORDER BY end_time DESC ranks the most recent trip first.
2. In a subquery, assign row numbers for each bike’s rides.
3. In the outer query, filter WHERE rn = 1 to keep only the most recent trip per bike.
4. Order the result set by end_time DESC to list the latest trips first.
*/

SELECT bike_number,
       end_time
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY bike_number
               ORDER BY end_time DESC
           ) AS rn
    FROM dc_bikeshare_q1_2012
) AS s
WHERE rn = 1
ORDER BY end_time DESC;


/*
5. Average Salaries

Task:
- For each employee, display their department, first name, salary, 
  and the average salary of their department.

Table:
- employee (department, first_name, salary, ...)

Approach:
1. Use AVG(salary) as a window function with OVER (PARTITION BY department).
   - PARTITION BY department computes the average salary for each department.
   - Unlike GROUP BY, window functions do not collapse rows.
   - Each employee row is preserved, with the department average shown alongside.

Correct Query:
*/

SELECT department,
       first_name,
       salary,
       AVG(salary) OVER (PARTITION BY department) AS average_salary
FROM employee;

/*
Example Output:
| department | first_name | salary | average_salary |
|------------|------------|--------|----------------|
| HR         | Alice      | 50000  | 55000          |
| HR         | Bob        | 60000  | 55000          |
| IT         | Carol      | 80000  | 90000          |
| IT         | Dave       |100000  | 90000          |

-----------------------------------------------------

Why the earlier subquery version fails:

Attempt (incorrect):
SELECT department,
       first_name,
       salary,
       (SELECT AVG(salary) OVER (PARTITION BY department) 
        FROM employee)
FROM employee;

Problem:
- A subquery used in the SELECT list is a *scalar subquery*.
- Scalar subqueries must return exactly ONE value (one row, one column).
- But a window function (AVG OVER ...) produces MANY values (one per row).
- This mismatch causes PostgreSQL to throw an error:
  "more than one row returned by a subquery used as an expression."

Correct Fix:
- Use the window function directly in the SELECT list, 
  not inside a scalar subquery.
- Or, if filtering is needed, wrap the whole query in a subquery/CTE 
  and then filter on the window function result.
*/

/*
6. Customer Details

Task:
- Retrieve each customer's details (first name, last name, city)
  along with their order details.
- Include all customers, even if they have not made any orders.
- Sort results by customer first name (ascending) and order details (ascending).

Tables:
- customers (id, first_name, last_name, city, ...)
- orders (order_id, cust_id, order_details, ...)

Approach:
1. Use a LEFT JOIN from customers to orders.
   - Ensures all customers are included, even those without orders (NULL order_details).
2. Select the required fields: first_name, last_name, city, order_details.
3. Apply ORDER BY on first_name and order_details, both ascending.
*/

SELECT c.first_name,
       c.last_name,
       c.city,
       o.order_details
FROM customers c
LEFT JOIN orders o
       ON c.id = o.cust_id
ORDER BY c.first_name ASC,
         o.order_details ASC;


-- 1. Write a query that returns the number of unique users per client per month
SELECT client_id, EXTRACT(MONTH FROM time_id) AS month, COUNT(DISTINCT user_id) AS users_num
    FROM fact_events
    GROUP BY EXTRACT(MONTH FROM time_id), client_id;

-- 2. Write a query that will calculate the number of shipments per month. The unique key for one shipment is a combination of shipment_id and sub_id. 
-- Output the year_month in format YYYY-MM and the number of shipments in that month.
SELECT to_char(shipment_date, 'YYYY-MM'), COUNT(DISTINCT(shipment_id, sub_id))
    FROM amazon_shipment
    GROUP BY 1;


-- 3. You have been asked to find the 5 most lucrative products in terms of total revenue for the first half of 2022 (from January to June inclusive).
-- Output their IDs and the total revenue.
select product_id, sum(units_sold*cost_in_dollars) as total_revenue
    from online_orders
    WHERE date >= '2022-01-01'
        AND date<= '2022-06-30'
    GROUP BY product_id
    ORDER BY 2 DESC
    LIMIT 5;

-- 4. Find the average number of bathrooms and bedrooms for each city’s property types. Output the result along with the city name and the property type.
select avg(bathrooms) bathrooms, avg(bedrooms) bedrooms, property_type, city
    from airbnb_search_details
    GROUP BY city, property_type;

-- 5. Count the number of user events performed by MacBookPro users.
-- Output the result along with the event name.
-- Sort the result based on the event count in the descending order.
select COUNT(event_name) event_count, event_name
    FROM playbook_events
    WHERE device = 'macbook pro'
    GROUP BY (event_name)
    ORDER BY 1 DESC;

-- 6. Find the most profitable company from the financial sector. Output the result along with the continent.
select continent, company
    from forbes_global_2010_2014
    WHERE sector = 'Financials'
    ORDER BY profits DESC
    LIMIT 1;

-- 7. Find the activity date and the pe_description of facilities with the name 'STREET CHURROS' and with a score of less than 95 points.
select activity_date, pe_description
    from los_angeles_restaurant_health_inspections
    where facility_name = 'STREET CHURROS'
        AND score <=95;

-- 8. Find the number of employees working in the Admin department that joined in April or later.
select COUNT(worker_id) 
    from worker
    WHERE EXTRACT(MONTH from joining_date) >= 04
        AND department = 'Admin'

-- 9. Find the number of workers by department who joined in or after April.
-- Output the department name along with the corresponding number of workers.
-- Sort records based on the number of workers in descending order.
select department, COUNT(worker_id)
    from worker
    WHERE EXTRACT(MONTH FROM joining_date) >= 4
    GROUP BY department;

-- 10. Find the details of each customer regardless of whether the customer made an order. Output the customer's first name, last name, and the city along with the order details.
-- Sort records based on the customer's first name and the order details in ascending order.
select customers.first_name, customers.last_name, customers.city, orders.order_details
    FROM customers LEFT JOIN orders ON customers.id = orders.cust_id
    ORDER BY customers.first_name, orders.order_details;

-- 11. Find order details made by Jill and Eva.
-- Consider the Jill and Eva as first names of customers.
-- Output the order date, details and cost along with the first name.
-- Order records based on the customer id in ascending order.
SELECT customers.first_name, orders.order_date, order_details, total_order_cost
    FROM customers INNER JOIN orders ON customers.id = orders.cust_id
    WHERE customers.first_name = 'Jill' OR customers.first_name = 'Eva'
    ORDER BY customers.id;

-- 12. Compare each employee's salary with the average salary of the corresponding department. 
-- Output the department, first name, and salary of employees along with the average salary of that department.
SELECT department, first_name, salary,
    AVG(salary) OVER (PARTITION BY department) as avg_salary
    FROM employee;

-- 13. Find libraries who haven't provided the email address in circulation year 2016 but their notice preference definition is set to email. Output the library code.
select DISTINCT(home_library_code)
    from library_usage
        WHERE circulation_active_year = 2016
            AND notice_preference_definition = 'email'
            AND provided_email_address = False;

-- 14. Find the base pay for Police Captains. Output the employee name along with the corresponding base pay.
SELECT employeename, basepay
    FROM sf_public_salaries
    WHERE jobtitle like '%CAPTAIN%POLICE%';

-- 15. Find how many times each artist appeared on the Spotify ranking list Output the artist name along with the corresponding number of occurrences. Order records by the number of occurrences in descending order.
select artist, count(trackname) as number_of_times
    from spotify_worldwide_daily_song_ranking
    GROUP BY artist
    ORDER BY 2 DESC;

-- 16. Find all Lyft drivers who earn either equal to or less than 30k USD or equal to or more than 70k USD. Output all details related to retrieved records.
select *
    from lyft_drivers
    WHERE yearly_salary <= 30000
    OR yearly_salary >= 70000;

-- 17. Meta/Facebook has developed a new programing language called Hack.To measure the popularity of Hack they ran a survey with their employees. The survey included data on previous programing familiarity as well as the number of years of experience, age, gender and most importantly satisfaction with Hack. Due to an error location data was not collected, but your supervisor demands a report showing average popularity of Hack by office location. Luckily the user IDs of employees completing the surveys were stored. Based on the above, find the average popularity of the Hack per office location. Output the location along with the average popularity.
select location, AVG(popularity)
    from facebook_employees INNER JOIN facebook_hack_survey
    ON facebook_employees.id = facebook_hack_survey.employee_id
    GROUP BY location;


-- 18. Find all posts which were reacted to with a heart. For such posts output all columns from facebook_posts table.
select DISTINCT(facebook_posts.*)
    from facebook_reactions INNER JOIN facebook_posts ON facebook_reactions.post_id = facebook_posts.post_id
    WHERE facebook_reactions.reaction = 'heart';

-- 19. Count the number of movies that Abigail Breslin was nominated for an oscar.
select COUNT(movie)
    from oscar_nominees
    WHERE nominee = 'Abigail Breslin';

-- 20. Find the number of rows for each review score earned by 'Hotel Arena'. Output the hotel name (which should be 'Hotel Arena'), 
-- review score along with the corresponding number of rows with that score for the specified hotel.
select hotel_name, reviewer_score, COUNT(reviewer_score)
    from hotel_reviews
    WHERE hotel_name = 'Hotel Arena'
    GROUP BY hotel_name, reviewer_score;

-- 21. Find the number of rows for each review score earned by 'Hotel Arena'. 
-- Output the hotel name (which should be 'Hotel Arena'), review score along with the corresponding number of rows with that score for the specified hotel.
select hotel_name, reviewer_score, COUNT(reviewer_score)
    from hotel_reviews
    WHERE hotel_name = 'Hotel Arena'
    GROUP BY hotel_name, reviewer_score;

-- 22. Find the last time each bike was in use. Output both the bike number and the date-timestamp of the bike's last use (i.e., the date-time the bike was returned). 
-- Order the results by bikes that were most recently used.
select bike_number, MAX(end_time) as last_used
    from dc_bikeshare_q1_2012
    GROUP BY bike_number
    ORDER BY last_used DESC;

-- 23. We have a table with employees and their salaries, however, some of the records are old and contain outdated salary information. 
-- Find the current salary of each employee assuming that salaries increase each year. Output their id, first name, last name, department ID, and current salary. 
-- Order your list by employee ID in ascending order.
select id, first_name, last_name, department_id, MAX(salary)
    from ms_employee_salary
    GROUP BY id, first_name, last_name, department_id
    ORDER BY id;

-- 24. Write a query that calculates the difference between the highest salaries found in the marketing and engineering departments. Output just the absolute difference in salaries.
SELECT ABS((SELECT MAX(salary)
    FROM db_employee INNER JOIN db_dept ON db_employee.department_id = db_dept.id
    WHERE department = 'marketing')-
    (SELECT MAX(salary)
    FROM db_employee INNER JOIN db_dept ON db_employee.department_id = db_dept.id
    WHERE department = 'engineering'));
