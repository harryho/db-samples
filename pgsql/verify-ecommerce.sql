-- Sanity checks for the ecommerce sample database.
-- Run: psql -d ecommerce -f verify-ecommerce.sql
-- (or: docker exec -i pgsql-infra psql -U postgres -d ecommerce -f /tmp/verify-ecommerce.sql)
-- Every "expect 0" query returning a non-zero count indicates corrupt seed data.

\echo '=== Row counts ==='
SELECT 'users' AS table_name, count(*) FROM users
UNION ALL SELECT 'addresses', count(*) FROM addresses
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'product_variants', count(*) FROM product_variants
UNION ALL SELECT 'product_images', count(*) FROM product_images
UNION ALL SELECT 'inventory', count(*) FROM inventory
UNION ALL SELECT 'inventory_movements', count(*) FROM inventory_movements
UNION ALL SELECT 'carriers', count(*) FROM carriers
UNION ALL SELECT 'carts', count(*) FROM carts
UNION ALL SELECT 'cart_items', count(*) FROM cart_items
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'order_status_history', count(*) FROM order_status_history
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'shipments', count(*) FROM shipments
ORDER BY 1;

\echo '=== Orders by status ==='
SELECT status, count(*) FROM orders GROUP BY status ORDER BY 2 DESC;

\echo '=== Check 1: inventory ledger reconciles to snapshot (expect 0) ==='
SELECT count(*) AS mismatches
FROM inventory i
LEFT JOIN (SELECT variant_id, sum(quantity_delta) AS total
           FROM inventory_movements GROUP BY variant_id) m USING (variant_id)
WHERE coalesce(m.total, 0) <> i.quantity_on_hand;

\echo '=== Check 2: grand_total arithmetic (expect 0) ==='
SELECT count(*) AS mismatches
FROM orders
WHERE grand_total <> subtotal - discount_total + shipping_total;

\echo '=== Check 3: line totals match subtotal minus discounts (expect 0) ==='
SELECT count(*) AS mismatches
FROM orders o
JOIN (SELECT order_id, sum(line_total) AS line_sum, count(*) AS n
      FROM order_items GROUP BY order_id) li USING (order_id)
WHERE abs(li.line_sum - (o.subtotal - o.discount_total)) > 0.01 * li.n;

\echo '=== Check 4: every order has at least one line (expect 0) ==='
SELECT count(*) AS mismatches
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id);

\echo '=== Check 5: fulfilled orders have a captured payment for the grand total (expect 0) ==='
SELECT count(*) AS mismatches
FROM orders o
WHERE o.status IN ('paid', 'processing', 'shipped', 'delivered')
  AND NOT EXISTS (SELECT 1 FROM payments p
                  WHERE p.order_id = o.order_id
                    AND p.status = 'captured'
                    AND p.amount = o.grand_total);

\echo '=== Check 6: delivered orders have a shipment (expect 0) ==='
SELECT count(*) AS mismatches
FROM orders o
WHERE o.status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM shipments s WHERE s.order_id = o.order_id);

\echo '=== Demo: top 10 products by revenue ==='
SELECT p.name, sum(oi.line_total) AS revenue
FROM order_items oi
JOIN product_variants v USING (variant_id)
JOIN products p USING (product_id)
GROUP BY p.name
ORDER BY revenue DESC
LIMIT 10;

\echo '=== Demo: full-text product search hits the GIN index ==='
SET enable_seqscan = off;  -- table is tiny; force the planner to show the index
EXPLAIN (COSTS OFF)
SELECT name FROM products WHERE search @@ to_tsquery('english', 'product');
RESET enable_seqscan;
