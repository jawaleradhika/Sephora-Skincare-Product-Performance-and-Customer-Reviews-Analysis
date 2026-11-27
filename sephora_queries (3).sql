-- Sephora Skincare: 5 deep-analysis SQL queries (SQLite syntax)
-- Tables: products (cleaned product_info, Skincare only), reviews (cleaned reviews joined with product fields)
-- Each query has a Pandas twin in sephora_analysis.py; the script compares both outputs.

-- name: q1_brand_performance
-- Brands with >= 5 products: size, price, rating and review volume
CREATE TABLE reviews_all AS
SELECT * FROM reviews_0_250
UNION ALL
SELECT * FROM reviews_250_500_final
UNION ALL
SELECT * FROM reviews_500_750_final
UNION ALL
SELECT * FROM reviews_750_1250
UNION ALL
SELECT * FROM reviews_1250_end;


SELECT
    brand_name,
    COUNT(DISTINCT product_id)        AS product_count,
    ROUND(AVG(price_usd), 4)          AS avg_price,
    ROUND(AVG(rating), 4)     AS avg_rating,
    SUM(reviews)        AS total_reviews
FROM product_info
GROUP BY brand_name
HAVING COUNT(DISTINCT product_id) >= 5
ORDER BY avg_rating DESC;

-- name: q2_price_band_vs_rating
-- Does a higher price mean a higher rating? Fixed price bands
SELECT
    CASE
        WHEN price_usd < 25  THEN '1: under 25'
        WHEN price_usd < 50  THEN '2: 25-50'
        WHEN price_usd < 100 THEN '3: 50-100'
        ELSE                      '4: 100+'
    END                               AS price_band,
    COUNT(*)                          AS product_count,
    ROUND(AVG(rating), 4)     AS avg_rating,
    ROUND(AVG(loves_count), 2)        AS avg_loves,
    SUM(reviews)        AS total_reviews
FROM product_info
GROUP BY price_band
ORDER BY price_band;

-- name: q3_category_satisfaction
-- Customer-level satisfaction per secondary category (review table JOIN products)
SELECT
    p.secondary_category              AS secondary_category,
    COUNT(*)                          AS review_count,
    ROUND(AVG(r.review_rating), 4)    AS avg_review_rating,
    ROUND(AVG(r.is_recommended), 4)   AS recommend_rate
FROM reviews r
JOIN products p ON p.product_id = r.product_id
GROUP BY p.secondary_category
ORDER BY recommend_rate DESC;

-- name: q4_top3_products_per_category
-- Window function: top 3 products per category (min 100 reviews to avoid tiny-sample bias)
WITH ranked AS (
    SELECT
        secondary_category,
        product_id,
        product_name,
        brand_name,
        rating,
        reviews,
        ROW_NUMBER() OVER (
            PARTITION BY secondary_category
            ORDER BY rating DESC,reviews DESC, product_id
        ) AS rank_in_category
    FROM product_info
    WHERE reviews>= 100
)
SELECT *
FROM ranked
WHERE rank_in_category <= 3
ORDER BY secondary_category, rank_in_category;

-- name: q5_skin_type_segments
-- Which skin types are happiest? (reviews only)
SELECT
    COALESCE(NULLIF(skin_type, ''), 'Unknown')   AS skin_type,
    COUNT(*)                                      AS review_count,
    ROUND(AVG(rating), 4)                         AS avg_review_rating,
    ROUND(AVG(is_recommended), 4)                 AS recommend_rate,
    ROUND(AVG(CHAR_LENGTH(review_text)), 2)       AS avg_review_length
FROM reviews_all
GROUP BY COALESCE(NULLIF(skin_type, ''), 'Unknown')
ORDER BY review_count DESC;

