--Administrator Procedures

--1.1
CREATE VIEW borrows_by_school AS
SELECT st.school_name, COUNT(b.username) AS total_borrows
FROM students_teachers AS st
JOIN borrow AS b ON st.username = b.username
WHERE b.status IN ('lended', 'returned', 'due return')
GROUP BY st.school_name;

CREATE VIEW borrows_by_school_date AS
SELECT st.school_name, DATE_FORMAT(b.borrow_date, '%Y-%m') AS date, COUNT(b.username) AS total_borrows
FROM students_teachers st
JOIN borrow b ON st.username = b.username
WHERE b.status IN ('lended', 'returned', 'due return')
GROUP BY st.school_name, date;

DELIMITER //

CREATE PROCEDURE GetBorrowsByDate(IN search_date VARCHAR(7))
BEGIN
  SELECT st.school_name AS 'School Name', COUNT(b.username) AS 'Total Borrows'
  FROM students_teachers st
  JOIN borrow b ON st.username = b.username
  WHERE b.status IN ('lended', 'returned', 'due return')
    AND DATE_FORMAT(b.borrow_date, '%Y-%m') = search_date
  GROUP BY st.school_name;
END //

DELIMITER ;

--1.2
CREATE VIEW category_teacher_authors AS
SELECT c.category_name, st.username AS teacher_username, a.author_name
FROM categories c
JOIN book_categories bc ON c.category_id = bc.category_id
JOIN books b ON bc.ISBN = b.ISBN
JOIN book_authors ba ON b.ISBN = ba.ISBN
JOIN authors a ON ba.author_id = a.author_id
JOIN borrow bor ON b.ISBN = bor.ISBN
JOIN students_teachers st ON bor.username = st.username
WHERE bor.borrow_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
AND st.role = 'teacher';

DELIMITER //
CREATE PROCEDURE GetCategoryTeacherAuthors(IN input_category VARCHAR(255))
BEGIN
  SELECT category_name AS 'Category', teacher_username AS 'Teacher', GROUP_CONCAT(author_name) AS 'Author(s)'
  FROM category_teacher_authors
  WHERE category_name = input_category
  GROUP BY category_name, teacher_username;
END //
DELIMITER ;

--1.3
CREATE VIEW teacher_borrows AS
SELECT u.first_name, u.last_name, COUNT(*) AS num_borrows
FROM users u
JOIN students_teachers st ON u.username = st.username
JOIN borrow b ON u.username = b.username
WHERE u.birth_date > DATE_SUB(CURDATE(), INTERVAL 40 YEAR)
  AND st.role = 'teacher'
GROUP BY u.first_name, u.last_name
ORDER BY num_borrows DESC;

DELIMITER //
CREATE PROCEDURE GetYoungTeachers()
BEGIN
  SELECT first_name AS 'Teacher First Name', last_name AS 'Teacher Last Name', num_borrows AS 'Number of borrows'
  FROM teacher_borrows;
END //
DELIMITER ;

--1.4
CREATE VIEW available_authors AS
SELECT DISTINCT a.author_id, a.author_name
FROM authors a
LEFT JOIN book_authors ba ON a.author_id = ba.author_id
LEFT JOIN borrow bor ON ba.ISBN = bor.ISBN
WHERE bor.ISBN IS NULL;

DELIMITER //
CREATE PROCEDURE GetAvailableAuthors()
BEGIN
  SELECT author_id AS 'Author ID', author_name AS 'Author'
  FROM available_authors;
END //
DELIMITER ;

--1.5

CREATE VIEW managers_with_same_borrows AS
SELECT su.lib_manager_fn AS first_name, su.lib_manager_ln AS last_name, COUNT(*) AS borrow_count
FROM borrow b
JOIN book_school_unit bsu ON b.ISBN = bsu.ISBN
JOIN school_unit su ON bsu.school_name = su.school_name
WHERE b.status IN ('lended', 'due return', 'returned')
GROUP BY su.lib_manager_fn, su.lib_manager_ln
HAVING COUNT(*) > 20;

CREATE VIEW borrows_per_manager AS
SELECT su.lib_manager_fn AS first_name, su.lib_manager_ln AS last_name, COUNT(*) AS borrow_count
FROM borrow b
JOIN book_school_unit bsu ON b.ISBN = bsu.ISBN
JOIN school_unit su ON bsu.school_name = su.school_name
WHERE b.status IN ('lended', 'due return', 'returned')
GROUP BY su.lib_manager_fn, su.lib_manager_ln;

DELIMITER //
CREATE PROCEDURE GetManagerSameBorrows()
BEGIN
  SELECT first_name AS 'Manager First Name', last_name AS 'Manager Last Name', borrow_count AS 'Borrow Count'
  FROM managers_with_same_borrows;
END //
DELIMITER ;

--1.6
CREATE VIEW top_borrowed_category_pairs AS
SELECT bc1.category_id AS category1_id, c1.category_name AS category1_name,
       bc2.category_id AS category2_id, c2.category_name AS category2_name,
       COUNT(*) AS borrow_count
FROM book_categories bc1
JOIN book_categories bc2 ON bc1.ISBN = bc2.ISBN AND bc1.category_id < bc2.category_id
JOIN categories c1 ON bc1.category_id = c1.category_id
JOIN categories c2 ON bc2.category_id = c2.category_id
JOIN borrow b ON bc1.ISBN = b.ISBN
WHERE b.status IN ('lended', 'returned', 'due return')  -- Filter based on borrow statuses
GROUP BY bc1.category_id, bc2.category_id
ORDER BY borrow_count DESC
LIMIT 3;

DELIMITER //
CREATE PROCEDURE GetTopBorrowedCategory()
BEGIN
  SELECT category1_id AS 'First Category ID', category1_name AS 'First Category Name', category2_id AS 'Second Category ID', category2_name AS 'Second Category Name'
  FROM top_borrowed_category_pairs;
END //
DELIMITER ;

--1.7
CREATE VIEW less_than_five AS
SELECT a.author_name
FROM authors a
JOIN book_authors ba ON a.author_id = ba.author_id
GROUP BY a.author_id, a.author_name
HAVING (SELECT COUNT(ba2.ISBN) FROM book_authors ba2 WHERE ba2.author_id = a.author_id) <= (SELECT COUNT(ba3.ISBN) - 1 FROM book_authors ba3 GROUP BY ba3.author_id ORDER BY COUNT(ba3.ISBN) DESC LIMIT 1);

DELIMITER //
CREATE PROCEDURE GetLessThanFive()
BEGIN
  SELECT author_name AS 'Author'
  FROM less_than_five;
END //
DELIMITER ;

--Administrator Accept Manager

DELIMITER //

CREATE PROCEDURE UpdateUserStatusAndInsertManager(
  IN p_username VARCHAR(30)
)
BEGIN
  DECLARE v_school_name VARCHAR(40);
  DECLARE v_previous_status ENUM('pending manager');

  SELECT school_name, status INTO v_school_name, v_previous_status
  FROM users
  WHERE username = p_username;

  IF v_previous_status = 'pending manager' THEN
    UPDATE users
    SET status = 'accepted'
    WHERE username = p_username;

    INSERT INTO manager (username, school_name)
    VALUES (p_username, v_school_name);
  END IF;
END //

DELIMITER ;

--Administrator Deny Manager

DELIMITER //

CREATE PROCEDURE UpdateUserStatusToDeniedManager(
  IN p_username VARCHAR(30)
)
BEGIN
  DECLARE v_previous_status ENUM('pending manager');

  SELECT status INTO v_previous_status
  FROM users
  WHERE username = p_username;

  IF v_previous_status = 'pending manager' THEN
    UPDATE users
    SET status = 'denied'
    WHERE username = p_username;
  END IF;
END //

DELIMITER ;

--Administrator Get Pending Managers

DELIMITER //

CREATE PROCEDURE GetPendingManagers()
BEGIN
  SELECT username, first_name, last_name, birth_date, school_name
  FROM users
  WHERE status = 'pending manager';
END //

DELIMITER ;

--Admin Get Accepted Users (By School)

DELIMITER //

CREATE PROCEDURE GetAcceptedUsers(
  IN p_school_name VARCHAR(50),
  IN p_username VARCHAR(50)
)
BEGIN
    IF p_school_name IS NOT NULL THEN
        SELECT u.username, u.first_name, u.last_name, u.birth_date, u.school_name
        FROM users u
        INNER JOIN students_teachers st ON u.username = st.username
        WHERE u.school_name = p_school_name AND u.status = 'accepted'
        AND (p_username IS NULL OR u.username = p_username);
    ELSE
        SELECT u.username, u.first_name, u.last_name, u.birth_date, u.school_name
        FROM users u
        WHERE u.status = 'accepted'
        AND (p_username IS NULL OR u.username = p_username);
    END IF;
END //

DELIMITER ;

--Admin Insert School

DELIMITER //

CREATE PROCEDURE InsertSchool(
  IN p_school_name VARCHAR(50),
  IN p_principal VARCHAR(50),
  IN p_lib_manager_fn VARCHAR(20),
  IN p_lib_manager_ln VARCHAR(20),
  IN p_city VARCHAR(30),
  IN p_postal_code INT,
  IN p_email VARCHAR(50),
  IN p_phone_num BIGINT
)
BEGIN
  INSERT INTO school_unit (school_name, principal, lib_manager_fn, lib_manager_ln, city, postal_code, email, phone_num)
  VALUES (p_school_name, p_principal, p_lib_manager_fn, p_lib_manager_ln, p_city, p_postal_code, p_email, p_phone_num);
END //

DELIMITER ;

--Admin Edit School

DELIMITER //

CREATE PROCEDURE UpdateSchool(
  IN p_school_name VARCHAR(50),
  IN p_principal VARCHAR(50),
  IN p_lib_manager_fn VARCHAR(20),
  IN p_lib_manager_ln VARCHAR(20),
  IN p_city VARCHAR(30),
  IN p_postal_code INT,
  IN p_email VARCHAR(50),
  IN p_phone_num BIGINT
)
BEGIN
  UPDATE school_unit
  SET principal = IFNULL(p_principal, principal),
      lib_manager_fn = IFNULL(p_lib_manager_fn, lib_manager_fn),
      lib_manager_ln = IFNULL(p_lib_manager_ln, lib_manager_ln),
      city = IFNULL(p_city, city),
      postal_code = IFNULL(p_postal_code, postal_code),
      email = IFNULL(p_email, email),
      phone_num = IFNULL(p_phone_num, phone_num)
  WHERE school_name = p_school_name;
END //

DELIMITER ;

--Admin get schools

DELIMITER //

CREATE PROCEDURE GetSchools(IN p_school_name VARCHAR(50))
BEGIN
  IF p_school_name IS NOT NULL THEN
    SELECT *
    FROM school_unit
    WHERE school_name = p_school_name;
  ELSE
    SELECT *
    FROM school_unit;
  END IF;
END //

DELIMITER ;




--Manager Procedures

--2.1

DELIMITER //

CREATE PROCEDURE SearchBooksBySchool(
  IN school_name VARCHAR(255),
  IN search_title VARCHAR(255),
  IN search_category VARCHAR(255),
  IN search_author_name VARCHAR(255),
  IN search_available_copies INT 
)
BEGIN
  SET SESSION sql_mode = '';

  SELECT
    b.image AS 'Image',
    b.title AS 'Title',
    (
      SELECT GROUP_CONCAT(DISTINCT a.author_name ORDER BY a.author_name SEPARATOR ', ')
      FROM authors a
      JOIN book_authors ba ON a.author_id = ba.author_id
      WHERE ba.ISBN = b.ISBN
    ) AS 'Authors',
    b.ISBN
  FROM
    books b
    JOIN book_categories bc ON b.ISBN = bc.ISBN
    JOIN categories c ON bc.category_id = c.category_id
    JOIN book_school_unit bs ON b.ISBN = bs.ISBN
  WHERE
    (bs.school_name = school_name OR school_name = '' OR school_name IS NULL)
    AND (b.title LIKE CONCAT('%', search_title, '%') OR search_title = '' OR search_title IS NULL)
    AND (c.category_name LIKE CONCAT('%', search_category, '%') OR search_category = '' OR search_category IS NULL)
    AND (bs.available_copies >= search_available_copies OR search_available_copies IS NULL)
    AND (
      search_author_name = '' OR search_author_name IS NULL
      OR EXISTS (
        SELECT 1
        FROM authors a
        JOIN book_authors ba ON a.author_id = ba.author_id
        WHERE ba.ISBN = b.ISBN AND a.author_name = search_author_name
      )
    )
  GROUP BY
    b.image, b.title;
END //

DELIMITER ;

--Manager AND user select book

DELIMITER //

CREATE PROCEDURE SelectBookByISBN(
  IN book_ISBN BIGINT
)
BEGIN
  SET SESSION sql_mode = '';

  SELECT
    b.ISBN,
    b.image,
    b.title,
    GROUP_CONCAT(DISTINCT a.author_name ORDER BY a.author_name SEPARATOR ', ') AS 'Authors',
    b.languages,
    GROUP_CONCAT(DISTINCT c.category_name ORDER BY c.category_name SEPARATOR ', ') AS 'Categories',
    b.keywords,
    b.publisher,
    b.page_num,
    b.summary,
    bs.available_copies
  FROM
    books b
    JOIN book_authors ba ON b.ISBN = ba.ISBN
    JOIN authors a ON ba.author_id = a.author_id
    JOIN book_categories bc ON b.ISBN = bc.ISBN
    JOIN categories c ON bc.category_id = c.category_id
    JOIN book_school_unit bs ON b.ISBN = bs.ISBN
  WHERE
    b.ISBN = book_ISBN;
END //

DELIMITER ;
--2.2
DELIMITER //

CREATE PROCEDURE GetUsersWithUnreturnedBooks(IN school_unit VARCHAR(255), IN first_name VARCHAR(255), IN last_name VARCHAR(255), IN overdue_days INT)
BEGIN
  SELECT
    bor.username AS 'User',
    b.title AS 'Book Title',
    bor.borrow_date AS 'Borrow Date',
    bor.return_date AS 'Return Date',
    bor.borrow_id AS 'Borrow ID',
    DATEDIFF(CURDATE(), bor.return_date) AS 'Overdue Days'
  FROM
    borrow bor
    JOIN books b ON bor.ISBN = b.ISBN
    JOIN book_school_unit bsu ON b.ISBN = bsu.ISBN
    JOIN users u ON bor.username = u.username
  WHERE
    bor.status = 'due return'
    AND (u.first_name = first_name OR first_name IS NULL)
    AND (u.last_name = last_name OR last_name IS NULL)
    AND (bsu.school_name = school_unit OR school_unit IS NULL)
    AND (DATEDIFF(CURDATE(), bor.return_date) = overdue_days OR overdue_days IS NULL)
  ORDER BY
    bor.return_date;
END //

DELIMITER ;

  
--2.3

CREATE VIEW CategoryAverageRatings AS
SELECT c.category_name, AVG(br.rating) AS average_rating
FROM categories c
LEFT JOIN book_categories b ON c.category_id = b.category_id
LEFT JOIN book_reviews br ON b.ISBN = br.ISBN
GROUP BY c.category_id, c.category_name;

DELIMITER //
CREATE PROCEDURE GetCategoryAverageRatings(IN search_category VARCHAR(255))
BEGIN
  IF search_category IS NULL THEN
    SELECT * FROM CategoryAverageRatings;
  ELSE
    SELECT * FROM CategoryAverageRatings WHERE category_name = search_category;
  END IF;
END //
DELIMITER ;

CREATE VIEW UserAverageRatings AS
SELECT username, AVG(rating) AS average_rating
FROM book_reviews
GROUP BY username;

DELIMITER //
CREATE PROCEDURE GetUserAverageRatings(IN search_username VARCHAR(255))
BEGIN
  IF search_username IS NULL THEN
    SELECT * FROM UserAverageRatings;
  ELSE
    SELECT * FROM UserAverageRatings WHERE username = search_username;
  END IF;
END //
DELIMITER ;

--Manager Borrow Approval

CREATE VIEW pending_borrows AS
SELECT *
FROM borrow
WHERE status = 'pending';

CREATE VIEW pending_reserves AS
SELECT *
FROM borrow
WHERE status = 'in queue';

DELIMITER //

CREATE PROCEDURE SelectNonPendingBorrows(IN school_name VARCHAR(255))
BEGIN
  SELECT
    b.*
  FROM
    borrow b
    JOIN students_teachers st ON b.username = st.username
  WHERE
    b.status != 'pending'
    AND st.school_name = school_name;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ApproveBorrowRequest(IN p_borrow_id INT)
BEGIN
    DECLARE v_username VARCHAR(30);
    DECLARE v_school_name VARCHAR(50);
    DECLARE v_available_copies INT;
    DECLARE v_ISBN BIGINT;
    
    -- Get the username, school_name, and ISBN for the given borrow_id
    SELECT borrow.username, students_teachers.school_name, borrow.ISBN INTO v_username, v_school_name, v_ISBN
    FROM borrow
    INNER JOIN students_teachers ON borrow.username = students_teachers.username
    WHERE borrow_id = p_borrow_id;
    
    -- Get the available_copies for the specific school and book
    SELECT available_copies INTO v_available_copies
    FROM book_school_unit
    WHERE ISBN = v_ISBN
    AND school_name = v_school_name;
    
    IF v_available_copies > 0 THEN
        -- Decrease available_copies by 1
        UPDATE book_school_unit
        SET available_copies = available_copies - 1
        WHERE ISBN = v_ISBN
        AND school_name = v_school_name;
        
        -- Change status to 'reserved' and set reserve_date to the current date
        UPDATE borrow
        SET status = 'reserved', reserve_date = CURDATE()
        WHERE borrow_id = p_borrow_id;
    ELSE
        -- Change status to 'in queue'
        UPDATE borrow
        SET status = 'in queue'
        WHERE borrow_id = p_borrow_id;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ChangeBorrowStatusToLended(IN p_borrow_id INT)
BEGIN
    UPDATE borrow
    SET status = 'lended', borrow_date = CURDATE(), return_date = DATE_ADD(CURDATE(), INTERVAL 1 WEEK)
    WHERE borrow_id = p_borrow_id
    AND status = 'reserved';
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ChangeBorrowStatusToReturned(IN p_borrow_id INT)
BEGIN
    UPDATE borrow
    SET status = 'returned'
    WHERE borrow_id = p_borrow_id
    AND (status = 'lended' OR status = 'due return');
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ChangeBorrowStatusToDueReturn(IN p_borrow_id INT)
BEGIN
    UPDATE borrow
    SET status = 'due return'
    WHERE borrow_id = p_borrow_id
    AND (status = 'lended');
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE ShowPendingBorrows(IN p_school_name VARCHAR(50))
BEGIN
    SELECT b.status, b.ISBN, b.username, b.borrow_id, b.date, st.role AS 'Account Type', st.school_name AS 'School Name',
    	(SELECT COUNT(*) FROM borrow WHERE username = st.username AND status IN ('reserved', 'lended', 'due return')) AS 'Borrow Count',
	(SELECT MAX(CASE WHEN status = 'due return' THEN 'Yes' ELSE 'Νο' END) FROM borrow WHERE username = st.username) AS 'Due Return Status'
    FROM pending_borrows AS b
    INNER JOIN students_teachers AS st ON b.username = st.username
    WHERE st.school_name = p_school_name;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE DenyBorrowRequest(IN p_borrow_id INT)
BEGIN
    UPDATE borrow SET status = 'denied' WHERE borrow_id = p_borrow_id;
END //

DELIMITER ;

--Manager accept user

DELIMITER //

CREATE PROCEDURE UpdateUserStatusAndInsert(
  IN p_username VARCHAR(30),
  IN p_role VARCHAR(10)
)
BEGIN
  DECLARE v_school_name VARCHAR(40);
  DECLARE v_previous_status ENUM('pending student', 'pending teacher');

  SELECT school_name, status INTO v_school_name, v_previous_status
  FROM users
  WHERE username = p_username;

  IF v_previous_status = 'pending student' OR v_previous_status = 'pending teacher' THEN
    UPDATE users
    SET status = 'accepted'
    WHERE username = p_username;

    INSERT INTO students_teachers (username, role, school_name)
    VALUES (p_username, p_role, v_school_name);
  END IF;
END //

DELIMITER ;

--Manager Deny User

DELIMITER //

CREATE PROCEDURE UpdateUserStatusToDenied(
  IN p_username VARCHAR(30)
)
BEGIN
  DECLARE v_previous_status ENUM('pending student', 'pending teacher');

  SELECT status INTO v_previous_status
  FROM users
  WHERE username = p_username;

  IF v_previous_status = 'pending student' OR v_previous_status = 'pending teacher' THEN
    UPDATE users
    SET status = 'denied'
    WHERE username = p_username;
  END IF;
END //

DELIMITER ;

--Manager Get Pending STs

DELIMITER //

CREATE PROCEDURE GetPendingUsers()
BEGIN
  SELECT username AS 'Username', first_name AS 'First Name', last_name AS 'Last Name', birth_date AS 'Birth Date', school_name AS 'School Name', status AS 'Status'
  FROM users
  WHERE status IN ('pending student', 'pending teacher');
END //

DELIMITER ;

--Manager Get Accepted Users

DELIMITER //

CREATE PROCEDURE GetAcceptedUsersBySchool(
  IN p_school_name VARCHAR(50),
  IN p_username VARCHAR(50)
)
BEGIN
  SELECT u.username, u.first_name, u.last_name, u.birth_date, st.role
  FROM users u
  INNER JOIN students_teachers st ON u.username = st.username
  WHERE u.status = 'accepted'
    AND (p_school_name IS NULL OR st.school_name = p_school_name)
    AND (p_username IS NULL OR u.username = p_username);
END //

DELIMITER ;

--Manager Insert New Book

DELIMITER //

CREATE PROCEDURE InsertAuthors(
  IN p_names VARCHAR(500)
)
BEGIN
  DECLARE v_author VARCHAR(100);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_pos INT DEFAULT 1;

  WHILE v_done = 0 DO
    SET v_author = SUBSTRING_INDEX(SUBSTRING_INDEX(p_names, ',', v_pos), ',', -1);
    IF v_author = '' THEN
      SET v_done = 1;
    ELSE
      BEGIN
        DECLARE CONTINUE HANDLER FOR 1062 -- Duplicate key error
          BEGIN
            -- Handle duplicate entry (optional)
            -- You can choose to ignore or log the error message
            -- In this example, we are skipping the duplicate entry and continuing
          END;
        INSERT INTO authors (author_name)
        VALUES (TRIM(v_author));
        SET v_pos = v_pos + 1;
      END;
    END IF;

    -- Check if v_pos exceeds the length of p_names
    IF v_pos > LENGTH(p_names) THEN
      SET v_done = 1;
    END IF;
  END WHILE;

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE InsertBookAuthors(
  IN p_ISBN BIGINT,
  IN p_authors VARCHAR(500)
)
BEGIN
  DECLARE v_author VARCHAR(100);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_pos INT DEFAULT 1;
  DECLARE v_author_id INT;

  WHILE v_done = 0 DO
    SET v_author = SUBSTRING_INDEX(SUBSTRING_INDEX(p_authors, ',', v_pos), ',', -1);
    IF v_author = '' THEN
      SET v_done = 1;
    ELSE
      BEGIN
        DECLARE CONTINUE HANDLER FOR 1062 -- Duplicate key error
          BEGIN
            -- Handle duplicate entry (optional)
            -- You can choose to ignore or log the error message
            -- In this example, we are skipping the duplicate entry and continuing
          END;
        SELECT author_id INTO v_author_id
        FROM authors
        WHERE author_name = TRIM(v_author);

        IF v_author_id IS NOT NULL THEN
          INSERT INTO book_authors (ISBN, author_id)
          VALUES (p_ISBN, v_author_id);
        END IF;

        SET v_pos = v_pos + 1;
      END;
    END IF;

    -- Check if v_pos exceeds the length of p_authors
    IF v_pos > LENGTH(p_authors) THEN
      SET v_done = 1;
    END IF;
  END WHILE;

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE InsertCategories(
  IN p_categories VARCHAR(500)
)
BEGIN
  DECLARE v_category VARCHAR(100);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_pos INT DEFAULT 1;

  WHILE v_done = 0 DO
    SET v_category = SUBSTRING_INDEX(SUBSTRING_INDEX(p_categories, ',', v_pos), ',', -1);
    IF v_category = '' THEN
      SET v_done = 1;
    ELSE
      BEGIN
        DECLARE CONTINUE HANDLER FOR 1062 -- Duplicate key error
        BEGIN
          -- Handle duplicate entry (optional)
          -- You can choose to ignore or log the error message
          -- In this example, we are skipping the duplicate entry and continuing
          SET v_pos = v_pos + 1;
        END;
        INSERT IGNORE INTO categories (category_name)
        VALUES (TRIM(v_category));
        SET v_pos = v_pos + 1;
      END;
    END IF;

    -- Check if v_pos exceeds the length of p_categories
    IF v_pos > LENGTH(p_categories) THEN
      SET v_done = 1;
    END IF;
  END WHILE;

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE InsertBookCategories(
  IN p_ISBN BIGINT,
  IN p_categories VARCHAR(500)
)
BEGIN
  DECLARE v_category VARCHAR(100);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_pos INT DEFAULT 1;
  DECLARE v_category_id INT;

  DECLARE EXIT HANDLER FOR 1062 -- Duplicate key error
  BEGIN
    -- Handle duplicate entry (optional)
    -- You can choose to ignore or log the error message
    -- In this example, we are skipping the duplicate entry and continuing
  END;

  WHILE v_done = 0 DO
    SET v_category = SUBSTRING_INDEX(SUBSTRING_INDEX(p_categories, ',', v_pos), ',', -1);
    IF v_category = '' THEN
      SET v_done = 1;
    ELSE
      -- Check if the category already exists
      SELECT category_id INTO v_category_id
      FROM categories
      WHERE category_name = TRIM(v_category);

      -- Insert the book-category relationship
      INSERT INTO book_categories (ISBN, category_id)
      VALUES (p_ISBN, v_category_id);

      SET v_pos = v_pos + 1;
    END IF;

    -- Check if v_pos exceeds the length of p_categories
    IF v_pos > LENGTH(p_categories) THEN
      SET v_done = 1;
    END IF;
  END WHILE;

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE InsertBook(
  IN p_ISBN BIGINT,
  IN p_image VARCHAR(1000),
  IN p_title VARCHAR(80),
  IN p_languages VARCHAR(60),
  IN p_keywords VARCHAR(60),
  IN p_publisher VARCHAR(50),
  IN p_page_num INT,
  IN p_summary VARCHAR(5000),
  IN p_authors VARCHAR(500),
  IN p_categories VARCHAR(500),
  IN p_copies INT,
  IN p_school_name VARCHAR(40)
)
BEGIN
  -- Insert into the books table
  INSERT INTO books (ISBN, image, title, languages, keywords, publisher, page_num, summary)
  VALUES (p_ISBN, p_image, p_title, p_languages, p_keywords, p_publisher, p_page_num, p_summary);

  -- Insert into the book_school_unit table
  INSERT INTO book_school_unit (ISBN, school_name, available_copies)
  VALUES (p_ISBN, p_school_name, p_copies);

  -- Insert authors into the authors table
  CALL InsertAuthors(p_authors);

  -- Insert authors and ISBN into the book_authors table
  CALL InsertBookAuthors(p_ISBN, p_authors);

  -- Insert Categories that do not exist in the categories table
  CALL InsertCategories(p_categories);

  -- Insert categories and ISBN into the book_categories table
  CALL InsertBookCategories(p_ISBN, p_categories);

END //

DELIMITER ;

--Update Existing Books Available Copies

DELIMITER //

CREATE PROCEDURE UpdateCopies(
IN p_ISBN BIGINT,
IN p_school VARCHAR(50),
IN p_new_copies INT)
BEGIN
UPDATE book_school_unit
  SET available_copies = p_new_copies
  WHERE ISBN = p_ISBN AND school_name = p_school;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE AddCopies(
IN p_ISBN BIGINT,
IN p_school VARCHAR(50),
IN p_new_copies INT)
BEGIN
UPDATE book_school_unit
  SET available_copies = available_copies + p_new_copies
  WHERE ISBN = p_ISBN AND school_name = p_school;
END //

DELIMITER ;

--See the reserve queue of the school

CREATE VIEW ReserveQueue AS
SELECT *
FROM borrow
WHERE status = 'in queue';

DELIMITER //

CREATE PROCEDURE SchoolReserveQueue(IN p_school_name VARCHAR(50))
BEGIN
    SELECT borrow.username AS 'Username', borrow.borrow_id AS 'Borrow ID', borrow.date AS 'Borrow Date', borrow.ISBN AS 'ISBN'
    FROM borrow
    INNER JOIN students_teachers ON borrow.username = students_teachers.username
    WHERE borrow.status = 'in queue' AND students_teachers.school_name = p_school_name;
END //

DELIMITER ;

--Manager Delete User

DELIMITER //

CREATE PROCEDURE DeleteUser(IN p_username VARCHAR(30))
BEGIN
    DECLARE message VARCHAR(100);
    
    DELETE FROM students_teachers WHERE username = p_username;
    DELETE FROM users WHERE username = p_username;
    
    IF ROW_COUNT() > 0 THEN
        SET message = CONCAT('User ', p_username, ' has been successfully deleted.');
    ELSE
        SET message = CONCAT('User ', p_username, ' does not exist.');
    END IF;
    
    SELECT message AS 'Result';
END //

DELIMITER ;

--Manager Register

DELIMITER //

CREATE PROCEDURE ManagerRegister(
  IN p_username VARCHAR(30),
  IN p_password VARCHAR(30),
  IN p_first_name VARCHAR(50),
  IN p_last_name VARCHAR(50),
  IN p_birth_date DATE,
  IN p_school_name VARCHAR(50),
  IN p_manager_key BIGINT
)
BEGIN
  DECLARE v_exists INT;

  -- Check if the school_name exists in the school_unit table
  SELECT COUNT(*) INTO v_exists FROM school_unit WHERE school_name = p_school_name;
  
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid school_name';
  ELSEIF p_manager_key <> 4557370293 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid manager_key';
  ELSE
    -- Insert the manager into the users table with the role 'manager' and status 'pending manager'
    INSERT INTO users (username, password, first_name, last_name, birth_date, school_name, status)
    VALUES (p_username, p_password, p_first_name, p_last_name, p_birth_date, p_school_name, 'pending manager');
    
    SELECT 'Manager inserted successfully' AS result;
  END IF;
END //

DELIMITER ;

--Manager Edit Book Info

DELIMITER //

CREATE PROCEDURE EditBook(
  IN p_ISBN BIGINT,
  IN p_image VARCHAR(1000),
  IN p_title VARCHAR(80),
  IN p_languages VARCHAR(60),
  IN p_keywords VARCHAR(60),
  IN p_publisher VARCHAR(50),
  IN p_page_num INT,
  IN p_summary VARCHAR(5000),
  IN p_authors VARCHAR(500),
  IN p_categories VARCHAR(500),
  IN p_copies INT,
  IN p_school_name VARCHAR(40)
)
BEGIN
  -- Update the books table
  UPDATE books
  SET image = p_image, title = p_title, languages = p_languages, keywords = p_keywords,
      publisher = p_publisher, page_num = p_page_num, summary = p_summary
  WHERE ISBN = p_ISBN;

  -- Update the book_school_unit table
  UPDATE book_school_unit
  SET school_name = p_school_name, available_copies = p_copies
  WHERE ISBN = p_ISBN;

  -- Insert authors into the authors table
  CALL InsertAuthors(p_authors);

  -- Delete existing book-author relationships
  DELETE FROM book_authors WHERE ISBN = p_ISBN;

  -- Insert authors and ISBN into the book_authors table
  CALL InsertBookAuthors(p_ISBN, p_authors);

  -- Insert Categories that do not exist in the categories table
  CALL InsertCategories(p_categories);

  -- Delete existing book-category relationships
  DELETE FROM book_categories WHERE ISBN = p_ISBN;

  -- Insert categories and ISBN into the book_categories table
  CALL InsertBookCategories(p_ISBN, p_categories);

END //

DELIMITER ;





--User Procedures

--3.1

DELIMITER //

CREATE PROCEDURE SearchBooksByCriteria(
  IN search_school_name VARCHAR(255),
  IN search_title VARCHAR(255),
  IN search_category_name VARCHAR(255),
  IN search_author_name VARCHAR(255)
)
BEGIN
  SELECT
    b.image AS 'Image',
    b.title AS 'Title',
    GROUP_CONCAT(DISTINCT a.author_name ORDER BY a.author_name SEPARATOR ', ') AS 'Authors',
    b.ISBN
  FROM
    books b
    JOIN book_authors ba ON b.ISBN = ba.ISBN
    JOIN authors a ON ba.author_id = a.author_id
    JOIN book_categories bc ON b.ISBN = bc.ISBN
    JOIN categories c ON bc.category_id = c.category_id
    JOIN book_school_unit bs ON b.ISBN = bs.ISBN
    JOIN students_teachers st ON bs.school_name = st.school_name
  WHERE
    (st.school_name = search_school_name)
    AND (b.title LIKE CONCAT('%', search_title, '%') OR search_title IS NULL)
    AND (c.category_name LIKE CONCAT('%', search_category_name, '%') OR search_category_name IS NULL)
    AND (a.author_name LIKE CONCAT('%', search_author_name, '%') OR search_author_name IS NULL)
  GROUP BY
    b.image,
    b.title;
END //

DELIMITER ;




--3.2
CREATE VIEW user_borrowed_books AS
SELECT
  b.title AS title,
  bor.borrow_date AS borrow_date,
  bor.return_date AS return_date,
  bor.status AS status,
  bor.username AS username,
  bor.borrow_id AS borrow_id
FROM
  books b
  JOIN book_school_unit bs ON b.ISBN = bs.ISBN
  JOIN borrow bor ON b.ISBN = bor.ISBN
WHERE bor.status IN ('lended', 'returned', 'due return')
GROUP BY
  b.title, bor.borrow_date, bor.return_date, bor.status, bor.username;


DELIMITER //

CREATE PROCEDURE GetUserBorrowedBooks(IN user_username VARCHAR(255))
BEGIN
  SELECT borrow_date AS 'Borrow Date', return_date AS 'Return Date', status AS 'Status', username AS 'User', borrow_id AS 'Borrow ID'
  FROM user_borrowed_books
  WHERE username = user_username;
END //

DELIMITER ;

--User borrow request

DELIMITER //

CREATE PROCEDURE UserBorrowRequest(
  IN p_username VARCHAR(30),
  IN p_ISBN BIGINT
)
BEGIN
  DECLARE v_school_name VARCHAR(50);
  DECLARE v_borrow_count INT;

  -- Check if the ISBN exists in book_school_unit table for the user's school_name
  SELECT school_name INTO v_school_name
  FROM book_school_unit
  WHERE ISBN = p_ISBN AND school_name = (
    SELECT school_name FROM students_teachers WHERE username = p_username
  );

  -- Check the borrow count based on user's role
  IF v_school_name IS NOT NULL THEN
    IF EXISTS(SELECT 1 FROM students_teachers WHERE username = p_username AND role = 'student') THEN
      SELECT COUNT(*) INTO v_borrow_count
      FROM borrow
      WHERE username = p_username AND status IN ('reserved', 'lended', 'due return');

      IF v_borrow_count < 2 THEN
        -- Insert the borrow request
        INSERT INTO borrow (reserve_date, return_date, borrow_date, status, ISBN, username)
        VALUES (NULL, NULL, NULL, 'pending', p_ISBN, p_username);
      END IF;
    ELSEIF EXISTS(SELECT 1 FROM students_teachers WHERE username = p_username AND role = 'teacher') THEN
      SELECT COUNT(*) INTO v_borrow_count
      FROM borrow
      WHERE username = p_username AND status IN ('reserved', 'lended', 'due return');

      IF v_borrow_count < 1 THEN
        -- Insert the borrow request
        INSERT INTO borrow (reserve_date, return_date, borrow_date, status, ISBN, username)
        VALUES (NULL, NULL, NULL, 'pending', p_ISBN, p_username);
      END IF;
    END IF;
  END IF;
END //

DELIMITER ;

--Make a book review

DELIMITER //

CREATE PROCEDURE InsertBookReview(
  IN p_username VARCHAR(30),
  IN p_ISBN BIGINT,
  IN p_comment VARCHAR(500),
  IN p_rating DECIMAL(3, 1)
)
BEGIN
  INSERT INTO book_reviews (ISBN, username, comment, rating)
  VALUES (p_ISBN, p_username, p_comment, p_rating);
END //

DELIMITER ;

--User Register

DELIMITER //

CREATE PROCEDURE UserRegister(
  IN p_username VARCHAR(30),
  IN p_password VARCHAR(30),
  IN p_first_name VARCHAR(50),
  IN p_last_name VARCHAR(50),
  IN p_birth_date DATE,
  IN p_school_name VARCHAR(50),
  IN p_role VARCHAR(20)
)
BEGIN
  DECLARE v_exists INT;

  -- Check if the school_name exists in the school_unit table
  SELECT COUNT(*) INTO v_exists FROM school_unit WHERE school_name = p_school_name;
  
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid school_name';
  ELSE
    -- Insert the user into the users table with the provided role and status
    INSERT INTO users (username, password, first_name, last_name, birth_date, school_name, status)
    VALUES (p_username, p_password, p_first_name, p_last_name, p_birth_date, p_school_name, CONCAT('pending ', p_role));
    
    SELECT 'User inserted successfully' AS result;
  END IF;
END //

DELIMITER ;

--Teacher Edit Info

DELIMITER //

CREATE PROCEDURE EditTeacherUser(
  IN p_username VARCHAR(30),
  IN p_first_name VARCHAR(50),
  IN p_last_name VARCHAR(50),
  IN p_birth_date DATE
)
BEGIN
  DECLARE v_role VARCHAR(50);

  -- Check the role of the user in the students_teachers table
  SELECT role INTO v_role FROM students_teachers WHERE username = p_username;

  IF v_role = 'teacher' THEN
    -- Update the user in the users table
    UPDATE users
    SET first_name = p_first_name, last_name = p_last_name, birth_date = p_birth_date
    WHERE username = p_username;

    SELECT 'User updated successfully' AS result;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid user role';
  END IF;
END //

DELIMITER ;

--User Change Password

DELIMITER //

CREATE PROCEDURE ChangePass(
    IN p_username VARCHAR(30),
    IN p_old_password VARCHAR(20),
    IN p_new_password VARCHAR(20)
)
BEGIN
    DECLARE v_current_password VARCHAR(20);
    
    SELECT password INTO v_current_password
    FROM users
    WHERE username = p_username;
    
    IF v_current_password = p_old_password THEN
        UPDATE users
        SET password = p_new_password
        WHERE username = p_username;
        SELECT 'Password updated successfully.' AS Message;
    ELSE
        SELECT 'Invalid old password. Password not changed.' AS Message;
    END IF;
    
END //

DELIMITER ;


--User Get Reviews for a Book

DELIMITER //

CREATE PROCEDURE GetBookReviews(IN p_ISBN BIGINT)
BEGIN
    SELECT br.rating AS 'Book Rating', br.comment AS 'Comment', u.username 'Username'
    FROM book_reviews br
    INNER JOIN users u ON br.username = u.username
    WHERE br.ISBN = p_ISBN;
END //

DELIMITER ;

--User Get Account Info

DELIMITER //

CREATE PROCEDURE GetUserDetails()
BEGIN
    SELECT u.username AS 'Username', u.first_name AS 'First Name', u.last_name AS 'Last Name', u.birth_date AS 'Birth Date', st.school_name AS 'School Name', st.role AS 'Account Type'
    FROM users u
    INNER JOIN students_teachers st ON u.username = st.username;
END //

DELIMITER ;