CREATE USER 'truenorth_app'@'127.0.0.1'
IDENTIFIED BY 'Psalm119!';

GRANT SELECT, INSERT, UPDATE, DELETE
ON truenorth119.*
TO 'truenorth_app'@'127.0.0.1';