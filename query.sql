CREATE TABLE `prolaser4` (
	`rid` INT(11) NOT NULL AUTO_INCREMENT,
	`timestamp` DATETIME NOT NULL,
	`speed` INT(11) NOT NULL DEFAULT '0',
	`distance` FLOAT NOT NULL DEFAULT '0',
	`targetX` FLOAT NOT NULL DEFAULT '0',
	`targetY` FLOAT NOT NULL DEFAULT '0',
	`player` TEXT NOT NULL COLLATE 'latin1_swedish_ci',
	`street` TEXT NOT NULL COLLATE 'latin1_swedish_ci',
	`selfTestTimestamp` DATETIME NOT NULL,
	PRIMARY KEY (`rid`) USING BTREE
)
COLLATE='latin1_swedish_ci'
ENGINE=InnoDB
AUTO_INCREMENT=1
;
