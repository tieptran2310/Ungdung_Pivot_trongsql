--Case01: Phân tích doanh thu theo năm

SELECT 
	YEAR(OrderDate) year,
	SUM(SubTotal) total_sales
INTO #pv01
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY YEAR(OrderDate)

--Case01a: pivot static: sắp xếp doanh thu từng năm trên các cột
SELECT * FROM #pv01
PIVOT(
	SUM(total_sales)   
    FOR year IN ([2011],[2012],[2013],[2014])) AS ypvot

--Case01b: pivot dynamic: sắp xếp doanh thu từng năm trên các cột

DECLARE @queryString AS NVARCHAR(MAX)
DECLARE @column AS NVARCHAR(MAX)
SELECT @column= ISNULL(@column + ',','') + QUOTENAME(year)
FROM (SELECT DISTINCT year FROM #pv01) AS Years
SET @queryString = 
  N'SELECT * FROM #pv01
    PIVOT
		(SUM(total_sales) 
         FOR year IN (' + @column + ')) AS ypvot'
EXEC sp_executesql @queryString

--Case02: Phân tích doanh thu theo quý và theo năm

Drop Table #pv02
SELECT 
	YEAR(OrderDate) year,
	DATEPART(QUARTER,OrderDate) quarter, 
	SUM(SubTotal) total_sales
INTO #pv02
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), DATEPART(QUARTER,OrderDate)
ORDER BY 1,2 ASC

-- Case02a: pivot static
SELECT * FROM #pv02
PIVOT( SUM(total_sales)   
        FOR quarter IN ([1],[2],[3],[4])) AS qpvot

-- Case02b: pivot dynamic -- doanh thu theo năm và quý
DECLARE @queryString AS NVARCHAR(MAX)
DECLARE @column AS NVARCHAR(MAX)
SELECT @column= ISNULL(@column + ',','') + QUOTENAME(quarter)
FROM (SELECT DISTINCT quarter FROM #pv02) AS Quarters
SET @queryString = 
  N'SELECT year, ' + @column + '
    FROM #pv02
    PIVOT(SUM(total_sales) 
          FOR quarter IN (' + @column + ')) AS qpvot'
EXEC sp_executesql @queryString

--- Case 04 | Phân tích hành vi mua hàng

-- Sales.SalesOrderHeader --a: hóa đơn
-- Sales.SalesOrderDetail --b: chi tiết hóa đơn
-- Production.Product --c: sản phẩm
-- Production.ProductCategory -- d: nhóm sản phẩm
-- Production.ProductSubcategory -- e: chi tiết nhóm sản phẩm

Drop Table #pv04 --xóa bảng tạm

-- Tạo bảng chứa mã nhân viên, mã hóa đơn, Nhóm sản phẩm, Nhóm, ID sản phẩm
SELECT
	a.CustomerID
	,a.SalesOrderID
	,e.Name ProductType
	,c.ProductLine
	,c.ProductID
INTO #pv04
FROM Sales.SalesOrderHeader a INNER JOIN Sales.SalesOrderDetail b ON a.SalesOrderID = b.SalesOrderID
INNER JOIN Production.Product c ON b.ProductID = c.ProductID
INNER JOIN Production.ProductSubcategory d ON c.ProductSubcategoryID = d.ProductSubcategoryID
INNER JOIN Production.ProductCategory e ON d.ProductCategoryID = e.ProductCategoryID
WHERE YEAR(a.OrderDate) = 2013

-- Sử dụng pivot để tách thành các cột chứa nhóm sản phẩm theo hóa đơn
Drop Table cte -- xóa bảng tạm

With cte as
(
	SELECT *
	--INTO #pv041
	FROM
		(SELECT DISTINCT SalesOrderID, ProductType, cnt = 1 FROM #pv04) a
	PIVOT
		(COUNT (Cnt) 
		FOR ProductType IN ([Bikes], [Accessories] ,[Clothing], [Components])
	) b
)

-- Đếm số lượng hóa đơn các nhóm sản phẩm khách hàng mua cùng nhau

SELECT Bikes,Accessories ,Clothing ,Components ,COUNT(*) num_orders
FROM cte
GROUP BY Bikes, Accessories, Clothing, Components
ORDER BY Bikes, Accessories, Clothing, Components

--Case05: Liệt kê khách hàng có chi tiêu trong quý 3 và quý 4, với điều kiện quý 3 < quý 4 năm 2013

-- Tạo bảng nguồn: doanh thu của mã nhân viên theo quý
Select 
	CustomerID Ma_NV,
	DATEPART(Quarter,OrderDate) Quy,
	SUM(SubTotal) Doanhthu
INTO #doanhthu
From Sales.SalesOrderHeader
Where YEAR(OrderDate)=2013
Group by CustomerID, DATEPART(Quarter,OrderDate)
Order by CustomerID, DATEPART(Quarter,OrderDate)

-- Thực hiện pivot và gắn điều kiện
Select 
Ma_NV Cus_ID, ---Đổi tên cột và thay giá trị null bằng 0
isnull([1],0) total_q1,
isnull([2],0) total_q2,
isnull([3],0) total_q3,
isnull([4],0) total_q4

from #doanhthu
Pivot
	(SUM(Doanhthu)
		For Quy in ([1],[2],[3],[4])) as pvt
Where [3] is not null and [3]<[4]
Order by Ma_NV,[4]

