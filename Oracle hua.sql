--Συνάρτηση για τον υπολογισμό ηλικίας από την ημερομηνία
CREATE OR REPLACE FUNCTION get_age_group(BIRTH_DATE DATE) RETURN VARCHAR2 AS
  age INT;--οριζω μεταβλητη ΙΝΤ για να ελέγξω την ηλικία
BEGIN
  age := TRUNC(MONTHS_BETWEEN(SYSDATE, BIRTH_DATE) / 12);--υπολογισμος ηλικιας μεσω της διαφορας των μηνων διαιρεμενει με το 12 και περνοντας το ακεραιο μερος μόνο

  IF age < 40 THEN
    RETURN 'under 40';
  ELSIF age BETWEEN 40 AND 49 THEN
    RETURN '40-49';
  ELSIF age BETWEEN 50 AND 59 THEN
    RETURN '50-59';
  ELSIF age BETWEEN 60 AND 69 THEN
    RETURN '60-69';
  ELSIF age >= 70 THEN 
    RETURN 'above 70';
  ELSE 
    RETURN 'NON RECORDABLE';
  END IF;--τελος ιφ
END;--τελοσ συναρτησης
/
--μετατρεπει το income range σε high , meduim ,low  συμβολοσειρά
CREATE OR REPLACE FUNCTION get_income_level(income_range VARCHAR2) RETURN VARCHAR2 AS

  income_high NUMBER;-- μεταβλητη για τον μεγαλυτερο αριθμο
BEGIN
  --με τα επομενα ορισματα επιστρεφει αναλογως την πρωτη ή την δευτερη ακολουθια ψηφιων
  income_high := TO_NUMBER(REGEXP_SUBSTR(income_range, '\d+', 1, 2));--to_number μετατρεπει το "111"σε ακεραιο 111

  If  income_high <= 129999 THEN
    RETURN 'low';
  ELSIF  income_high <= 249999 and income_high>129999 THEN
    RETURN 'meduim';
  ELSE
    RETURN 'high';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'UNKNOWN'; -- Return 'UNKNOWN' ΣΕ ΠΕΡΙΠΤΩΣΗ ΛΑΘΟΥΣ
END;
/


CREATE OR REPLACE FUNCTION fix_status(marital_status VARCHAR2) RETURN VARCHAR2 AS
BEGIN
  CASE
    WHEN marital_status IN ('Widowed', 'Separ.', 'divorced', 'NeverM', 'Single', 'Divorc.') THEN --ελέγχει την τιμή marital_status 
      RETURN 'single';
    WHEN marital_status = 'married' THEN
      RETURN 'married';
    ELSE
      RETURN 'unknown';
  END CASE;--TELOS CASE
END;
/



CREATE TABLE CUSTOMERS AS--ΔΗΜΙΟΥΡΓΙΑ ΠΙΝΑΚΑ ΠΕΛΑΤΩΝ ΑΠΟ ΤΗΝ ΒΑΣΗ XSALES ΧΡΗΣΙΜΟΠΟΙΟΝΤΑΣ ΤΙΣ ΣΥΝΑΡΤΗΣΕΙΣ ΠΡΑΠΑΝΩ
SELECT C.ID AS CUSTOMER_ID,C.GENDER, get_age_group(C.BIRTH_DATE) AS AGEGROUP, fix_status(C.MARITAL_STATUS) as MARITAL_STATUS,get_income_level(C.INCOME_LEVEL)AS INCOME_LEVEL
FROM XSALES.CUSTOMERS C;




CREATE TABLE PRODUCTS AS---ΠΙΝΑΚΑ ΜΕ ΠΡΟΙΟΝΤΑ
SELECT P.IDENTIFIER AS PRODUCT_ID, P.NAME AS PRODUCT_NAME, C.DESCRIPTION AS CATEGORY_NAME, P.LIST_PRICE
FROM XSALES.PRODUCTS P--ΧΡΕΙΑΣΤΗΚΑ DESCRIPTION ΣΑΝ ΓΝΩΡΙΣΜΑ ΤΟΥ ΠΙΝΑΚΑ ΠΟΥ ΘΑ ΕΦΤΙΑΧΝΑ ΓΙΑ ΑΥΤΟ ΕΚΑΝΑ JOIN
INNER JOIN XSALES.CATEGORIES C ON P.SUBCATEGORY_REFERENCE = C.ID;

CREATE TABLE ORDERS AS--πινακα παραγγελιων
SELECT O.ID AS ORDER_ID,
       O.CUSTOMER_ID AS CUSTOMER_ID,
       O.CHANNEL AS CHANNEL,
       I.PRODUCT_ID AS PRODUCT_ID,
       I.AMOUNT AS PRICE,
       I.COST AS COSTS,
       (O.ORDER_FINISHED - I.ORDER_DATE) AS DAYS_TO_PROCESS--ηθελα την διαφορα σκεφτηκα να βαλω και την συναρτηση floor αλλα δεν χρειαστηκε
FROM XSALES.ORDERS O
INNER JOIN XSALES.ORDER_ITEMS I ON O.ID = I.ORDER_ID;


--ΕΜΦΑΝΙΣΗ ΤΩΝ ΠΙΝΑΚΩΝ ΜΑΣ
SELECT * FROM CUSTOMERS;
SELECT * FROM ORDERS;
SELECT * FROM PRODUCTS;


---




--2ο)Ερώτημα--πρεπει να τρεξετε ολο το 2ο ερωτημα μαζί

-- Ορισμός του πίνακα για τις ζημιές
CREATE TABLE deficit_orders (
  order_id NUMBER,
  customer_id NUMBER,
  channel VARCHAR2(50),
  amount NUMBER
);

-- Ορισμός του πίνακα για τα κέρδη
CREATE TABLE profit_orders ( -- Προσθήκη πεδίων max_delay και final_profit στον πίνακα orders
  order_id  NUMBER , 
  customer_id NUMBER,
  channel VARCHAR2(50),
  amount NUMBER
);

--I)
 CREATE INDEX idx_orders_id
ON orders (order_id);--χρησιμοποιω για να γινουν οι συναρτησεις πιο γρηγορες 

CREATE OR REPLACE FUNCTION CalculateMaxDelay(or_id IN NUMBER) RETURN NUMBER AS
  v_max_delay NUMBER;
  
BEGIN
  SELECT /*+INDEX( o idx_orders_id)*/MAX(days_to_process - 20)
  INTO v_max_delay
  FROM orders 
  WHERE order_id = or_id;
IF v_max_delay<0 THEN
RETURN 0;
ELSE
  RETURN NVL(v_max_delay, 0);--για να εξασφαλίσετε ότι η επιστρεφόμενη τιμή είναι τουλάχιστον 0.
  END IF;
END CalculateMaxDelay;
/
SELECT CalculateMaxDelay(ORDER_ID),ORDER_ID
FROM ORDERS;

--II)
CREATE OR REPLACE FUNCTION CalculateOrderProfit(or_id IN NUMBER) RETURN NUMBER AS
  v_final_profit NUMBER;
BEGIN
  SELECT/*+Index( o idx_orders_id)*/ SUM((O.price - O.costs) - (O.days_to_process * 0.001 * P.list_price))
  INTO v_final_profit
  FROM orders O
  INNER JOIN products P ON O.product_id = P.product_id
  WHERE O.order_id = or_id;

  RETURN NVL(v_final_profit, 0);--για να εξασφαλίσετε ότι η επιστρεφόμενη τιμή είναι τουλάχιστον 0.
END CalculateOrderProfit;
/
  SELECT ORDER_ID,CUSTOMER_ID,CalculateOrderProfit(ORDER_ID),PRODUCT_ID
  FROM ORDERS;



--III)--
CREATE INDEX IDX_ORDER ON ORDERS (ORDER_ID);

CREATE OR REPLACE PROCEDURE ProcessOrders AS
  CURSOR order_cursor IS
    SELECT /*+INDEX (IDX_ORDER)*/ order_id, customer_id, channel, days_to_process, price, costs, product_id
    FROM orders;

  c_order_rec order_cursor%ROWTYPE;
  c_amount NUMBER;

BEGIN
  FOR c_order_rec IN order_cursor LOOP
    c_amount := CalculateOrderProfit(c_order_rec.order_id);

    -- Έλεγχος αν το κέρδος είναι αρνητικό ή θετικό
    IF c_amount < 0 THEN
      -- Καταχώρηση στον πίνακα ζημιάς
      INSERT INTO deficit_orders (order_id, customer_id, channel, amount)
      VALUES (c_order_rec.order_id, c_order_rec.customer_id, c_order_rec.channel, c_amount);
    ELSE
      -- Καταχώρηση στον πίνακα κερδών
      INSERT INTO profit_orders (order_id, customer_id, channel, amount)
      VALUES (c_order_rec.order_id, c_order_rec.customer_id, c_order_rec.channel, c_amount);
    END IF;
  END LOOP;
END;
/



exec ProcessOrders;

SELECT * FROM PROFIT_ORDERS;
SELECT * FROM DEFICIT_ORDERS;
DROP INDEX idx_orders_id;
--iv)
-- Συνολικά έσοδα ανά φύλο χωρίς διπλότυπες εγγραφές
SELECT SUM(amount) AS total_income,
       gender
FROM (
    SELECT /*+INDEX (IDX_ORDER)*/ DISTINCT  P.amount, C.gender
    FROM profit_orders P
   INNER JOIN orders O ON P.order_id = O.order_id
   INNER JOIN customers C ON O.customer_id = C.customer_id
)
GROUP BY gender;

-- Συνολικές ζημιές ανά φύλο χωρίς διπλότυπες εγγραφές
SELECT SUM(amount) AS total_deficit,
       gender
FROM (
    SELECT /*+INDEX (IDX_ORDER)*/  DISTINCT D.amount, C.gender
    FROM deficit_orders D
   INNER JOIN orders O ON D.order_id = O.order_id
  INNER  JOIN customers C ON O.customer_id = C.customer_id
)
GROUP BY gender;
 

---V)
-- Συνολικά έσοδα ανά κανάλι παραγγελιών
SELECT O.channel,
       SUM(P.amount) AS total_income  
FROM profit_orders P
JOIN orders O ON P.order_id = O.order_id
GROUP BY O.channel;

-- Συνολικές ζημιές ανά κανάλι παραγγελιών
SELECT O.channel,
       SUM(D.amount) AS total_deficit
FROM deficit_orders D
JOIN orders O ON D.order_id = O.order_id
GROUP BY O.channel;



---3o Ερώτημα
DELETE FROM PLAN_TABLE;
EXPLAIN PLAN FOR
SELECT o.order_id, o.price - o.costs, o.days_to_process
FROM products p
JOIN orders o ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.category_name = 'Accessories'
  AND o.channel = 'Internet'
  AND c.gender = 'Male'
  AND c.income_level = 'high'
  AND o.days_to_process = 0;


-- Εκτύπωση του σχεδίου εκτέλεσης
SELECT OPERATION ,OPTIONS , OBJECT_NAME,OBJECT_TYPE,ID, PARENT_ID,DEPTH,
COST ,CPU_COST,IO_COST, CARDINALITY, FILTER_PREDICATES, ACCESS_PREDICATES ,PROJECTION
FROM PLAN_TABLE
CONNECT  BY PRIOR ID = PARENT_ID
START WITH ID=0 
ORDER BY ID;

---Για τον υπολογισμό των πραγματικών επστρεφόμενων πλειάδων
SELECT COUNT(*) FROM(SELECT o.order_id, o.price - o.costs, o.days_to_process
FROM products p
JOIN orders o ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.category_name = 'Accessories'
  AND o.channel = 'Internet'
  AND c.gender = 'Male'
  AND c.income_level = 'high'
  AND o.days_to_process = 0);
---βελτιωση σχεδιου

--btree index
CREATE INDEX idx_orders_product_channel ON orders(product_id, channel);
CREATE INDEX idx_products_categoryname ON products(category_name);
CREATE INDEX idx_customers_id_gender_income ON customers(customer_id, gender, income_level);


DELETE FROM PLAN_TABLE;
EXPLAIN PLAN FOR
SELECT /*+INDEX(p idx_products_categoryname) INDEX(o idx_products_channel) INDEX(c idx_customers_id_gender_income)*//* USE_HASH(o p c)*/
  o.order_id, o.price - o.costs, o.days_to_process
FROM products p
JOIN orders o ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.category_name = 'Accessories'
  AND o.channel = 'Internet'
  AND c.gender = 'Male'
  AND c.income_level = 'high'
  AND o.days_to_process = 0;



SELECT OPERATION ,OPTIONS , OBJECT_NAME,OBJECT_TYPE,ID, PARENT_ID,DEPTH,
COST ,CPU_COST,IO_COST, CARDINALITY, FILTER_PREDICATES, ACCESS_PREDICATES ,PROJECTION
FROM PLAN_TABLE
CONNECT  BY PRIOR ID = PARENT_ID
START WITH ID=0 
ORDER BY ID;


--4oΕρωτημα


-- Διαγραφή του ευρετηρίου idx_orders_product_channel
DROP INDEX idx_customers_id_gender_income

-- Διαγραφή του ευρετηρίου idx_products_categoryname
DROP INDEX idx_products_categoryname;

-- Διαγραφή του ευρετηρίου idx_customers_id_gender_income
DROP INDEX idx_customers_id_gender_income;


DELETE FROM PLAN_TABLE;
EXPLAIN PLAN FOR
  SELECT /*+NO_INDEX*/o.order_id, o.price - o.costs, o.days_to_process
FROM products p
JOIN orders o ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.category_name = 'Accessories'
  AND o.channel = 'Internet'
  AND c.gender = 'Male'
  AND c.income_level = 'high'
  AND o.days_to_process >100;


SELECT OPERATION ,OPTIONS , OBJECT_NAME,OBJECT_TYPE,ID, PARENT_ID,DEPTH,
COST ,CPU_COST,IO_COST, CARDINALITY, FILTER_PREDICATES, ACCESS_PREDICATES ,PROJECTION
FROM PLAN_TABLE
CONNECT  BY PRIOR ID = PARENT_ID
START WITH ID=0 
ORDER BY ID;

---βελτιοση σχεδίου
DELETE FROM PLAN_TABLE;

CREATE BITMAP INDEX IDX_PRODUCTS_CATEGORY ON products(product_id, category_name);
CREATE BITMAP INDEX IDX_C_GEND ON  customers(customer_id, gender);
CREATE BITMAP INDEX IDX_C_income ON  customers(customer_id, income_level);
CREATE INDEX idx_orders_product_channel ON orders(order_id,product_id, channel);

EXPLAIN PLAN FOR
SELECT /*INDEX(p IDX_PRODUCTS_CATEGORY) INDEX(c IDX_C_GEND ) INDEX(c IDX_C_income)  INDEX(o idx_orders_product_channel)*/
  o.order_id, o.price - o.costs, o.days_to_process
FROM products p
JOIN orders o ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.category_name = 'Accessories'
  AND o.channel = 'Internet'
  AND c.gender = 'Male'
  AND c.income_level = 'high'
  AND o.days_to_process > 100;


SELECT OPERATION ,OPTIONS , OBJECT_NAME,OBJECT_TYPE,ID, PARENT_ID,DEPTH,
COST ,CPU_COST,IO_COST, CARDINALITY, FILTER_PREDICATES, ACCESS_PREDICATES ,PROJECTION 
FROM PLAN_TABLE
CONNECT  BY PRIOR ID = PARENT_ID
START WITH ID=0 
ORDER BY ID;

-- Drop the bitmap indexes
DROP INDEX IDX_PRODUCTS_CATEGORY;
DROP INDEX IDX_C_GEND ;
DROP INDEX IDX_C_income;

-- Drop the regular index
DROP INDEX idx_orders_product_channel ;

--Ερώτημα i)
-- Δημιουργία της στήλης Address
ALTER TABLE Customers
ADD Address VARCHAR2(100);

-- Ενημέρωση της στήλης Address με τυχαίες τιμές
UPDATE Customers
SET Address = (
    SELECT 
        CASE 
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN 'Athens'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.7 THEN 'Thessaloniki'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.8 THEN 'Patras'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.9 THEN 'Heraklion'
            ELSE 'Larissa'
        END || ', ' ||
        CASE 
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.1 THEN 'Adrianou Street'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.2 THEN 'Athinas Street'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.3 THEN 'Ermou Street'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.4 THEN 'Panepistimiou Avenue'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN 'Patision Street'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.6 THEN 'Vasilissis Sofias Avenue'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.7 THEN 'Kifisias Avenue'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.8 THEN 'Syngrou Avenue'
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.9 THEN 'Vouliagmenis Avenue'
            ELSE 'Stadiou Street'
        END || ' ' ||
        TO_CHAR(DBMS_RANDOM.VALUE(1, 100))
    FROM dual
);
-- Εμφάνιση των εγγραφών για έλεγχο
SELECT * FROM Customers;

--Ερώτημα ii)
-- Προσθήκη της στήλης ProductTypes
ALTER TABLE Products
ADD ProductTypes VARCHAR2(100);

-- Ενημέρωση της στήλης ProductTypes με τιμές ανάλογα με το CategoryName
UPDATE Products
SET PRODUCTTYPES = 
  CASE 
    WHEN CATEGORY_NAME = 'CD-ROM' THEN 'storage'
    WHEN CATEGORY_NAME = 'Modems/Fax' THEN 'communication'
    WHEN CATEGORY_NAME = 'Documentation' THEN 'office'
    WHEN CATEGORY_NAME = 'Recordable DVD Discs' THEN 'storage'
    WHEN CATEGORY_NAME = 'Printer Supplies' THEN 'office'
    WHEN CATEGORY_NAME = 'Game Consoles' THEN 'games'
    WHEN CATEGORY_NAME = 'Accessories' THEN 'other'
    WHEN CATEGORY_NAME = 'Bulk Pack Diskettes' THEN 'storage'
    WHEN CATEGORY_NAME = 'Y Box Games' THEN 'games'
    WHEN CATEGORY_NAME = 'Camcorders' THEN 'video'
    WHEN CATEGORY_NAME = 'Recordable CDs' THEN 'storage'
    WHEN CATEGORY_NAME = 'Desktop PCs' THEN 'computer'
    WHEN CATEGORY_NAME = 'Camera Batteries' THEN 'electronics'
    WHEN CATEGORY_NAME = 'Memory' THEN 'electronics'
    WHEN CATEGORY_NAME = 'Home Audio' THEN 'audio'
    WHEN CATEGORY_NAME = 'Operating Systems' THEN 'software'
    WHEN CATEGORY_NAME = 'Camera Media' THEN 'electronics'
    WHEN CATEGORY_NAME = 'Cameras' THEN 'electronics'
    WHEN CATEGORY_NAME = 'Monitors' THEN 'computer'
    WHEN CATEGORY_NAME = 'Portable PCs' THEN 'computer'
    WHEN CATEGORY_NAME = 'Y Box Accessories' THEN 'other'
    ELSE 'other'
  END;

-- Εμφάνιση των εγγραφών για έλεγχο
SELECT * FROM Products;

DESCRIBE Products;

SELECT DISTINCT CATEGORY_NAME
FROM Products;

--Ερώτημα iv)
--Για κάποιο λόγο δεν μου αναγνωρίζιε το product_package γιατί μου λέει ότι δεν υπάρχει ή ότι χρησιμοποιείται ήδη δεν έχω καταλάβει!!
CREATE OR REPLACE PACKAGE PRODUCT_TYPE AS
  TYPE product_type AS OBJECT (
    product_id NUMBER,
    productname VARCHAR2(100),
    categoryname VARCHAR2(100),
    producttypes VARCHAR2(100),
    listprice VARCHAR2(10)
  );
-- Τύπος order_item_type: Περιγράφει τα χαρακτηριστικά ενός στοιχείου παραγγελίας, που περιλαμβάνει ένα προϊόν.
  TYPE order_item_type AS OBJECT (
    days_to_process NUMBER,
    price NUMBER,
    cost NUMBER,
    channel VARCHAR2(100),
    product product_type
  );
-- Τύπος order_item_list: Λίστα από στοιχεία παραγγελίας.
  TYPE order_item_list IS TABLE OF order_item_type;

-- Τύπος order_type: Περιγράφει τα χαρακτηριστικά μιας παραγγελίας, που περιλαμβάνει μια λίστα από στοιχεία παραγγελίας.
  TYPE order_type AS OBJECT (
    customer_id NUMBER,
    order_items order_item_list
  );
  
-- Το πακέτο BODY δεν περιέχει επιπλέον λειτουργίες αυτή τη στιγμή.
--CREATE OR REPLACE PACKAGE BODY PRODUCT_TYPE AS
  -- Εδώ μπορείτε να προσθέσετε ή να τροποποιήσετε τους επιπλέον ορισμούς τύπων που χρειάζεστε.
--END PRODUCT_TYPE;
--/



-- Εμφάνιση πληροφοριών για τον τύπο product_type
DESCRIBE product_type;

-- Εμφάνιση πληροφοριών για τον τύπο order_item_type
DESCRIBE order_item_type;

-- Εμφάνιση πληροφοριών για τον τύπο order_type
DESCRIBE order_type;

/









