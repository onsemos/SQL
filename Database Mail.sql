
/*
http://www.snapdba.com/2013/04/enabling-and-configuring-database-mail-in-sql-server-using-t-sql/#.V-MSLigrLmE
*/

USE msdb

SELECT		TOP 100 send_request_date, sent_date,*
FROM		msdb.dbo.sysmail_mailitems 
ORDER BY 1 DESC


SELECT		* 
FROM		msdb.dbo.sysmail_log
ORDER BY log_id DESC 


--Check to see if the service broker is enabled (should be 1):
SELECT is_broker_enabled FROM sys.databases WHERE name = 'msdb'

--Check to see if Database Mail is started in the msdb database:
EXECUTE dbo.sysmail_help_status_sp

--and start Database Mail if necessary:
EXECUTE dbo.sysmail_start_sp

--Check the status of the mail queue:
sysmail_help_queue_sp @queue_type = 'Mail'

--Check the Database Mail event logs:
SELECT * FROM sysmail_event_log

--Check the mail queue for the status of all items (including sent mails):
SELECT * FROM sysmail_allitems