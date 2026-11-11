-- Задание 1
BEGIN;

-- Очищаем таблицы, чтобы можно было запустить скрипт повторно
TRUNCATE TABLE
    deliveries, 
	payments, 
	reviews, 
	addresses,
    order_items, 
	cart_items, 
	orders, 
	carts,
    stock, 
	products, 
	categories, 
	sellers, 
	users
RESTART IDENTITY CASCADE;

-- users - 250 пользователей, первые 50 являются продавцами
INSERT INTO users (full_name, email, phone, role)
SELECT
    'Клиент ' || g,
    'client' || g || '@mail.com',
    '+7977' || lpad(g::text, 7, '0'),
    CASE
        WHEN g <= 50 THEN 'seller_owner'
        ELSE 'customer'
    END
FROM generate_series(1, 250) AS g;


-- sellers - магазины для продавцов
INSERT INTO sellers (user_id, store_name, description)
SELECT
    id,
    'Торговая площадка ' || id,
    'Магазин с товарами различных категорий №' || id
FROM users
WHERE role = 'seller_owner';


-- categories - 5 основных категорий
INSERT INTO categories (parent_id, name)
VALUES
    (NULL, 'Техника'),
    (NULL, 'Одежда'),
    (NULL, 'Книги'),
    (NULL, 'Товары для дома'),
    (NULL, 'Спортивные товары');

-- + 2 подкатегории к каждой основной категории
INSERT INTO categories (parent_id, name)
SELECT c.id, c.name || ' / Подкатегория ' || g
FROM categories c
CROSS JOIN generate_series(1, 2) AS g
WHERE c.parent_id IS NULL;


-- products - 1500 товаров
WITH seller_list AS (SELECT array_agg(id) AS ids, count(*) AS total FROM sellers),
     category_list AS (SELECT array_agg(id) AS ids, count(*) AS total FROM categories WHERE parent_id IS NOT NULL)
INSERT INTO products (seller_id, category_id, title, description, price, is_active)
SELECT
    seller_list.ids[floor(random() * seller_list.total)::int + 1],
    category_list.ids[floor(random() * category_list.total)::int + 1],
    'Товар ' || g,
    'Информация о товаре ' || g,
    (random() * 30000 + 500)::numeric(12,2),
    (random() > 0.15)
FROM generate_series(1, 1500) AS g, seller_list, category_list;


-- stock - остаток для каждого товара
INSERT INTO stock (product_id, quantity)
SELECT
    id,
    (random() * 150)::int
FROM products;


-- carts - корзины для 180 случайных пользователей
INSERT INTO carts (user_id)
SELECT id
FROM users
ORDER BY random()
LIMIT 180;


-- cart_items - до 4 товаров в каждой корзине
WITH product_list AS (SELECT array_agg(id) AS ids, count(*) AS total FROM products)
INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT c.id, product_list.ids[floor(random() * product_list.total)::int + 1], (floor(random() * 4) + 1)::int
FROM carts c
CROSS JOIN generate_series(1, 4) AS slot
CROSS JOIN product_list
ON CONFLICT (cart_id, product_id) DO NOTHING;


-- orders - 1200 заказов
WITH user_list AS (SELECT array_agg(id) AS ids, count(*) AS total FROM users)
INSERT INTO orders (user_id, status, created_at)
SELECT
    user_list.ids[floor(random() * user_list.total)::int + 1],
    (ARRAY['created', 'paid', 'sent', 'delivered', 'cancelled'])[floor(random() * 5 + 1)],
    now() - (random() * interval '180 days')
FROM generate_series(1, 1200) AS g, user_list;


-- order_items - до 3 случайных товаров в каждом заказе.
WITH product_list AS (SELECT array_agg(id) AS ids, array_agg(price) AS prices, count(*) AS total FROM products)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.id, product_list.ids[pick.idx], (floor(random() * 3) + 1)::int, product_list.prices[pick.idx]
FROM orders o
CROSS JOIN generate_series(1, 3) AS slot
CROSS JOIN product_list
CROSS JOIN LATERAL (
    SELECT floor(random() * product_list.total)::int + 1 AS idx
) AS pick
ON CONFLICT (order_id, product_id) DO NOTHING;

-- Обновляем общую стоимость заказов total_amount по позициям
UPDATE orders o
SET total_amount = COALESCE((
        SELECT SUM(oi.quantity * oi.unit_price)
        FROM order_items oi
        WHERE oi.order_id = o.id
    ),
    0
);


-- addresses - по одному адресу для каждого пользователя, у которого есть заказ
INSERT INTO addresses (user_id, city, street, house, apartment)
SELECT DISTINCT ON (o.user_id)
    o.user_id,
    (ARRAY['Москва', 'Казань', 'Самара', 'Тула', 'Краснодар'])[floor(random() * 5 + 1)],
    'ул. Центральная',
    (floor(random() * 100) + 1)::text,
    (floor(random() * 200) + 1)::text
FROM orders o
ORDER BY o.user_id;


-- payments - платежи для оплаченных заказов
INSERT INTO payments (order_id, amount, status, paid_at)
SELECT o.id, o.total_amount, 'succeeded', o.created_at + interval '1 hour'
FROM orders o
WHERE o.status IN ('paid', 'sent', 'delivered') AND o.total_amount > 0;


-- deliveries - доставки отправленных заказов
INSERT INTO deliveries (
    order_id, address_id, delivery_status, delivery_date
)
SELECT
    o.id,
    a.id,
    CASE
        WHEN o.status = 'delivered' THEN 'delivered'
        ELSE 'in_transit'
    END,
    o.created_at + interval '3 days'
FROM orders o
JOIN addresses a ON a.user_id = o.user_id
WHERE o.status IN ('sent', 'delivered');


-- reviews - отзывы на приобретённые товары
INSERT INTO reviews (user_id, product_id, score, comment, created_at)
SELECT DISTINCT ON (o.user_id, oi.product_id)
    o.user_id,
    oi.product_id,
    (floor(random() * 5) + 1)::int,
    'Отзыв ' || oi.product_id,
    o.created_at + interval '7 days'
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'delivered'
ORDER BY o.user_id, oi.product_id, random()
ON CONFLICT (user_id, product_id) DO NOTHING;


COMMIT;


-- Проверка количества записей во всех таблицах
SELECT 'users' AS table_name, count(*) AS total FROM users
UNION ALL SELECT 'sellers', count(*) FROM sellers
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'stock', count(*) FROM stock
UNION ALL SELECT 'carts', count(*) FROM carts
UNION ALL SELECT 'cart_items', count(*) FROM cart_items
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'addresses', count(*) FROM addresses
UNION ALL SELECT 'deliveries', count(*) FROM deliveries
ORDER BY table_name;


-- Задание 2
SELECT DISTINCT
    category_id AS "Код категории",
	price AS "Цена (руб.)",
    is_active AS "Активность товара"
FROM products
ORDER BY category_id, is_active;


-- Задание 3
SELECT id, title AS "Наименование", description AS "Описание", price AS "Цена (руб.)"
FROM products
WHERE is_active = TRUE AND (price < 5000 OR price > 30000)
ORDER BY price;

-- Задание 4
SELECT id, title, category_id, price, description
FROM products
WHERE
    category_id IN (1, 3, 5, 7, 9)
    AND price BETWEEN 1000 AND 25000
    AND description IS NOT NULL
    AND title NOT ILIKE 'Товар 12%'
ORDER BY id;


-- Задание 5
SELECT p.category_id, c.name AS category_name, p.title, p.price
FROM products AS p
JOIN categories AS c ON p.category_id = c.id
ORDER BY p.category_id ASC, p.price DESC;


-- Задание 6
SELECT id, title, price
FROM products
ORDER BY id ASC
LIMIT 5 OFFSET 5;