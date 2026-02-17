-- Sample Queries for VMSizes Database
-- Use these queries to explore and test the data

USE VMSizes;
GO

-- 1. Get all VM sizes
SELECT * FROM dbo.VMSizes;

-- 2. Count VM sizes by region
SELECT
    Region,
    COUNT(*) AS VMCount
FROM dbo.VMSizes
GROUP BY Region
ORDER BY VMCount DESC;

-- 3. Find VMs with specific CPU and Memory requirements
SELECT
    Name,
    CPU,
    MemoryGB,
    Region
FROM dbo.VMSizes
WHERE CPU >= 4 AND MemoryGB >= 16
ORDER BY CPU, MemoryGB;

-- 4. Get VMs with Accelerated Networking support
SELECT
    Name,
    CPU,
    MemoryGB,
    Region
FROM dbo.VMSizes
WHERE AcceleratedNetworking = 'True'
ORDER BY CPU, MemoryGB;

-- 5. Find the most memory-intensive VMs per region
SELECT
    Region,
    Name,
    MemoryGB,
    CPU
FROM (
    SELECT
        Region,
        Name,
        MemoryGB,
        CPU,
        ROW_NUMBER() OVER (PARTITION BY Region ORDER BY MemoryGB DESC) AS rn
    FROM dbo.VMSizes
) AS ranked
WHERE rn <= 5
ORDER BY Region, MemoryGB DESC;

-- 6. Compare VM availability across regions
SELECT
    v1.Name,
    COUNT(DISTINCT v1.Region) AS RegionCount,
    STRING_AGG(v1.Region, ', ') AS AvailableInRegions
FROM dbo.VMSizes v1
GROUP BY v1.Name
HAVING COUNT(DISTINCT v1.Region) >= 5
ORDER BY RegionCount DESC;

-- 7. Calculate average specs by region
SELECT
    Region,
    COUNT(*) AS TotalVMs,
    AVG(CAST(CPU AS FLOAT)) AS AvgCPU,
    AVG(MemoryGB) AS AvgMemoryGB,
    AVG(CAST(IOPS AS FLOAT)) AS AvgIOPS
FROM dbo.VMSizes
GROUP BY Region
ORDER BY AvgMemoryGB DESC;

-- 8. Find VMs suitable for storage-intensive workloads
SELECT
    Name,
    IOPS,
    MaxDisks,
    MemoryGB,
    Region
FROM dbo.VMSizes
WHERE IOPS >= 10000 AND MaxDisks >= 16
ORDER BY IOPS DESC;

-- 9. Get VMs with Ephemeral OS Disk support
SELECT
    Name,
    CPU,
    MemoryGB,
    Region,
    EphemeralOSDiskSupported
FROM dbo.VMSizes
WHERE EphemeralOSDiskSupported = 'True'
ORDER BY CPU, MemoryGB;

-- 10. Find VMs by name pattern (e.g., all D-series VMs)
SELECT
    Name,
    CPU,
    MemoryGB,
    Region
FROM dbo.VMSizes
WHERE Name LIKE 'Standard_D%'
ORDER BY CPU, MemoryGB;

-- 11. Get latest updated records
SELECT TOP 100
    Name,
    Region,
    UpdatedDate,
    CPU,
    MemoryGB
FROM dbo.VMSizes
ORDER BY UpdatedDate DESC;

-- 12. Check for duplicate VM names in same region (data quality)
SELECT
    Name,
    Region,
    COUNT(*) AS DuplicateCount
FROM dbo.VMSizes
GROUP BY Name, Region
HAVING COUNT(*) > 1;

-- 13. Get statistics about VM capabilities
SELECT
    'Total VMs' AS Metric,
    COUNT(*) AS Value
FROM dbo.VMSizes
UNION ALL
SELECT
    'Unique VM Names',
    COUNT(DISTINCT Name)
FROM dbo.VMSizes
UNION ALL
SELECT
    'Total Regions',
    COUNT(DISTINCT Region)
FROM dbo.VMSizes
UNION ALL
SELECT
    'VMs with Accelerated Networking',
    COUNT(*)
FROM dbo.VMSizes
WHERE AcceleratedNetworking = 'True'
UNION ALL
SELECT
    'VMs with Ephemeral OS Disk',
    COUNT(*)
FROM dbo.VMSizes
WHERE EphemeralOSDiskSupported = 'True';

-- 14. Find "best value" VMs (high CPU/Memory, available in many regions)
WITH VMMetrics AS (
    SELECT
        Name,
        AVG(CAST(CPU AS FLOAT)) AS AvgCPU,
        AVG(MemoryGB) AS AvgMemory,
        COUNT(DISTINCT Region) AS RegionCount
    FROM dbo.VMSizes
    GROUP BY Name
)
SELECT TOP 20
    Name,
    AvgCPU,
    AvgMemory,
    RegionCount,
    (AvgCPU * AvgMemory * RegionCount) AS ValueScore
FROM VMMetrics
WHERE AvgCPU >= 4
ORDER BY ValueScore DESC;

-- 15. Export data for a specific region (for external analysis)
SELECT
    Name AS 'VM Name',
    CPU,
    MemoryGB AS 'Memory (GB)',
    IOPS,
    MaxNICS AS 'Max NICs',
    MaxDisks AS 'Max Disks',
    AcceleratedNetworking AS 'Accel Network',
    EphemeralOSDiskSupported AS 'Ephemeral OS'
FROM dbo.VMSizes
WHERE Region = 'eastus'
ORDER BY CPU, MemoryGB;
