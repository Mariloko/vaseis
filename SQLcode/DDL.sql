SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS dtbs;
CREATE SCHEMA dtbs;
USE dtbs;

CREATE TABLE school_unit (
  school_name VARCHAR(50) NOT NULL,
  principal VARCHAR(50) NOT NULL,
  lib_manager_fn VARCHAR(20) NOT NULL,
  lib_manager_ln VARCHAR(20) NOT NULL,
  city VARCHAR(30) NOT NULL,
  postal_code INT NOT NULL,
  email VARCHAR(50) NOT NULL,
  phone_num BIGINT NOT NULL,
  PRIMARY KEY (school_name),
  CONSTRAINT check_10_digits CHECK (LENGTH(phone_num) = 10),
  CONSTRAINT check_5_digits CHECK (LENGTH(postal_code) = 5),
  CONSTRAINT fk_school_unit_lib_manager_fn_lib_manager_ln FOREIGN KEY (lib_manager_fn, lib_manager_ln) REFERENCES managers(first_name, last_name) 
);

CREATE TABLE books (
  ISBN BIGINT NOT NULL,
  image VARCHAR(1000) NOT NULL,
  title VARCHAR (80) NOT NULL,
  languages VARCHAR (60) NOT NULL,
  keywords VARCHAR (60) NOT NULL,
  publisher VARCHAR (50) NOT NULL,
  page_num INT NOT NULL,
  summary VARCHAR (5000) NOT NULL,
  PRIMARY KEY (ISBN)
  );

CREATE TABLE book_school_unit (
  ISBN BIGINT NOT NULL,
  school_name VARCHAR(50) NOT NULL,
  available_copies INT NOT NULL,
  PRIMARY KEY (ISBN, school_name),
  CONSTRAINT fk_book_school_unit_ISBN FOREIGN KEY (ISBN) REFERENCES books (ISBN),
  CONSTRAINT fk_book_school_unit_school_name FOREIGN KEY (school_name) REFERENCES school_unit (school_name)
);

CREATE TABLE authors (
  author_name VARCHAR(50) NOT NULL,
  author_id INT NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (author_id),
  UNIQUE (author_name)
);

CREATE TABLE book_authors (
  ISBN BIGINT NOT NULL,
  author_id INT NOT NULL,
  PRIMARY KEY (ISBN, author_id),
  CONSTRAINT fk_book_authors_ISBN FOREIGN KEY (ISBN) REFERENCES books(ISBN),
  FOREIGN KEY (author_id) REFERENCES authors(author_id)
);

CREATE TABLE categories (
  category_id INT NOT NULL AUTO_INCREMENT,
  category_name VARCHAR(40) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE (category_name)
);

CREATE TABLE book_categories (
  ISBN BIGINT NOT NULL,
  category_id INT NOT NULL,
  PRIMARY KEY (ISBN, category_id),
  CONSTRAINT fk_book_categories_ISBN FOREIGN KEY (ISBN) REFERENCES books(ISBN),
  CONSTRAINT fk_book_categories_category_id FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE users (
  username VARCHAR(30) NOT NULL PRIMARY KEY,
  password VARCHAR(20) NOT NULL,
  first_name VARCHAR(20) NOT NULL,
  last_name VARCHAR(20) NOT NULL,
  birth_date DATE NOT NULL,
  school_name VARCHAR(50) NOT NULL DEFAULT 'North High School',
  status ENUM ('accepted', 'denied', 'pending teacher', 'pending student', 'pending manager') NOT NULL
  );

CREATE TABLE administrator (
  username VARCHAR(30) NOT NULL PRIMARY KEY,
  CONSTRAINT fk_administrator_username FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
  );

CREATE TABLE manager (
  username VARCHAR(30) NOT NULL,
  school_name VARCHAR(40) NOT NULL,
  PRIMARY KEY (username, school_name),
  CONSTRAINT fk_managers_username FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE,
  CONSTRAINT fk_managers_school_name FOREIGN KEY (school_name) REFERENCES school_unit(school_name) ON DELETE CASCADE
  );

CREATE TABLE students_teachers (
  username VARCHAR (30) NOT NULL PRIMARY KEY,
  school_name VARCHAR(40) NOT NULL,
  role ENUM ('student', 'teacher') NOT NULL,
  FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
  );

CREATE TABLE borrow (
  reserve_date DATE,
  return_date DATE,
  borrow_date DATE,
  status ENUM ('reserved', 'pending', 'denied', 'lended', 'due return', 'returned', 'in queue', 'expired') DEFAULT 'pending',
  ISBN BIGINT NOT NULL,
  username VARCHAR(30) NOT NULL,
  borrow_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  date DATE DEFAULT CURRENT_DATE() NOT NULL,
  FOREIGN KEY (username) REFERENCES students_teachers(username) ON DELETE CASCADE,
  FOREIGN KEY (ISBN) REFERENCES books(ISBN) ON DELETE CASCADE
);


CREATE TABLE book_reviews (
  ISBN BIGINT NOT NULL,
  username VARCHAR(30) NOT NULL,
  comment VARCHAR(500) NOT NULL,
  rating DECIMAL(3, 1) CHECK (rating >= 0 AND rating <= 5),
  FOREIGN KEY (ISBN) REFERENCES books(ISBN) ON DELETE CASCADE,
  FOREIGN KEY (username) REFERENCES students_teachers(username) ON DELETE CASCADE,
  PRIMARY KEY (ISBN, username)
);

CREATE UNIQUE INDEX idx_school_name ON school_unit (school_name);

CREATE INDEX idx_school_unit_lib_manager ON school_unit (lib_manager_fn, lib_manager_ln);

CREATE INDEX idx_books_ISBN ON books (ISBN);

CREATE INDEX idx_book_school_unit_primary ON book_school_unit (ISBN, school_name);

CREATE INDEX idx_book_school_unit_ISBN ON book_school_unit (ISBN);

CREATE INDEX idx_authors_primary ON authors (author_id);

CREATE INDEX idx_authors_author_name ON authors (author_name);

CREATE INDEX idx_book_authors_primary ON book_authors (ISBN, author_id);

CREATE INDEX idx_book_authors_ISBN ON book_authors (ISBN);

CREATE INDEX idx_book_authors_author_id ON book_authors (author_id);

CREATE INDEX idx_book_categories_primary ON book_categories (ISBN, category_id);

CREATE INDEX idx_book_categories_ISBN ON book_categories (ISBN);

CREATE INDEX idx_book_categories_category_id ON book_categories (category_id);

CREATE INDEX idx_users_primary ON users (username);

CREATE INDEX idx_manager_primary ON manager (username, school_name);

CREATE INDEX idx_manager_username ON manager (username);

CREATE INDEX idx_manager_school_name ON manager (school_name);

CREATE INDEX idx_students_teachers_primary ON students_teachers (username);

CREATE INDEX idx_students_teachers_school_name ON students_teachers (school_name);

CREATE INDEX idx_borrow_primary ON borrow (username, ISBN);

CREATE INDEX idx_borrow_username ON borrow (username);

CREATE INDEX idx_borrow_ISBN ON borrow (ISBN);

CREATE INDEX idx_book_reviews_primary ON book_reviews (ISBN, username);

CREATE INDEX idx_book_reviews_ISBN ON book_reviews (ISBN);

CREATE INDEX idx_book_reviews_username ON book_reviews (username);

CREATE UNIQUE INDEX idx_author_id ON authors (author_id);