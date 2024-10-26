USE db;

SELECT *
FROM Occ_Tickets_Data;



/* 
I Have Imported a table that Consists of a 5605 rows of data that tickets worked by all employees in organazation there is No Duplicate data
in the table
The table coonsists following columns
	- Associate Column which consists names of employees
	- Customer column consists name of the customer 
	- Ticket_type column consists ticket types in this example 'SR' , 'IN'and'HD'
		- 'SR' - refer Service Requests
		- 'IN' - refer Incidents
		- 'HD' - Helpdesk Tickets
	- Ticket_No column consist of ticket number
	- Title column gives the title of the ticket
	- The Hours Worked column consists of the time each employee worked on the ticket
	- Created On column is the time when the ticket is genrated
	- Updated On column is the time which is last updated on the ticket
*/

-- Duplicating the table if any issue came our original table did not effect
SELECT *
INTO
	Emp_tickets	--New table which we copying the data from our original table
FROM
	Occ_Tickets_Data;

--Looking what type of data types in the tabele
SELECT	Column_Name,
		Data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Emp_tickets';

/* Here we converting the [Created On] column into YYYY-MM-DD formatt because i want only date to be appear in the columun
for more understanding do this i am going to add the new column and updating into it*/

ALTER TABLE
	Emp_tickets
ADD
	Created_On NVARCHAR(10);

-- Converting a column into YYYY-MM-DD So iam using CONVERT Function 
UPDATE 
	Emp_tickets
SET 
	Created_On = CONVERT(DATE, [Created On]);	--Hint: Use[] Square brackets if your column name contains spaces

-- To drop the oringinal [Created On] column

ALTER TABLE
	Emp_tickets
DROP COLUMN	
	[Created On];

-- here i want [hours worked] column in HH:MM format so that adding new column to see the Hours Worked in HH:MM Format

AlTER TABLE Emp_tickets
ADD Workingtime VARCHAR(5);

/*converting the [hours worked] into HH:MM format and update in the new Workingtime column here 108 code is for HH:MM:SS Format 
and and we using LEFT function it take Left side 5 Characters*/

UPDATE Emp_tickets
SET Workingtime = LEFT(CONVERT(VARCHAR,[Hours Worked],108),5);

--Removing the [hours worked] column
AlTER TABLE Emp_tickets
DROP COLUMN [Hours Worked];

--Final Table after some modifications
SELECT * FROM Emp_tickets;

-- (1)Determine the number of tickets worked by each employee

SELECT
	Emp_name,
	COUNT(*) AS Ticket_Count
FROM
	Emp_tickets
GROUP BY
	Emp_name
ORDER BY 
	Ticket_Count DESC

--(2)Determine the number of tickets worked by each employee per customer
SELECT
	Emp_name,
	customer,
	COUNT(*) AS Ticket_Count
FROM
	Emp_tickets
WHERE Customer = 'Libra Solutions Group'		--(If you want tickets count for specific customer )
GROUP BY
	Emp_name,customer							
ORDER BY 3 DESC							--(It means order the third column in the table)

--(3)Determining the no of SR or HD Closed by the each employee which created before 2023
SELECT 
	Emp_name,Count(*) AS Ticket_Count
FROM
	Emp_tickets
WHERE
	(ticket_Type IN ('SR','HD')
	AND YEAR([Created_On]) < 2023)
GROUP BY
	Emp_name
ORDER BY
	Ticket_Count DESC;

--(4) If the SR ticket which are genarated before 2023 make it as old_tickets
SELECT *,
	CASE WHEN Year([created_on]) < 2023 THEN 'old_tickets' ELSE 'new_tickets' END AS [Old/New]
FROM
	Emp_tickets
WHERE 
	ticket_type = 'SR';

--(5)a)Determine the total time worked per each customer per emp_name
WITH Total_WorkingHours AS
(
SELECT
	Emp_name,
	Customer,
	COUNT(Ticket_No) AS Ticket_Count,
	SUM((CAST(LEFT(WorkingTime,2) AS INT) * 60) + CAST(RIGHT(WorkingTime,2) AS INT)) AS Total_Minutes
FROM
	Emp_tickets
GROUP BY 
	Emp_name,
	Customer
)SELECT
	Emp_name,
	Customer,
	Ticket_Count,
	FORMAT(DATEADD(MINUTE, Total_Minutes, 0), 'HH:mm') AS Total_Work_Time		-- Here DATEADD Function adds the our time into sql default value which is 1900-01-01 00:00:00 when you add 0 and here we use MINUTE because we are working on MINUTEs
FROM
	Total_WorkingHours
ORDER BY 2,1 ;

--Making it as View so that we can re use it
CREATE VIEW Total_Working_Time AS
SELECT
	Emp_name,
	Customer,
	COUNT(Ticket_No) AS Ticket_Count,
	SUM((CAST(LEFT(WorkingTime,2) AS INT) * 60) + CAST(RIGHT(WorkingTime,2) AS INT)) AS Total_Minutes
FROM
	Emp_tickets
GROUP BY 
	Emp_name,
	Customer;

SELECT * FROM Total_Working_Time

--(5)b) Determining the total time worked by each employee for required customer
SELECT *
FROM
	Total_Working_Time
WHERE 
	Customer = 'Spyglass Corporate Services Group'		--Select the required customer


--(6) Which person max hours worked per each customer
WITH Total_minutes AS
(
    SELECT  
        Customer,
        MAX(Total_Minutes) AS Maximum_minutes
    FROM
        Total_Working_Time		--Using User Defined View
    GROUP BY
        Customer
)
SELECT
    t.Customer,
    t.Emp_name,
    t.Ticket_Count,
    FORMAT(DATEADD(MINUTE, t.Total_Minutes, 0), 'HH:mm') AS Working_Hours
FROM
    Total_Working_Time t 
INNER JOIN 
    Total_minutes tm
ON
    t.Customer = tm.Customer 
AND 
    t.Total_Minutes = tm.Maximum_minutes;



--(7)Determin the most number of tickets worked by employee per each customer

WITH TicketCounts AS(
SELECT
	Customer,Emp_name,COUNT(Ticket_No) AS Ticket_Count
FROM
	Emp_tickets
GROUP BY 
	Customer,Emp_name
),
Maxtickets AS
(
SELECT
	Customer,MAX(Ticket_Count) AS Tickets_Count
FROM
	TicketCounts
GROUP BY
	Customer
)
SELECT
	TC.Customer,TC.Emp_name,TC.Ticket_Count
FROM
	TicketCounts TC INNER JOIN Maxtickets MT
ON
	TC.customer = MT.customer
AND
	TC.Ticket_Count = MT.Tickets_Count
--WHERE
--	TC.Emp_name = 'nazmuddin shaik'
ORDER BY
	TC.Customer,TC.Emp_name;

--Creating view about Number tickets worked per each customer and employee for resuing the query

CREATE VIEW TicketCounts AS
SELECT
	Emp_Name,
	customer,
	COUNT(Ticket_No) AS Tickets_Count		--(Without Aliasing we cannot create view)
FROM 
	Emp_tickets
GROUP BY 
	Emp_Name,
	customer;


--(8)Determining customer if all employees worked on the project then it shows as All employees worked on the project other wise show the name of the specific employees who are worked on that project

WITH Employees_Worked AS
(
SELECT
	customer,
	Emp_name
FROM
	Emp_tickets
GROUP BY
	customer,
	Emp_name
),  Emp_count AS
(
SELECT
	Customer,
	COUNT(Emp_name) AS [Total No of Employees worked]
FROM
	Employees_Worked
GROUP BY 
	customer
) , Emp_status AS 
(
SELECT
	ec.customer,
	CASE WHEN ec.[Total No of Employees worked] = (SELECT COUNT(DISTINCT(Emp_name)) FROM Employees_Worked)THEN 'All employees worked on the project'
	ELSE NULL
	END AS [Total Employees worked]
FROM
	Emp_count ec
)
SELECT 
	es.customer,
	COALESCE(es.[Total Employees worked],STRING_AGG(ew.Emp_name, ',')) AS [Total Employees worked]		--here COALESCE finds the null values and append the emp name by use of STRING_AGG employee names separated with coma
FROM
    Emp_status es
JOIN 
    Employees_Worked ew ON es.Customer = ew.Customer
GROUP BY 
    es.customer, es.[Total Employees worked]
ORDER BY 
    1;

-- (9) Determine Total Number of Incidents,Service Requests, Helpdesk tickets worked by each employee
SELECT
    Emp_name,
    COUNT(CASE WHEN Ticket_type = 'IN' THEN Ticket_No END) AS Incidents_count,
    COUNT(CASE WHEN Ticket_type = 'SR' THEN Ticket_No END) AS Servicetickets_count,
    COUNT(CASE WHEN Ticket_type = 'HD' THEN Ticket_No END) AS Helpdesktickets_count,
	Count(Ticket_No) AS Total_tickets
FROM
    Emp_tickets
GROUP BY
    Emp_name;

-- (10)Determine the Toatl Number Days worked for incidents,Service request & Helpdesk tickets worked  by each employee
SELECT
    Emp_name,
    COUNT(DISTINCT CASE WHEN Ticket_type = 'IN' THEN Created_On END) AS Days_worked_incidents,
    COUNT(DISTINCT CASE WHEN Ticket_type = 'SR' THEN Created_On END) AS Days_worked_Servicetickets,
    COUNT(DISTINCT CASE WHEN Ticket_type = 'HD' THEN Created_On END) AS Days_worked_Helpdesktickets
FROM
    Emp_tickets
GROUP BY
    Emp_name;
-- (11) Avarage Number of Incidents, Service request & Helpdesk ticlets worked by each employee NOTE: here round of to the nearest integer
WITH CTE AS (
    SELECT
        Emp_name,
        COUNT(CASE WHEN Ticket_type = 'IN' THEN Ticket_No END) AS Incidents_count,
        COUNT(CASE WHEN Ticket_type = 'SR' THEN Ticket_No END) AS Servicetickets_count,
        COUNT(CASE WHEN Ticket_type = 'HD' THEN Ticket_No END) AS Helpdesktickets_count,
		COUNT(DISTINCT CASE WHEN Ticket_type = 'IN' THEN Created_On END) AS Days_worked_incidents,
		COUNT(DISTINCT CASE WHEN Ticket_type = 'SR' THEN Created_On END) AS Days_worked_Servicetickets,
		COUNT(DISTINCT CASE WHEN Ticket_type = 'HD' THEN Created_On END) AS Days_worked_Helpdesktickets
    FROM
        Emp_tickets
    GROUP BY
        Emp_name
)
SELECT
    Emp_name,
    ROUND(AVG(CAST(Incidents_count AS FLOAT) / Days_worked_incidents),0) AS Avg_incidents_per_day,
    ROUND(AVG(CAST(Servicetickets_count AS FLOAT) / Days_worked_Servicetickets),0) AS Avg_servicetickets_per_day,
    ROUND(AVG(CAST(Helpdesktickets_count AS FLOAT) / Days_worked_Helpdesktickets),0) AS Avg_helpdesktickets_per_day
FROM
    CTE
GROUP BY
    Emp_name;

--(12)a) Creating a stored procedure that takes Employee name & date return the all of the ticekts worked by the employee
CREATE PROCEDURE sp.Emp_tickets
	@name NVARCHAR(20),
	@date NVARCHAR(10)
AS
BEGIN
SET NOCOUNT ON;

SELECT *
FROM 
	dbo.Emp_tickets
WHERE
	Emp_name = @name AND
	Created_On = @date
END

SELECT *
FROM information_schema.tables
WHERE table_name = 'Emp_tickets';


--(12)b) Executing the Stored Procedure Enter the Details in between quotes and date should be in YYYY-MM-DD Format

EXEC sp.Emp_tickets  @name = 'Nazmuddin Shaik', @date = '2024-06-12';


--(13) Determine the Cutsomers which are not worked by employee
SELECT 
	e.Emp_name, 
	STRING_AGG(c.Customer, ', ') AS [Customers not worked]
FROM 
	(SELECT DISTINCT Emp_name FROM Emp_tickets) e CROSS JOIN 
	(SELECT DISTINCT Customer FROM Emp_tickets) c LEFT JOIN 
	Emp_tickets et
ON 
	e.Emp_name = et.Emp_name AND c.Customer = et.Customer
WHERE 
	et.Customer IS NULL
GROUP BY 
	e.Emp_name;

--(14)Determine the Number of Help Desk tickets(i.e. Ticket_type = 'HD') genrated per week

WITH DateInfo AS (
    SELECT
        created_on,
        DATEPART(WEEK, created_on) - DATEPART(WEEK, '2024-04-01') + 1 AS Week_Number,
        created_on AS Actual_Date
    FROM Emp_tickets
    WHERE created_on BETWEEN '2024-04-01' AND '2024-09-30'
),
Weekdates AS (
    SELECT DISTINCT
        Week_Number,
        MIN(Actual_Date) OVER (PARTITION BY Week_Number) AS Week_start_date,
        MAX(Actual_Date) OVER (PARTITION BY Week_Number) AS Week_end_date
    FROM DateInfo
),
Ticket_count AS (
    SELECT
        DATEPART(WEEK, created_on) - DATEPART(WEEK, '2024-04-01') + 1 AS Week_number,
        COUNT(Ticket_No) AS Ticket_no
    FROM Emp_tickets
	WHERE
        ticket_type = 'HD'
        AND created_on BETWEEN '2024-04-01' AND '2024-09-30'
    GROUP BY DATEPART(WEEK, created_on) - DATEPART(WEEK, '2024-04-01') + 1
)
SELECT 
    t.Week_Number,
    w.Week_start_date + ' to ' + w.Week_end_date AS Week_range,
    t.Ticket_no
FROM Ticket_count t
JOIN Weekdates w ON t.Week_number = w.Week_number
ORDER BY t.Week_Number;

--(15) Determine the Avarage Number of HD tickets (i.e Ticket_Type = 'HD") genrated per week
WITH Ticket_Count AS 
(SELECT
	DATEPART(WEEK,Created_On) AS Week_No ,
	COUNT(Ticket_NO) AS Tickets_count
FROM
	Emp_tickets
WHERE
	Ticket_Type = 'HD'
	AND Created_On BETWEEN '2024-04-01' AND '2024-09-30'
GROUP BY
	DATEPART(WEEK,Created_On)
),Total_tickets AS
(SELECT
	SUM(Tickets_count) As total_tickets,
	COUNT(Week_No) AS [Total_No_of weeks]
FROM
	Ticket_Count
)SELECT
	ROUND(AVG(CAST(total_tickets AS FLOAT)/[Total_No_of weeks]),0)AS Total_Tickets
FROM
Total_tickets;



--(16)Determine the Ticket which are worked by the two or more employees and display the employees also
SELECT
    Ticket_No,
    Customer,
    title,
    STRING_AGG(Emp_name, ',') AS Employee_Names
FROM
    Emp_tickets 
GROUP BY
    Ticket_No,
    Customer,
    title
HAVING
    COUNT(DISTINCT Emp_name) > 1;

SELECT * 
FROM Emp_tickets

