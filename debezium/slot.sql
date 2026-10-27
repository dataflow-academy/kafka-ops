-- The replication slots of the SCADA database and how much write-ahead log each one holds back.
-- retained_wal: the log between the oldest position the slot still needs (restart_lsn) and now. PostgreSQL may not
-- delete any of it. pg_wal: what lies on the disk right now.
SELECT slot_name, active, wal_status,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS not_confirmed
FROM pg_replication_slots;
SELECT count(*) AS wal_files, pg_size_pretty(sum(size)) AS pg_wal FROM pg_ls_waldir();
