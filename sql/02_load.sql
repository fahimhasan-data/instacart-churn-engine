\copy raw.aisles FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\aisles.csv' WITH (FORMAT csv, HEADER true)

\copy raw.departments FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\departments.csv' WITH (FORMAT csv, HEADER true)

\copy raw.products FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\products.csv' WITH (FORMAT csv, HEADER true)

\copy raw.orders FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\orders.csv' WITH (FORMAT csv, HEADER true)

\copy raw.order_products_train FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\order_products__train.csv' WITH (FORMAT csv, HEADER true)

\copy raw.order_products_prior FROM 'C:\Users\fahim\Downloads\Instacart Market Basket Analysis\order_products__prior.csv' WITH (FORMAT csv, HEADER true)

--Last two is too large. one take 25 sec and last one take 40 to 45 sec. I did it on psql shell. It was a great adventure by the way!!