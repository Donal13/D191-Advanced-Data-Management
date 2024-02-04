-- Section B
CREATE OR REPLACE FUNCTION format_dollar(amount NUMERIC)
RETURNS TEXT AS $$
BEGIN
    RETURN '$' || TO_CHAR(amount, 'FM999,999,999.00');
END;
$$ LANGUAGE plpgsql;

-- verification
SELECT format_dollar(123456.78);

-- Section C
DROP TABLE IF EXISTS detailed_movie_revenue;
CREATE TABLE detailed_movie_revenue (
    film_id INT PRIMARY KEY,
    title VARCHAR(255),
    genre VARCHAR(255),
    total_revenue TEXT
);

DROP TABLE IF EXISTS summary_genre_revenue;
CREATE TABLE summary_genre_revenue (
    genre VARCHAR(255) PRIMARY KEY,
    top_ten_movies TEXT
);

-- verification
SELECT * FROM detailed_movie_revenue;

SELECT * FROM summary_genre_revenue;

-- Section D
TRUNCATE TABLE detailed_movie_revenue;

WITH RankedMovies AS (
    SELECT
        f.film_id,
        f.title,
        c.name AS genre,
        format_dollar(SUM(p.amount)) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY SUM(p.amount) DESC) as rank
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY f.film_id, f.title, c.name
)

INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue)
SELECT film_id, title, genre, total_revenue
FROM RankedMovies
WHERE rank <= 10;

-- verification
SELECT * FROM detailed_movie_revenue LIMIT 100;

-- Section E
CREATE OR REPLACE FUNCTION update_summary_table()
RETURNS TRIGGER AS $$
BEGIN
    -- Clear the summary table
    DELETE FROM summary_genre_revenue;

    -- Insert new summary data
    INSERT INTO summary_genre_revenue (genre, top_ten_movies)
    SELECT
        genre,
        STRING_AGG(title, ', ') AS top_ten_movies
    FROM
        detailed_movie_revenue
    GROUP BY
        genre;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_summary
AFTER INSERT OR UPDATE OR DELETE ON detailed_movie_revenue
FOR EACH ROW EXECUTE FUNCTION update_summary_table();

-- verification
INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue) VALUES (999, 'Test Movie', 'Test Genre', 2024, '$1000.00');

SELECT * FROM summary_genre_revenue;

-- Section F
CREATE OR REPLACE PROCEDURE refresh_movie_data()
LANGUAGE plpgsql AS $$
BEGIN
    -- Clear the contents of the detailed and summary tables
    TRUNCATE TABLE detailed_movie_revenue;
    TRUNCATE TABLE summary_genre_revenue;

    -- Perform raw data extraction (as outlined in part D)
    INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue)
    SELECT
        f.film_id,
        f.title,
        c.name AS genre,
        format_dollar(SUM(p.amount)) AS total_revenue
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN payment p ON f.film_id = p.film_id
    GROUP BY f.film_id, f.title, c.name
    ORDER BY c.name, SUM(p.amount) DESC
    LIMIT 10;

    -- The trigger will automatically update the summary table
END;
$$;

-- verification
CALL refresh_movie_data();

SELECT * FROM detailed_movie_revenue LIMIT 5;

SELECT * FROM summary_genre_revenue LIMIT 5;
_________________________________________________________________________________________

-- Section B: Function for Formatting Dollar Amounts
CREATE OR REPLACE FUNCTION format_dollar(amount NUMERIC)
RETURNS TEXT AS $$
BEGIN
    -- Formats numeric amount to a dollar string format. "FM" Fill Mode used to eliminate white space.
    RETURN '$' || TO_CHAR(amount, 'FM999,999,999.00');
END;
$$ LANGUAGE plpgsql; 

-- Test the format_dollar function
SELECT format_dollar(123456.78);

-- Section C: Table Creation
DROP TABLE IF EXISTS detailed_movie_revenue;
CREATE TABLE detailed_movie_revenue (
    film_id INT PRIMARY KEY,
    title VARCHAR(255),
    genre VARCHAR(255),
    total_revenue TEXT
);

DROP TABLE IF EXISTS summary_genre_revenue;
CREATE TABLE summary_genre_revenue (
    genre VARCHAR(255) PRIMARY KEY,
    top_ten_movies TEXT
);

-- Verify tables are created.
SELECT * FROM detailed_movie_revenue;

SELECT * FROM summary_genre_revenue;

-- Section D: Data Insertion with Ranking
-- Clear existing data from detailed_movie_revenue for a fresh start.
TRUNCATE TABLE detailed_movie_revenue;

-- Rank and insert top 10 movies by revenue in each genre
WITH RankedMovies AS (
    SELECT
        f.film_id,
        f.title,
        c.name AS genre,
        format_dollar(SUM(p.amount)) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY SUM(p.amount) DESC) as rank
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rental r ON i.inventory_id = r.inventory_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY f.film_id, f.title, c.name
)

INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue)
SELECT film_id, title, genre, total_revenue
FROM RankedMovies
WHERE rank <= 10;

-- Verification
SELECT * FROM detailed_movie_revenue LIMIT 160;

-- Section E: Trigger Creation
CREATE OR REPLACE FUNCTION update_summary_table()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM summary_genre_revenue;

    INSERT INTO summary_genre_revenue (genre, top_ten_movies)
    SELECT
        genre,
        STRING_AGG(title, ', ') AS top_ten_movies
    FROM detailed_movie_revenue
    GROUP BY genre;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Defines the trigger to call the above function
CREATE TRIGGER trigger_update_summary
AFTER INSERT OR UPDATE OR DELETE ON detailed_movie_revenue
FOR EACH ROW EXECUTE FUNCTION update_summary_table();

-- Verification
INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue) VALUES (999, 'Test Movie', 'Test Genre', '$1000.00');

SELECT * FROM summary_genre_revenue;

-- Section F
CREATE OR REPLACE PROCEDURE refresh_movie_data()
LANGUAGE plpgsql AS $$
BEGIN
    -- Clear the contents of the detailed and summary tables
    TRUNCATE TABLE detailed_movie_revenue;
    TRUNCATE TABLE summary_genre_revenue;

    -- Insert the top 10 ranked movies from each genre
    INSERT INTO detailed_movie_revenue (film_id, title, genre, total_revenue)
    SELECT 
        film_id, 
        title, 
        genre, 
        total_revenue
    FROM (
        SELECT
            f.film_id,
            f.title,
            c.name AS genre,
            format_dollar(SUM(p.amount)) AS total_revenue,
            ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY SUM(p.amount) DESC) as rank
        FROM film f
        JOIN film_category fc ON f.film_id = fc.film_id
        JOIN category c ON fc.category_id = c.category_id
        JOIN inventory i ON f.film_id = i.film_id
        JOIN rental r ON i.inventory_id = r.inventory_id
        JOIN payment p ON r.rental_id = p.rental_id
        GROUP BY f.film_id, f.title, c.name
    ) AS RankedMovies
    WHERE rank <= 10;

    DELETE FROM summary_genre_revenue;
    INSERT INTO summary_genre_revenue (genre, top_ten_movies)
    SELECT
        genre,
        STRING_AGG(title, ', ') AS top_ten_movies
    FROM detailed_movie_revenue
    GROUP BY genre;
END;
$$;

-- Final verification
CALL refresh_movie_data();

SELECT * FROM detailed_movie_revenue LIMIT 160;
SELECT * FROM summary_genre_revenue LIMIT 17;
