-- ============================================================================
-- GlobalHealth Unified System
-- Entregable XML - Script 01: base de datos SQL Server 2022
-- ============================================================================

USE master;
GO

IF DB_ID(N'GlobalHealthXml') IS NULL
BEGIN
    CREATE DATABASE GlobalHealthXml;
END;
GO

ALTER DATABASE GlobalHealthXml SET RECOVERY SIMPLE;
GO

USE GlobalHealthXml;
GO

