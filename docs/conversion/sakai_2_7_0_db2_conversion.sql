-- This is the DB2 Sakai 2.6.x -> 2.7.0 conversion script
-- --------------------------------------------------------------------------------------------------------------------------------------
-- 
-- use this to convert a Sakai database from 2.6.x to 2.7.0.  Run this before you run your first app server.
-- auto.ddl does not need to be enabled in your app server - this script takes care of all new TABLEs, changed TABLEs, and changed data.
--
-- --------------------------------------------------------------------------------------------------------------------------------------

-- SAK-16610 introduced a new osp presentation review permission
INSERT INTO SAKAI_REALM_FUNCTION (FUNCTION_NAME) VALUES ( 'osp.presentation.review' );

-- SAK-16686/KNL-241 Support exceptions to dynamic page localization
INSERT INTO SAKAI_SITE_PAGE_PROPERTY VALUES ('~admin','~admin-400','sitePage.customTitle','true');

-- SAK-16832
ALTER TABLE SAM_PUBLISHEDASSESSMENT_T ADD LASTNEEDRESUBMITDATE DATE NULL;
