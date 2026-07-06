-- 1) Is the data complete and reliable?
-- 1.1 Row Counts (All Tables)
SELECT 
    'buildings' AS table_name, COUNT(*) AS row_count FROM buildings
UNION ALL
SELECT 'energy_tariffs', COUNT(*) FROM energy_tariffs
UNION ALL
SELECT 'building_metadata', COUNT(*) FROM building_metadata
UNION ALL
SELECT 'weather_data', COUNT(*) FROM weather_data
UNION ALL
SELECT 'energy_readings', COUNT(*) FROM energy_readings
UNION ALL
SELECT 'peak_demand', COUNT(*) FROM peak_demand
UNION ALL
SELECT 'anomalies', COUNT(*) FROM anomalies
UNION ALL
SELECT 'energy_forecasts', COUNT(*) FROM energy_forecasts
UNION ALL
SELECT 'recommendations', COUNT(*) FROM recommendations
ORDER BY row_count DESC;

-- 1.2 Orphaned Readings Check
SELECT COUNT(*) AS orphaned_readings
FROM energy_readings er
LEFT JOIN buildings b ON er.building_id = b.building_id
WHERE b.building_id IS NULL;

-- 1.3 Date Range Check
SELECT 
    MIN(timestamp) AS first_reading,
    MAX(timestamp) AS last_reading,
    COUNT(DISTINCT building_id) AS total_buildings,
    COUNT(*) AS total_readings
FROM energy_readings;

--2)Which buildings are inefficient?
SELECT 
    b.building_id,
    b.building_name,
    ROUND(SUM(er.energy_kwh), 2) AS total_kwh,
    ROUND(MAX(er.demand_kw), 2) AS peak_demand,
    ROUND(AVG(er.demand_kw), 2) AS avg_demand,
    COUNT(*) AS total_intervals,
    ROUND(COUNT(*) * 0.25, 0) AS total_hours,
    ROUND(
        (SUM(er.energy_kwh) / (MAX(er.demand_kw) * (COUNT(*) * 0.25))) * 100, 
        2
    ) AS load_factor_percent,
    CASE 
        WHEN (SUM(er.energy_kwh) / (MAX(er.demand_kw) * (COUNT(*) * 0.25))) > 0.6 THEN 'Efficient'
        WHEN (SUM(er.energy_kwh) / (MAX(er.demand_kw) * (COUNT(*) * 0.25))) > 0.4 THEN 'Average'
        ELSE 'Inefficient'
    END AS efficiency_rating
FROM energy_readings er
JOIN buildings b ON er.building_id = b.building_id
GROUP BY b.building_id, b.building_name
ORDER BY load_factor_percent ASC;

--3) Which buildings have highest peak demand?
SELECT
    b.building_name,
    MAX(er.demand_kw) AS max_demand_kw
FROM energy_readings er
JOIN buildings b
    ON er.building_id = b.building_id
GROUP BY b.building_name
ORDER BY max_demand_kw DESC;

--4) What are the exact timestamps of waste events?
SELECT 
    b.building_name,
    a.anomaly_type,
    a.severity,
    a.description,
    a.cost_impact_eur,
    a.detected_at
FROM anomalies a
JOIN buildings b ON a.building_id = b.building_id
ORDER BY a.cost_impact_eur DESC;
 
--5) Which type of buildings consume the most?
SELECT
    building_type,
    ROUND(SUM(er.energy_kwh),2) AS total_energy
FROM energy_readings er
JOIN buildings b
    ON er.building_id = b.building_id
GROUP BY building_type
ORDER BY total_energy DESC;


--6)  How much does Building_31 pay in demand charges per month and year?
WITH monthly_peaks AS (
    SELECT 
        DATE_TRUNC('month', peak_date) AS month,
        MAX(demand_kw) AS monthly_peak_kw
    FROM peak_demand
    WHERE building_id = 31
    GROUP BY DATE_TRUNC('month', peak_date)
)
SELECT 
    TO_CHAR(month, 'YYYY-MM') AS month,
    ROUND(monthly_peak_kw, 2) AS monthly_peak_kw,
    ROUND(monthly_peak_kw * 15.00, 2) AS monthly_demand_charge_eur,
    ROUND(SUM(monthly_peak_kw * 15.00) OVER (), 2) AS annual_demand_charge_eur
FROM monthly_peaks
ORDER BY month;

--7)  What are the total annual demand charges for all buildings?
WITH monthly_peaks AS (
    SELECT 
        building_id,
        EXTRACT(YEAR FROM peak_date) AS year,
        DATE_TRUNC('month', peak_date) AS month,
        MAX(demand_kw) AS monthly_max_demand_kw
    FROM peak_demand
    GROUP BY building_id, EXTRACT(YEAR FROM peak_date), DATE_TRUNC('month', peak_date)
)
SELECT 
    b.building_name,
    mp.year,
    COUNT(*) AS months_with_peaks,
    ROUND(SUM(mp.monthly_max_demand_kw * 15.00), 2) AS annual_demand_charge_eur
FROM monthly_peaks mp
JOIN buildings b ON mp.building_id = b.building_id
GROUP BY b.building_name, mp.year
ORDER BY annual_demand_charge_eur DESC;

--8)  Is the portfolio improving or getting worse?
 WITH monthly_peaks AS (
    SELECT 
        building_id,
        EXTRACT(YEAR FROM peak_date) AS year,
        DATE_TRUNC('month', peak_date) AS month,
        MAX(demand_kw) AS monthly_max_demand_kw
    FROM peak_demand
    GROUP BY building_id, EXTRACT(YEAR FROM peak_date), DATE_TRUNC('month', peak_date)
),
annual_demand AS (
    SELECT 
        building_id,
        year,
        ROUND(SUM(monthly_max_demand_kw * 15.00), 2) AS annual_demand_charge_eur
    FROM monthly_peaks
    GROUP BY building_id, year
)
SELECT 
    b.building_name,
    ad.year,
    ad.annual_demand_charge_eur,
    LAG(ad.annual_demand_charge_eur) OVER (PARTITION BY b.building_id ORDER BY ad.year) AS previous_year,
    ROUND(
        (ad.annual_demand_charge_eur - LAG(ad.annual_demand_charge_eur) OVER (PARTITION BY b.building_id ORDER BY ad.year)) / 
        NULLIF(LAG(ad.annual_demand_charge_eur) OVER (PARTITION BY b.building_id ORDER BY ad.year), 0) * 100, 
        2
    ) AS yoy_change_percent
FROM annual_demand ad
JOIN buildings b ON ad.building_id = b.building_id
ORDER BY ad.annual_demand_charge_eur DESC;

--9)  What is the total annual cost for each building?
WITH annual_energy AS (
    SELECT 
        b.building_id,
        b.building_name,
        EXTRACT(YEAR FROM er.timestamp) AS year,
        ROUND(SUM(er.energy_kwh) * 0.12, 2) AS energy_cost_eur
    FROM energy_readings er
    JOIN buildings b ON er.building_id = b.building_id
    GROUP BY b.building_id, b.building_name, EXTRACT(YEAR FROM er.timestamp)
),
monthly_peaks AS (
    SELECT 
        building_id,
        EXTRACT(YEAR FROM peak_date) AS year,
        DATE_TRUNC('month', peak_date) AS month,
        MAX(demand_kw) AS monthly_max_demand_kw
    FROM peak_demand
    GROUP BY building_id, EXTRACT(YEAR FROM peak_date), DATE_TRUNC('month', peak_date)
),
annual_demand AS (
    SELECT 
        building_id,
        year,
        ROUND(SUM(monthly_max_demand_kw * 15.00), 2) AS demand_charge_eur
    FROM monthly_peaks
    GROUP BY building_id, year
)
SELECT 
    ae.building_name,
    ae.year,
    ae.energy_cost_eur,
    ad.demand_charge_eur,
    912.50 AS fixed_fees_eur,
    ROUND(ae.energy_cost_eur + ad.demand_charge_eur + 912.50, 2) AS total_annual_bill_eur
FROM annual_energy ae
JOIN annual_demand ad ON ae.building_id = ad.building_id AND ae.year = ad.year
ORDER BY total_annual_bill_eur DESC;

--10) How much of the bill is from demand charges?
WITH annual_energy AS (
    SELECT 
        b.building_id,
        b.building_name,
        EXTRACT(YEAR FROM er.timestamp) AS year,
        ROUND(SUM(er.energy_kwh) * 0.12, 2) AS energy_cost_eur
    FROM energy_readings er
    JOIN buildings b ON er.building_id = b.building_id
    GROUP BY b.building_id, b.building_name, EXTRACT(YEAR FROM er.timestamp)
),
monthly_peaks AS (
    SELECT 
        building_id,
        EXTRACT(YEAR FROM peak_date) AS year,
        DATE_TRUNC('month', peak_date) AS month,
        MAX(demand_kw) AS monthly_max_demand_kw
    FROM peak_demand
    GROUP BY building_id, EXTRACT(YEAR FROM peak_date), DATE_TRUNC('month', peak_date)
),
annual_demand AS (
    SELECT 
        building_id,
        year,
        ROUND(SUM(monthly_max_demand_kw * 15.00), 2) AS demand_charge_eur
    FROM monthly_peaks
    GROUP BY building_id, year
)
SELECT 
    ae.building_name,
    ae.year,
    ae.energy_cost_eur,
    ad.demand_charge_eur,
    ROUND(ae.energy_cost_eur + ad.demand_charge_eur + 912.50, 2) AS total_bill_eur,
    ROUND((ad.demand_charge_eur / (ae.energy_cost_eur + ad.demand_charge_eur + 912.50)) * 100, 2) AS demand_percentage_of_bill
FROM annual_energy ae
JOIN annual_demand ad ON ae.building_id = ad.building_id AND ae.year = ad.year
ORDER BY demand_percentage_of_bill DESC;

--11) Which buildings consume the most energy per square meter?
SELECT
    b.building_name,
    ROUND(
        SUM(er.energy_kwh) / b.floor_area_m2,
        2
    ) AS kwh_per_m2
FROM energy_readings er
JOIN buildings b
    ON er.building_id = b.building_id
GROUP BY
    b.building_name,
    b.floor_area_m2
ORDER BY kwh_per_m2 DESC;

--12)Does occupancy explain energy use?
SELECT
    b.building_name,
    b.occupancy_rate,
    ROUND(SUM(er.energy_kwh),2) AS total_energy
FROM buildings b
JOIN energy_readings er
    ON b.building_id = er.building_id
GROUP BY
    b.building_name,
    b.occupancy_rate
ORDER BY total_energy DESC;

--13)"How to detect energy waste and forecast consumption for commercial buildings?"
WITH anomaly_summary AS (
    SELECT 
        b.building_name,
        COUNT(*) AS anomaly_count,
        ROUND(SUM(a.cost_impact_eur), 2) AS total_cost_2years
    FROM anomalies a
    JOIN buildings b ON a.building_id = b.building_id
    GROUP BY b.building_name
)
SELECT 
    building_name,
    anomaly_count,
    total_cost_2years,
    ROUND(total_cost_2years * 52 / 2, 2) AS annual_projection_eur,
    ROUND(total_cost_2years * 52 / 2 * 50 / 3, 2) AS portfolio_projection_eur
FROM anomaly_summary;
