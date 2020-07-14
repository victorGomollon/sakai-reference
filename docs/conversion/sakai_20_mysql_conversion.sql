-- clear unchanged bundle properties
DELETE SAKAI_MESSAGE_BUNDLE from SAKAI_MESSAGE_BUNDLE where PROP_VALUE is NULL;

-- SAK_41228
UPDATE CM_MEMBERSHIP_T SET USER_ID = LOWER(USER_ID);
UPDATE CM_ENROLLMENT_T SET USER_ID = LOWER(USER_ID);
UPDATE CM_OFFICIAL_INSTRUCTORS_T SET INSTRUCTOR_ID = LOWER(INSTRUCTOR_ID);
-- End of SAK_41228

-- SAK-41391

ALTER TABLE POLL_OPTION ADD OPTION_ORDER INTEGER;

-- END SAK-41391

-- SAK-41825
ALTER TABLE SAM_ASSESSMENTBASE_T ADD CATEGORYID BIGINT(20);
ALTER TABLE SAM_PUBLISHEDASSESSMENT_T ADD CATEGORYID BIGINT(20);
-- END SAK-41825

-- User Activity (SAK-40018)
create table SST_DETAILED_EVENTS
(ID bigint not null auto_increment,
 USER_ID varchar(99) not null,
 SITE_ID varchar(99) not null,
 EVENT_ID varchar(32) not null,
 EVENT_DATE datetime not null,
 EVENT_REF varchar(512) not null,
 primary key (ID));

create index IDX_DE_SITE_ID_DATE on SST_DETAILED_EVENTS(SITE_ID,EVENT_DATE);
create index IDX_DE_SITE_ID_USER_ID_DATE on SST_DETAILED_EVENTS(SITE_ID,USER_ID,EVENT_DATE);

INSERT INTO SAKAI_REALM_FUNCTION VALUES (DEFAULT, 'sitestats.usertracking.track');
INSERT INTO SAKAI_REALM_FUNCTION VALUES (DEFAULT, 'sitestats.usertracking.be.tracked');

INSERT INTO SAKAI_REALM_RL_FN VALUES((select REALM_KEY from SAKAI_REALM where REALM_ID = '!site.template'), (select ROLE_KEY from SAKAI_REALM_ROLE where ROLE_NAME = 'maintain'), (select FUNCTION_KEY from SAKAI_REALM_FUNCTION where FUNCTION_NAME = 'sitestats.usertracking.track'));
INSERT INTO SAKAI_REALM_RL_FN VALUES((select REALM_KEY from SAKAI_REALM where REALM_ID = '!site.template'), (select ROLE_KEY from SAKAI_REALM_ROLE where ROLE_NAME = 'access'), (select FUNCTION_KEY from SAKAI_REALM_FUNCTION where FUNCTION_NAME = 'sitestats.usertracking.be.tracked'));
INSERT INTO SAKAI_REALM_RL_FN VALUES((select REALM_KEY from SAKAI_REALM where REALM_ID = '!site.template.course'), (select ROLE_KEY from SAKAI_REALM_ROLE where ROLE_NAME = 'Instructor'), (select FUNCTION_KEY from SAKAI_REALM_FUNCTION where FUNCTION_NAME = 'sitestats.usertracking.track'));
INSERT INTO SAKAI_REALM_RL_FN VALUES((select REALM_KEY from SAKAI_REALM where REALM_ID = '!site.template.course'), (select ROLE_KEY from SAKAI_REALM_ROLE where ROLE_NAME = 'Student'), (select FUNCTION_KEY from SAKAI_REALM_FUNCTION where FUNCTION_NAME = 'sitestats.usertracking.be.tracked'));

CREATE TABLE PERMISSIONS_SRC_TEMP (ROLE_NAME VARCHAR(99), FUNCTION_NAME VARCHAR(99));
INSERT INTO PERMISSIONS_SRC_TEMP values ('maintain','sitestats.usertracking.track');
INSERT INTO PERMISSIONS_SRC_TEMP values ('access','sitestats.usertracking.be.tracked');
INSERT INTO PERMISSIONS_SRC_TEMP values ('Instructor','sitestats.usertracking.track');
INSERT INTO PERMISSIONS_SRC_TEMP values ('Student','sitestats.usertracking.be.tracked');

CREATE TABLE PERMISSIONS_TEMP (ROLE_KEY INTEGER, FUNCTION_KEY INTEGER);
INSERT INTO PERMISSIONS_TEMP (ROLE_KEY, FUNCTION_KEY)
  SELECT SRR.ROLE_KEY, SRF.FUNCTION_KEY
    from PERMISSIONS_SRC_TEMP TMPSRC
    JOIN SAKAI_REALM_ROLE SRR ON (TMPSRC.ROLE_NAME = SRR.ROLE_NAME)
    JOIN SAKAI_REALM_FUNCTION SRF ON (TMPSRC.FUNCTION_NAME = SRF.FUNCTION_NAME);

INSERT INTO SAKAI_REALM_RL_FN (REALM_KEY, ROLE_KEY, FUNCTION_KEY)
  SELECT SRRFD.REALM_KEY, SRRFD.ROLE_KEY, TMP.FUNCTION_KEY
  FROM
    (SELECT DISTINCT SRRF.REALM_KEY, SRRF.ROLE_KEY FROM SAKAI_REALM_RL_FN SRRF) SRRFD
    JOIN PERMISSIONS_TEMP TMP ON (SRRFD.ROLE_KEY = TMP.ROLE_KEY)
    JOIN SAKAI_REALM SR ON (SRRFD.REALM_KEY = SR.REALM_KEY)
    WHERE SR.REALM_ID != '!site.helper' AND SR.REALM_ID NOT LIKE '!user.template%'
    AND NOT EXISTS (
        SELECT 1
            FROM SAKAI_REALM_RL_FN SRRFI
            WHERE SRRFI.REALM_KEY=SRRFD.REALM_KEY AND SRRFI.ROLE_KEY=SRRFD.ROLE_KEY AND SRRFI.FUNCTION_KEY=TMP.FUNCTION_KEY
    );

DROP TABLE PERMISSIONS_TEMP;
DROP TABLE PERMISSIONS_SRC_TEMP;
-- End User Activity (SAK-40018)

-- SAK-34741
ALTER TABLE SAM_ITEM_T ADD ISEXTRACREDIT bit(1) NULL DEFAULT NULL;
ALTER TABLE SAM_PUBLISHEDITEM_T ADD ISEXTRACREDIT bit(1) NULL DEFAULT NULL;
-- END SAK-34741

-- START SAK-42400
ALTER TABLE SAM_ASSESSACCESSCONTROL_T ADD FEEDBACKENDDATE DATETIME;
ALTER TABLE SAM_PUBLISHEDACCESSCONTROL_T ADD FEEDBACKENDDATE DATETIME;
ALTER TABLE SAM_ASSESSACCESSCONTROL_T ADD FEEDBACKSCORETHRESHOLD DOUBLE;
ALTER TABLE SAM_PUBLISHEDACCESSCONTROL_T ADD FEEDBACKSCORETHRESHOLD DOUBLE;
-- END SAK-42400

-- BEGIN SAK-42498
ALTER TABLE BULLHORN_ALERTS DROP INDEX IDX_BULLHORN_ALERTS_ALERT_TYPE_TO_USER;
ALTER TABLE BULLHORN_ALERTS DROP COLUMN ALERT_TYPE;
ALTER TABLE BULLHORN_ALERTS ADD INDEX IDX_BULLHORN_ALERTS_TO_USER(TO_USER);
-- END SAK-42498

-- SAK-41172: SAKAI_REALM_LOCKS
CREATE TABLE SAKAI_REALM_LOCKS (
REALM_KEY INTEGER NOT NULL,
REFERENCE VARCHAR (255) NOT NULL,
LOCK_MODE INTEGER NOT NULL
);

ALTER TABLE SAKAI_REALM_LOCKS
ADD ( PRIMARY KEY (REALM_KEY, REFERENCE) ) ;

ALTER TABLE SAKAI_REALM_LOCKS
ADD ( FOREIGN KEY (REALM_KEY)
REFERENCES SAKAI_REALM (REALM_KEY) ) ;

DROP FUNCTION IF EXISTS SPLITASSIGNMENTREFERENCES;
DROP PROCEDURE IF EXISTS BUILDGROUPLOCKTABLE;
DELIMITER $$
CREATE FUNCTION SPLITASSIGNMENTREFERENCES(ASSIGNMENTREFERENCES VARCHAR(4096), POS INTEGER) RETURNS VARCHAR(4096)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE OUTPUT VARCHAR(4096);
    DECLARE DELIM VARCHAR(3);
    SET DELIM = '#:#';
    SET OUTPUT = REPLACE(
        SUBSTRING(SUBSTRING_INDEX(ASSIGNMENTREFERENCES, DELIM, POS), LENGTH(SUBSTRING_INDEX(ASSIGNMENTREFERENCES, DELIM, POS - 1)) + 1)
        , DELIM
        , '');
    IF OUTPUT = '' THEN SET OUTPUT = NULL; END IF;
    RETURN OUTPUT;
END $$

CREATE PROCEDURE BUILDGROUPLOCKTABLE()
BEGIN
    DECLARE I INTEGER;
    SET I = 1;
    REPEAT
        INSERT INTO SAKAI_REALM_LOCKS (REALM_KEY, REFERENCE, LOCK_MODE)
            SELECT (SELECT REALM_KEY FROM SAKAI_REALM WHERE REALM_ID = (SELECT CONCAT_WS('/', '/site', SITE_ID, 'group', GROUP_ID))),
                   CONCAT('/assignment/a/', SITE_ID, '/', SUBSTRING_INDEX(SPLITASSIGNMENTREFERENCES(VALUE, I), '/', -1)),
                   1
            FROM SAKAI_SITE_GROUP_PROPERTY
            WHERE SPLITASSIGNMENTREFERENCES(VALUE, I) IS NOT NULL AND NAME='group_prop_locked_by';
        SET I = I + 1;
    UNTIL ROW_COUNT() = 0
        END REPEAT;
END $$

DELIMITER ;

CALL BUILDGROUPLOCKTABLE();
DROP FUNCTION SPLITASSIGNMENTREFERENCES;
DROP PROCEDURE BUILDGROUPLOCKTABLE;
-- END SAK-41172

-- SAK-43077
update GB_CATEGORY_T set IS_EQUAL_WEIGHT_ASSNS = false where IS_EQUAL_WEIGHT_ASSNS is null;
alter table GB_CATEGORY_T modify IS_EQUAL_WEIGHT_ASSNS bit not null default false;
-- END SAK-43077

-- SAK-42474
ALTER TABLE ASN_SUBMISSION ADD COLUMN PRIVATE_NOTES longtext NULL;
-- END SAK-42474

ALTER TABLE GB_GRADE_RECORD_T DROP COLUMN EXCLUDED;

-- SAK-42190 ONEDRIVE
CREATE TABLE ONEDRIVE_USER (
  oneDriveUserId varchar(255) NOT NULL,
  oneDriveName varchar(255) DEFAULT NULL,
  refreshToken longtext,
  sakaiUserId varchar(99) DEFAULT NULL,
  token longtext,
  PRIMARY KEY (oneDriveUserId)
);
-- END SAK-42190 ONEDRIVE

-- SAK-42423 GOOGLEDRIVE
CREATE TABLE GOOGLEDRIVE_USER (
  sakaiUserId varchar(99) NOT NULL,
  googleDriveName varchar(255) DEFAULT NULL,
  refreshToken longtext,
  googleDriveUserId varchar(255) DEFAULT NULL,
  token longtext,
  PRIMARY KEY (sakaiUserId),
  UNIQUE (googleDriveUserId)
);
-- END SAK-42423 GOOGLEDRIVE

-- START SAK-41812
ALTER TABLE SAKAI_PERSON_T ADD COLUMN PHONETIC_PRONUNCIATION varchar(255) DEFAULT NULL;
-- END SAK-41812

-- START SAK-43441
CREATE TEMPORARY TABLE messages_with_rubric AS
    SELECT CONCAT(m.CREATED_BY, ".", m.UUID) evaluated_item_id, m.CREATED_BY evaluee, re.association_id messageAssociationId, m.GRADEASSIGNMENTNAME gbItemId
        FROM MFR_MESSAGE_T m
        INNER JOIN rbc_evaluation re ON re.evaluated_item_id = CONCAT(m.CREATED_BY, ".", m.UUID)
        WHERE m.GRADEASSIGNMENTNAME IS NOT NULL;

UPDATE IGNORE rbc_evaluation re
    INNER JOIN messages_with_rubric mwr ON re.evaluated_item_id = mwr.evaluated_item_id
    INNER JOIN rbc_tool_item_rbc_assoc ra ON mwr.gbItemId = ra.itemId
        SET association_id = ra.id
        ,re.evaluated_item_id = CONCAT(mwr.gbItemId, ".", mwr.evaluee)
        WHERE association_id = messageAssociationId;

DROP TABLE messages_with_rubric;
-- END SAK-43441

-- START SAK-41502: Excusing an individual grade should be reflected in score's Grade Log
ALTER TABLE GB_GRADING_EVENT_T ADD IS_EXCLUDED INTEGER;
-- END SAK-41502: Excusing an individual grade should be reflected in score's Grade Log
