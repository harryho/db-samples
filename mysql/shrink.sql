-- # entityId, contactName, cnt
-- 1, Allen, Michael, 6
-- 11, Jaffe, David, 10
-- 13, Benito, Almudena, 1
-- 17, Jones, TiAnna, 6
-- 19, Boseman, Randall, 8
-- 23, Khanna, Karan, 5
-- 29, Kolesnikova, Katerina, 5
-- 31, Cheng, Yao-Qiang, 9
-- 37, Crăciun, Ovidiu V., 19
-- 41, Litton, Tim, 14
-- 43, Deshpande, Anu, 2
-- 47, Lupu, Cornel, 12
-- 53, Mallit, Ken, 3
-- 59, Meston, Tosh, 10
-- 61, Florczyk, Krzysztof, 9
-- 67, Garden, Euan, 11
-- 71, Navarro, Tomás, 31
-- 73, Gonzalez, Nuria, 7
-- 79, Wickham, Jim, 6
-- 83, Fonteneau, Karl, 11
-- 89, Smith Jr., Ronaldo, 14
-- (1, 2,3,5,7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89)

SELECT
    sum(cnt)
FROM (
    SELECT
        c.entityId,
        c.contactName,
        count(1) cnt
    FROM
        Customer c
        JOIN SalesOrder o ON c.entityId = o.customerId
            -- AND (c.entityId mod 3 <> 0 AND c.entityId mod 2 <> 0 AND c.entityId mod 5 <> 0 AND c.entityId mod 6 <> 0 AND c.entityId mod 7 <> 0) c.entityId IN (1, 2,3, 11, 13, 23, 31, 35,  43,  53, 72,  73,  83)
    GROUP BY
        contactName,
        c.entityId) AS m9;

START TRANSACTION;

    SELECT count(*) FROM SalesOrder;

    SELECT count(*) FROM OrderDetail;

    SELECT count(*) FROM Customer;

    DELETE FROM OrderDetail
    WHERE orderId IN (
            SELECT
                entityId
            FROM
                SalesOrder
            WHERE
                customerId NOT IN (1, 2,3, 11, 13, 23, 31, 35,  43,  53, 72,  73,  83));

    DELETE FROM SalesOrder
    WHERE customerId NOT IN (1, 2,3, 11, 13, 23, 31, 35,  43,  53, 72,  73,  83);

    DELETE FROM Customer
    WHERE entityId NOT IN (1, 2,3, 11, 13, 23, 31, 35,  43,  53, 72,  73,  83);

    SELECT count(*) FROM NorthwindCore.SalesOrder;

    SELECT count(*) FROM NorthwindCore.OrderDetail;

    SELECT count(*) FROM NorthwindCore.Customer;

ROLLBACK;

