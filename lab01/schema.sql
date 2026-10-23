BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'customer'
        CHECK (role IN ('customer', 'seller_owner', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sellers (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE
        REFERENCES users(id) ON DELETE CASCADE,
    store_name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categories (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT
        REFERENCES categories(id) ON DELETE RESTRICT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS products (
    id BIGINT PRIMARY KEY,
    seller_id BIGINT NOT NULL
        REFERENCES sellers(id) ON DELETE RESTRICT,
    category_id BIGINT NOT NULL
        REFERENCES categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    description TEXT,
    price NUMERIC NOT NULL CHECK (price > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stock (
    product_id BIGINT PRIMARY KEY
        REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0
        CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS carts (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE
        REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cart_items (
    cart_id BIGINT NOT NULL
        REFERENCES carts(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL
        REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS orders (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'created'
        CHECK (status IN ('created', 'paid', 'sent', 'delivered', 'cancelled')),
    total_amount NUMERIC NOT NULL DEFAULT 0
        CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id BIGINT NOT NULL
        REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL
        REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS payments (
    id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE
        REFERENCES orders(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    paid_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS addresses (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    city TEXT NOT NULL,
    street TEXT NOT NULL,
    house TEXT NOT NULL,
    apartment TEXT
);

CREATE TABLE IF NOT EXISTS deliveries (
    id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE
        REFERENCES orders(id) ON DELETE CASCADE,
    address_id BIGINT NOT NULL
        REFERENCES addresses(id) ON DELETE RESTRICT,
    delivery_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (delivery_status IN ('pending', 'in_transit', 'delivered', 'returned')),
    delivery_date TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS reviews (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL
        REFERENCES products(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, product_id)
);

END;
