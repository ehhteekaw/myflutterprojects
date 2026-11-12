// lib/schema.dart

const String createTablesSQL = '''
  CREATE TABLE IF NOT EXISTS shops (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_name TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_id INTEGER, -- NULL for SuperAdmin
    username TEXT UNIQUE NOT NULL,
    pin_code TEXT NOT NULL,
    role TEXT NOT NULL, -- 'SuperAdmin', 'ShopAdmin', 'Cashier'
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (shop_id) REFERENCES shops(id)
  );

  CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    card_number TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    customer_type TEXT NOT NULL, -- 'Student', 'Staff', 'Teacher'
    balance REAL DEFAULT 0.0
  );

  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS subcategories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER,
    name TEXT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
  );


  CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    sku TEXT,
    price REAL NOT NULL,
    shop_id INTEGER,
    image_url TEXT,
    subcategory_id INTEGER,
    FOREIGN KEY (shop_id) REFERENCES shops(id),
    FOREIGN KEY (subcategory_id) REFERENCES subcategories(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_id INTEGER,
    student_card_id TEXT, -- Uses the card number directly
    total_amount REAL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shop_id) REFERENCES shops(id)
  );

  CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    price REAL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
  );
''';

const String insertDummyDataSQL = '''
  INSERT INTO shops (shop_name) VALUES ('Danny');

  INSERT INTO users (shop_id, username, pin_code, role) VALUES 
    (NULL, 'superadmin', '1234', 'SuperAdmin'),
    (1, 'shopadmin', '1111', 'ShopAdmin'),
    (1, 'cashier1', '1111', 'Cashier');

  INSERT INTO customers (card_number, name, customer_type, balance) VALUES 
    ('STU-1001', 'Aung Aung', 'Student', 50.00),
    ('STF-2001', 'Daw Mya', 'Teacher', 100.00),
    ('STF-3001', 'Ko Ko', 'Staff', 20.50);

  INSERT INTO categories (name) VALUES ('Drinks'), ('Snacks');
  
  INSERT INTO subcategories (category_id, name) VALUES 
    (1, 'Cold Drinks'), 
    (2, 'Chips');

  INSERT INTO products (name, sku, price, shop_id, image_url, subcategory_id) VALUES 
    ('Coke', 'COKE-01', 1.50, 1, 'https://via.placeholder.com/150', 1),
    ('Pepsi', 'PEPSI-01', 1.50, 1, 'https://via.placeholder.com/150', 1),
    ('Chips', 'CHIPS-01', 1.00, 1, 'https://via.placeholder.com/150', 2);
''';