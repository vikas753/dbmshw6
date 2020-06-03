USE `lotrfinal_1`;

/* Q.1 : Procedure for track_character */
DROP PROCEDURE IF EXISTS `track_character`;

DELIMITER $$

CREATE PROCEDURE track_character
(
  input_character VARCHAR(100)
)
BEGIN
  SELECT character1_name , character2_name , title as book_name , region_name 
  FROM lotr_book
  INNER JOIN
  (SELECT * FROM lotr_first_encounter 
  WHERE (character1_name = input_character) 
  OR (character2_name = input_character)) AS encounter_table
  WHERE encounter_table.book_id = lotr_book.book_id; 
END $$ 

DELIMITER ;

CALL track_character("aragorn");

/* Q.2 : Procedure for track_region */
DROP PROCEDURE IF EXISTS `track_region`;


DELIMITER $$

CREATE PROCEDURE track_region
(
  input_region VARCHAR(100)
)
BEGIN
  SELECT region_encounter_table.region_name , leader , book_name , COUNT(*) AS num_encounters FROM
  (SELECT character1_name , character2_name , title as book_name , region_name 
  FROM lotr_book
  INNER JOIN
  (SELECT * FROM lotr_first_encounter 
  WHERE region_name = input_region) AS encounter_table
  WHERE encounter_table.book_id = lotr_book.book_id) AS region_encounter_table
  INNER JOIN
  lotr_region 
  WHERE region_encounter_table.region_name = lotr_region.region_name GROUP BY region_encounter_table.region_name; 
END $$ 

DELIMITER ;

CALL track_region("rivendell");

/* Q.3 : Function for strongerSpecies */

DROP FUNCTION IF EXISTS `strongerSpecies`;

DELIMITER $$

CREATE FUNCTION strongerSpecies
(
  sp1 VARCHAR(100),
  sp2 VARCHAR(100)
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE speciesone_size INT;
    DECLARE speciestwo_size INT;
    DECLARE result_value INT;
    
    SELECT size INTO speciesone_size FROM lotr_species WHERE species_name = sp1;
    SELECT size INTO speciestwo_size FROM lotr_species WHERE species_name = sp2;
    IF speciesone_size > speciestwo_size THEN SET result_value = 1;
    ELSEIF speciesone_size = speciestwo_size THEN SET result_value = 0;
    ELSEIF speciesone_size < speciestwo_size THEN SET result_value = -1;
    END IF;
  RETURN result_value;
END $$
  
DELIMITER ; 

SELECT strongerSpecies("balrog","ent") lotr_species; 

/* Q.4 : Function for region with most encounters of a character */

DROP FUNCTION IF EXISTS `region_most_encounters`;    

DELIMITER $$

CREATE FUNCTION region_most_encounters
(
  input_character VARCHAR(100)
)
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE result_value VARCHAR(100);
    
    SELECT region_name INTO result_value FROM
    (SELECT region_name , COUNT(*) AS num_encounters FROM lotr_first_encounter 
    WHERE ((character1_name = input_character) OR (character2_name = input_character)) GROUP BY region_name) 
    AS region_encounter_table ORDER BY num_encounters DESC LIMIT 1; 
    
    RETURN(result_value);
END $$
  
DELIMITER ; 

SELECT region_most_encounters("gimli"); 

/* Q.5 : Check for first encounter if it is homeland or not */

DROP FUNCTION IF EXISTS `home_region_encounter`;    

DELIMITER $$

CREATE FUNCTION home_region_encounter
(
  input_character VARCHAR(100)
)
RETURNS BOOL
READS SQL DATA
BEGIN
    DECLARE result_value                   BOOL;
    DECLARE region_first_encounter VARCHAR(100);
    DECLARE homeland_region        VARCHAR(100);
    
    SELECT region_name INTO region_first_encounter FROM
    (SELECT  character1_name,character2_name,region_name,row_number() OVER (ORDER BY character1_name,character2_name,region_name) FROM lotr_first_encounter WHERE 
    ((character1_name = input_character) OR (character2_name = input_character)) LIMIT 1) AS ordered_table_rows;
    
    SELECT homeland INTO homeland_region FROM lotr_character WHERE character_name = input_character;
    
    IF region_first_encounter = homeland_region THEN SET result_value = TRUE;
    ELSE SET result_value = FALSE;
    END IF;
    
    RETURN(result_value);
END $$

DELIMITER ;

SELECT home_region_encounter("elrond"); 

/* Q.6 : Number of encounters of a region */

DROP FUNCTION IF EXISTS `encounters_in_num_region`;    

DELIMITER $$

CREATE FUNCTION encounters_in_num_region
(
  input_region VARCHAR(100)
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE result_value                   INT;
    
    SELECT COUNT(*) INTO result_value FROM lotr_first_encounter WHERE region_name = input_region GROUP BY region_name LIMIT 1;
    
    RETURN(result_value);
END $$

DELIMITER ;

SELECT encounters_in_num_region("bree"); 

/* Q.7 : Procedure for fellowship encounters */
DROP PROCEDURE IF EXISTS `fellowship_encounters`;

DELIMITER $$

CREATE PROCEDURE fellowship_encounters
(
  input_book VARCHAR(100)
)
BEGIN
  SELECT character_name , COUNT(*) as num_first_encounters FROM
  (SELECT character1_name,character2_name,lotr_book.book_id,region_name,title FROM lotr_first_encounter INNER JOIN lotr_book 
    ON lotr_first_encounter.book_id = lotr_book.book_id WHERE title = input_book) as encounters_table
  INNER JOIN
  lotr_character 
  WHERE ((character_name = character1_name) OR (character_name = character2_name)) GROUP BY character_name;
END $$ 

DELIMITER ;

CALL fellowship_encounters("the fellowship of the ring");

/* Modifyiing the structure of books table for next set of questions */
ALTER TABLE lotr_book
ADD encounters_in_book INT;

/* Q.8 : Procedure for encounters count */
DROP PROCEDURE IF EXISTS `initialize_encounters_count`;

DELIMITER $$

CREATE PROCEDURE initialize_encounters_count
(
  input_book_id INT
)
BEGIN
  DECLARE num_encounters_book INT;
  SELECT COUNT(*) INTO num_encounters_book FROM lotr_first_encounter 
  WHERE book_id = input_book_id GROUP BY book_id;
  UPDATE lotr_book SET encounters_in_book = num_encounters_book 
  WHERE book_id = input_book_id;
END $$ 

DELIMITER ;

CALL initialize_encounters_count(1);
CALL initialize_encounters_count(3);
CALL initialize_encounters_count(2);

/* Q.9 Trigger an event */
DROP TRIGGER IF EXISTS firstencounters_after_insert;
DELIMITER $$
CREATE TRIGGER firstencounters_after_insert 
AFTER INSERT ON lotr_first_encounter
FOR EACH ROW
BEGIN
  CALL initialize_encounters_count(NEW.book_id);
END $$

DELIMITER ;
INSERT INTO lotr_first_encounter VALUES ("legolas","frodo",1,"Rivendell");

/* Q.10 Prepared statement to execute home region encounters */
PREPARE home_region_encs FROM 'SELECT home_region_encounter(?)';
SET @character_name = 'Aragorn';
EXECUTE home_region_encs USING @character_name;

/* Q.11 Prepared statement to execute region most encounters */
PREPARE region_most_encs FROM 'SELECT region_most_encounters(?)';
SET @character_name2 = 'Aragorn';
EXECUTE region_most_encs USING @character_name2;