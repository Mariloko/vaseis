--Increase copies on return
DELIMITER //

CREATE TRIGGER increase_copies_on_return
AFTER UPDATE ON borrow
FOR EACH ROW
BEGIN
    IF NEW.status = 'returned' AND OLD.status <> 'returned' THEN
        UPDATE book_school_unit
        SET available_copies = available_copies + 1
        WHERE ISBN = NEW.ISBN;
    END IF;
END //

DELIMITER ;

--Queue and reserve handling

DELIMITER //

CREATE PROCEDURE DecrementAvailableCopies(IN p_ISBN BIGINT)
BEGIN

  UPDATE book_school_unit
  SET available_copies = available_copies - 1
  WHERE ISBN = p_ISBN;
END //

DELIMITER ;



DELIMITER //

CREATE TRIGGER update_status_reserve_date
BEFORE UPDATE ON book_school_unit
FOR EACH ROW
BEGIN
    DECLARE v_username VARCHAR(30);
    DECLARE v_borrow_id INT;
    DECLARE v_borrow_date DATE;
    DECLARE v_borrow_ISBN BIGINT;
    DECLARE v_available_copies INT;
    DECLARE v_counter INT;
    
    SET v_available_copies = NEW.available_copies;
    
    IF v_available_copies > 0 AND OLD.available_copies = 0 THEN
        SET v_counter = 0;
        
        WHILE v_counter < v_available_copies DO
            SELECT borrow.username, borrow.borrow_id, borrow.date, borrow.ISBN INTO v_username, v_borrow_id, v_borrow_date, v_borrow_ISBN
            FROM borrow
            INNER JOIN students_teachers ON borrow.username = students_teachers.username
            WHERE borrow.status = 'in queue' AND students_teachers.school_name = NEW.school_name
            ORDER BY borrow.date ASC
            LIMIT 1;
            
            IF v_username IS NOT NULL THEN
                UPDATE borrow
                SET status = 'reserved', reserve_date = CURDATE()
                WHERE borrow_id = v_borrow_id;
                
                SET v_counter = v_counter + 1;
            END IF;
        END WHILE;
        
        -- Decrement the available_copies by the number of reserved copies
        SET NEW.available_copies = v_available_copies - v_counter;
    END IF;
END //

DELIMITER ;



SET GLOBAL event_scheduler = ON;

CREATE EVENT UpdateBorrowStatusEvent
ON SCHEDULE EVERY 1 DAY -- Adjust the frequency as needed
STARTS CURRENT_TIMESTAMP
DO
    UPDATE borrow
    SET status = 'expired'
    WHERE status = 'reserved'
      AND reserve_date < DATE_SUB(CURDATE(), INTERVAL 1 WEEK);

SET GLOBAL event_scheduler = ON;

CREATE EVENT UpdateDueReturnStatusEvent
ON SCHEDULE EVERY 1 DAY -- Adjust the frequency as needed
STARTS CURRENT_TIMESTAMP
DO
    UPDATE borrow
    SET status = 'due return'
    WHERE status = 'lended'
      AND return_date < CURDATE();

DELIMITER //

CREATE TRIGGER UpdateSchoolNameTrigger
AFTER UPDATE ON school_unit
FOR EACH ROW
BEGIN
  IF OLD.school_name <> NEW.school_name THEN
    UPDATE users SET school_name = NEW.school_name WHERE school_name = OLD.school_name;
    UPDATE students_teachers SET school_name = NEW.school_name WHERE school_name = OLD.school_name;
    UPDATE manager SET school_name = NEW.school_name WHERE school_name = OLD.school_name;
    UPDATE book_school_unit SET school_name = NEW.school_name WHERE school_name = OLD.school_name;
  END IF;
END //

DELIMITER ;