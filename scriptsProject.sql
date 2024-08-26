CREATE DATABASE DBlessons;

-- Creating Tables
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    price DECIMAL(10, 2)
);
CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    employee_name VARCHAR(100),
    position VARCHAR(50)
);
CREATE TABLE SalesTransactions (
    transaction_id INT PRIMARY KEY,
    product_id INT,
    employee_id INT,
    quantity INT,
    FOREIGN KEY (product_id) REFERENCES Products(product_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    contact_info VARCHAR(100)
);
CREATE TABLE Suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100),
    contact_info VARCHAR(100)
);
CREATE TABLE ProductSuppliers (
    product_id INT,
    supplier_id INT,
    PRIMARY KEY (product_id, supplier_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);
CREATE TABLE StoreLocations (
    location_id INT PRIMARY KEY,
    location_name VARCHAR(100),
    address VARCHAR(100)
);
CREATE TABLE EmployeeLocations (
    employee_id INT,
    location_id INT,
    PRIMARY KEY (employee_id, location_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id),
    FOREIGN KEY (location_id) REFERENCES StoreLocations(location_id)
);
CREATE TABLE CustomerFeedback (
    feedback_id INT PRIMARY KEY,
    customer_id INT,
    feedback TEXT,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);
CREATE TABLE SalesLog (
    log_id INT PRIMARY KEY IDENTITY,
    transaction_id INT,
    product_id INT,
    employee_id INT,
    quantity INT,
    log_time DATETIME DEFAULT GETDATE()
);
CREATE TABLE SupplierContactHistory (
    history_id INT PRIMARY KEY IDENTITY,
    supplier_id INT,
    old_contact_info VARCHAR(100),
    new_contact_info VARCHAR(100),
    change_date DATETIME DEFAULT GETDATE()
);



-- Editing relationships (primary and foreign keys) between tables 
ALTER TABLE SalesLog
ADD CONSTRAINT FK_SalesLog_Transaction
FOREIGN KEY (transaction_id)
REFERENCES SalesTransactions(transaction_id);

ALTER TABLE SalesLog
ADD CONSTRAINT FK_SalesLog_Product
FOREIGN KEY (product_id)
REFERENCES Products(product_id);

ALTER TABLE SalesLog
ADD CONSTRAINT FK_SalesLog_Employee
FOREIGN KEY (employee_id)
REFERENCES Employees(employee_id);

ALTER TABLE SupplierContactHistory
ADD CONSTRAINT FK_SupplierContactHistory_Supplier FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id);



-- Inserting values to tables
INSERT INTO Products (product_id, product_name, price) VALUES (1, 'Product 1', 10.00);
INSERT INTO Employees (employee_id, employee_name, position) VALUES (1, 'Employee 1', 'Manager');
INSERT INTO SalesTransactions (transaction_id, product_id, employee_id, quantity) VALUES (1, 1, 1, 2);
INSERT INTO Customers (customer_id, customer_name, contact_info) VALUES (1, 'Customer 1', '123-456-7890');



-- Creating indexes
CREATE INDEX idx_product_name ON Products (product_name);
CREATE INDEX idx_employee_name ON Employees (employee_name);
CREATE INDEX idx_customer_name ON Customers (customer_name);



-- Creating a login and a user with limited rights
CREATE LOGIN limited_user WITH PASSWORD = 'SuperPassword123';
CREATE USER limited_user FOR LOGIN limited_user;
ALTER ROLE db_datareader ADD MEMBER limited_user;
ALTER ROLE db_datawriter ADD MEMBER limited_user;

-- Creating login and user with full rights (admin)
CREATE LOGIN admin_user WITH PASSWORD = 'UltraPassword123@';
CREATE USER admin_user FOR LOGIN admin_user;
ALTER SERVER ROLE sysadmin ADD MEMBER admin_user;



-- Creating Views
CREATE VIEW ViewWithJoin AS
SELECT p.product_name, s.quantity, e.employee_name
FROM Products p
JOIN SalesTransactions s ON p.product_id = s.product_id
JOIN Employees e ON s.employee_id = e.employee_id;

CREATE VIEW ViewWithUnion AS
SELECT product_name AS name, 'Product' AS type
FROM Products
UNION
SELECT employee_name, 'Employee'
FROM Employees;

CREATE VIEW SimpleView AS
SELECT customer_name, contact_info
FROM Customers;



--Procedure to get all products with a price above a certain value
CREATE PROCEDURE GetProductsAbovePrice
    @Price DECIMAL(10, 2)
AS
BEGIN
    SELECT * FROM Products WHERE price > @Price;
END;

--Procedure to update customer contact information:
CREATE PROCEDURE UpdateCustomerContactInfo
    @CustomerID INT,
    @NewContactInfo VARCHAR(100)
AS
BEGIN
    UPDATE Customers SET contact_info = @NewContactInfo WHERE customer_id = @CustomerID;
END;

--Procedure to delete a product by ID:
CREATE PROCEDURE DeleteProductByID
    @ProductID INT
AS
BEGIN
    DELETE FROM Products WHERE product_id = @ProductID;
END;


-- (sub)Query to obtain products that have never been sold
SELECT * FROM Products 
	WHERE product_id NOT IN (SELECT product_id FROM SalesTransactions)
		ORDER BY product_id DESC;

-- Get the number of sales for each product
SELECT product_id, sales_count
FROM (
    SELECT product_id, COUNT(*) AS sales_count
    FROM SalesTransactions
    GROUP BY product_id
) AS NumOfSalesPerProdSubquery;

-- Get avg product price sold today
SELECT AVG(product_price) AS average_price_today
FROM (
    SELECT P.price AS product_price
    FROM SalesLog SL
    JOIN Products P ON SL.product_id = P.product_id
    WHERE CAST(SL.log_time AS DATE) = CAST(GETDATE() AS DATE)
) AS AvgPriceTodaySubquery;



-- Creating triggers
CREATE TRIGGER trg_InsertSalesTransactions
ON SalesTransactions
AFTER INSERT
AS
BEGIN
    INSERT INTO SalesLog (transaction_id, product_id, employee_id, quantity)
    SELECT 
        inserted.transaction_id, 
        inserted.product_id, 
        inserted.employee_id, 
        inserted.quantity
    FROM 
        inserted;
END;

CREATE TRIGGER trg_BeforeInsertProducts
ON Products
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (SELECT * FROM inserted WHERE price < 0)
    BEGIN
        RAISERROR('Price cannot be negative', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO Products (product_id, product_name, price)
        SELECT product_id, product_name, price
        FROM inserted;
    END
END;

CREATE TRIGGER trg_UpdateSupplierContactInfo
ON Suppliers
AFTER UPDATE
AS
BEGIN
    IF UPDATE(contact_info)
    BEGIN
        INSERT INTO SupplierContactHistory (supplier_id, old_contact_info, new_contact_info)
        SELECT 
            deleted.supplier_id, 
            deleted.contact_info, 
            inserted.contact_info
        FROM 
            inserted
        INNER JOIN 
            deleted 
        ON 
            inserted.supplier_id = deleted.supplier_id;
    END
END;



-- Creating backups
DECLARE @backupCount INT;
DECLARE @backupPath NVARCHAR(500);
DECLARE @currentDate DATETIME;
DECLARE @lastBackupDate DATETIME;
DECLARE @backupName NVARCHAR(500);

-- I will leave it like that so you can test if it works on your computer
SET @backupPath = 'insert here your path to store dbbackup :)';

SET @currentDate = GETDATE();
SELECT @backupCount = COUNT(*)
FROM msdb.dbo.backupset
WHERE database_name = 'DBlessons';
IF @backupCount >= 30
BEGIN
    SELECT TOP 1 @lastBackupDate = backup_finish_date
    FROM msdb.dbo.backupset
    WHERE database_name = 'DBlessons'
    ORDER BY backup_finish_date ASC;

    SET @backupName = @backupPath + 'DBBackup_' + REPLACE(CONVERT(NVARCHAR(50), @lastBackupDate, 120), ':', '') + '.bak'; 
    EXECUTE master.dbo.xp_delete_file 0, @backupName, 'BAK';
END

SET @backupName = @backupPath + 'DBBackup_' + REPLACE(CONVERT(NVARCHAR(50), @currentDate, 120), ':', '') + '.bak';

BACKUP DATABASE YourDatabaseName TO DISK = @backupName; 


-- stored procedures
sp_spaceused;
sp_help;
sp_helptext;
sp_helptext 'GetProductsAbovePrice';
sp_configure;
sp_helpindex 'Products';
sp_depends 'Products';
sp_who;
sp_lock;
sp_server_info;
sp_tables;