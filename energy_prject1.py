import psycopg2
import random
from datetime import datetime, timedelta
import pandas as pd

# ============================================================
# CONNECTION - CHANGE YOUR PASSWORD HERE!
# ============================================================
conn = psycopg2.connect(
    host="localhost",
    database="energy_intelligence_project1",
    user="postgres",
    password="Solovigo123DELLYS"  # <--- CHANGE TO YOUR PASSWORD
)
cur = conn.cursor()

print("="*60)
print("🚀 STARTING DATA GENERATION FOR 50 BUILDINGS")
print("="*60)

# ============================================================
# 1. BUILDINGS (50 rows)
# ============================================================
print("\n📋 Step 1: Inserting 50 buildings...")

cities = ['Paris', 'Lyon', 'Marseille', 'Toulouse', 'Nice', 'Nantes', 'Bordeaux', 'Lille']
building_types = ['office', 'retail', 'warehouse', 'school', 'hospital']
hvac_types = ['central', 'split', 'heat_pump', 'chiller']

for i in range(1, 51):
    city = random.choice(cities)
    cur.execute("""
        INSERT INTO buildings (
            building_name, address, city, state, country,
            building_type, floor_area_m2, construction_year,
            occupancy_rate, hvac_type
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        f'Building_{i}',
        f'{i} Rue de la Paix',
        city,
        'Ile-de-France',  # <--- FIXED: Removed accent
        'France',
        random.choice(building_types),
        random.randint(1000, 20000),
        random.randint(1970, 2024),
        round(random.uniform(40, 95), 2),
        random.choice(hvac_types)
    ))

conn.commit()
print("   ✅ 50 buildings inserted")

# ============================================================
# 2. ENERGY TARIFFS (3 rows)
# ============================================================
print("\n💰 Step 2: Inserting tariffs...")

cur.execute("""
    INSERT INTO energy_tariffs (
        tariff_name, utility_name, effective_from, effective_to,
        price_per_kwh, peak_price_per_kwh, offpeak_price_per_kwh,
        daily_fixed_fee, demand_charge_per_kw, currency, time_of_use_season
    ) VALUES 
    ('Standard Commercial Summer', 'EDF', '2023-01-01', '2023-09-30', 
     0.12, 0.18, 0.08, 2.50, 15.00, 'EUR', 'summer'),
    ('Standard Commercial Winter', 'EDF', '2023-10-01', '2024-03-31', 
     0.14, 0.20, 0.10, 2.50, 18.00, 'EUR', 'winter'),
    ('Standard Commercial Summer', 'EDF', '2024-01-01', '2024-09-30', 
     0.13, 0.19, 0.09, 2.75, 16.00, 'EUR', 'summer')
""")
conn.commit()
print("   ✅ 3 tariffs inserted")

# ============================================================
# 3. WEATHER DATA (36,500 rows)
# ============================================================
print("\n🌤️ Step 3: Generating weather data...")

start_date = datetime(2023, 1, 1)
end_date = datetime(2024, 12, 31)
current_date = start_date
weather_conditions = ['sunny', 'cloudy', 'rainy', 'partly_cloudy']
weather_count = 0

city_temp_bases = {
    'Paris': {'base': 10, 'amplitude': 12},
    'Lyon': {'base': 11, 'amplitude': 13},
    'Marseille': {'base': 14, 'amplitude': 15},
    'Toulouse': {'base': 12, 'amplitude': 14},
    'Nice': {'base': 15, 'amplitude': 15},
    'Nantes': {'base': 10, 'amplitude': 11},
    'Bordeaux': {'base': 11, 'amplitude': 12},
    'Lille': {'base': 8, 'amplitude': 10}
}

cur.execute("SELECT building_id, city FROM buildings")
buildings_cities = cur.fetchall()
building_city_map = {b[0]: b[1] for b in buildings_cities}

while current_date <= end_date:
    for building_id, city in building_city_map.items():
        month = current_date.month
        base = city_temp_bases[city]['base']
        amplitude = city_temp_bases[city]['amplitude']
        
        temp_avg = base + amplitude * ((month - 7) / 6) + random.uniform(-3, 3)
        temp_min = temp_avg - random.uniform(2, 5)
        temp_max = temp_avg + random.uniform(2, 5)
        
        hdd = max(0, 18 - temp_avg)
        cdd = max(0, temp_avg - 18)
        
        cur.execute("""
            INSERT INTO weather_data (
                building_id, weather_date, temperature_avg, temperature_min, temperature_max,
                heating_degree_days, cooling_degree_days, humidity_avg,
                precipitation_mm, wind_speed_mps, weather_condition
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            building_id,
            current_date.date(),
            round(temp_avg, 1),
            round(temp_min, 1),
            round(temp_max, 1),
            round(hdd, 1),
            round(cdd, 1),
            round(50 + 30 * random.random(), 1),
            round(0 + 8 * random.random(), 1),
            round(2 + 6 * random.random(), 1),
            random.choice(weather_conditions)
        ))
        weather_count += 1
        
        if weather_count % 5000 == 0:
            conn.commit()
            print(f"   Weather: {weather_count} rows...")
    
    current_date += timedelta(days=1)

conn.commit()
print(f"   ✅ {weather_count:,} weather records inserted")

# ============================================================
# 4. BUILDING METADATA (50 rows)
# ============================================================
print("\n📋 Step 4: Inserting building_metadata...")

occupancy_types = ['office_hours', '24_7', 'seasonal', 'flexible']
lighting_types = ['led', 'fluorescent', 'halogen']

for building_id in range(1, 51):
    cur.execute("""
        INSERT INTO building_metadata (
            building_id, occupancy_type, occupancy_hours_per_day,
            number_of_occupants, lighting_type, lighting_power_kw,
            equipment_power_kw, hvac_type, hvac_capacity_kw,
            operating_schedule, holiday_schedule, notes
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        building_id,
        random.choice(occupancy_types),
        random.choice([8, 10, 12, 16, 24]),
        random.randint(10, 500),
        random.choice(lighting_types),
        round(random.uniform(2, 20), 1),
        round(random.uniform(5, 50), 1),
        random.choice(['central', 'split', 'heat_pump']),
        round(random.uniform(50, 500), 1),
        '{"monday":"8-18","tuesday":"8-18","wednesday":"8-18","thursday":"8-18","friday":"8-18","saturday":"closed","sunday":"closed"}',
        '{"2024-01-01":"new_year","2024-12-25":"christmas"}',
        'Generated metadata'
    ))

conn.commit()
print("   ✅ 50 metadata records inserted")

# ============================================================
# 5. ENERGY READINGS (1.7M rows)
# ============================================================
print("\n⚡ Step 5: Generating energy readings...")
print("   ⏳ This takes ~10 minutes...")

start_time = datetime(2023, 1, 1)
end_time = datetime(2024, 12, 31)
current_time = start_time
readings_count = 0

cur.execute("SELECT building_id, floor_area_m2 FROM buildings")
buildings_floor = cur.fetchall()
base_loads = {b[0]: 0.5 + (b[1] / 20000) * 10 for b in buildings_floor}

while current_time <= end_time:
    for building_id in range(1, 51):
        hour = current_time.hour
        month = current_time.month
        day_of_week = current_time.weekday()
        
        base_load = base_loads[building_id]
        seasonal_factor = 1 + 0.4 * ((month - 7) / 6)
        
        if 8 <= hour <= 18:
            daily_factor = 1.5 + 0.3 * ((hour - 8) / 10)
        elif 6 <= hour < 8:
            daily_factor = 0.8 + 0.7 * ((hour - 6) / 2)
        elif 18 < hour <= 20:
            daily_factor = 1.5 - 0.5 * ((hour - 18) / 2)
        else:
            daily_factor = 0.4 + 0.2 * random.random()
        
        if day_of_week >= 5:
            daily_factor = daily_factor * 0.5
        
        consumption = base_load * seasonal_factor * daily_factor * (1 + random.normalvariate(0, 0.1))
        consumption = max(0.1, consumption)
        demand = consumption * random.uniform(1.0, 1.3)
        
        if 8 <= hour <= 18 and day_of_week < 5:
            price = 0.18
        else:
            price = 0.08
        cost = consumption * price
        
        cur.execute("""
            INSERT INTO energy_readings (
                building_id, timestamp, energy_kwh, demand_kw, cost_eur,
                temperature_celsius, humidity_percent, is_peak_flag, quality_flag, source
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            building_id,
            current_time,
            round(consumption, 2),
            round(demand, 2),
            round(cost, 2),
            round(10 + 20 * random.random(), 1),
            round(40 + 40 * random.random(), 1),
            demand > base_load * 3,
            'good',
            'utility'
        ))
        readings_count += 1
        
        if readings_count % 50000 == 0:
            conn.commit()
            print(f"   Readings: {readings_count:,} rows...")
    
    current_time += timedelta(minutes=15)

conn.commit()
print(f"   ✅ {readings_count:,} energy readings inserted")

# ============================================================
# 6. PEAK DEMAND (36,500 rows)
# ============================================================
print("\n📈 Step 6: Calculating peak_demand...")

cur.execute("""
    INSERT INTO peak_demand (building_id, peak_date, peak_start_time, peak_end_time, demand_kw, cost_impact_eur)
    SELECT 
        building_id,
        timestamp::DATE AS peak_date,
        timestamp AS peak_start_time,
        timestamp + INTERVAL '15 minutes' AS peak_end_time,
        demand_kw,
        demand_kw * 15.00 AS cost_impact_eur
    FROM energy_readings er
    WHERE er.demand_kw = (
        SELECT MAX(demand_kw) 
        FROM energy_readings er2 
        WHERE er2.building_id = er.building_id 
        AND er2.timestamp::DATE = er.timestamp::DATE
    )
    ON CONFLICT (peak_id) DO NOTHING
""")
conn.commit()
print("   ✅ Peak demand calculated")

# ============================================================
# 7. ANOMALIES (30 rows)
# ============================================================
print("\n🚨 Step 7: Detecting anomalies...")

cur.execute("""
    INSERT INTO anomalies (building_id, reading_id, anomaly_type, severity, 
                           anomaly_score, description, root_cause, cost_impact_eur, status)
    SELECT 
        er.building_id,
        er.reading_id,
        'weekend_waste' AS anomaly_type,
        'high' AS severity,
        ROUND(70 + 25 * RANDOM(), 2) AS anomaly_score,
        'Weekend waste detected in Building ' || er.building_id || ' at ' || er.timestamp::TEXT AS description,
        'schedule_error' AS root_cause,
        ROUND(er.energy_kwh * 0.15, 2) AS cost_impact_eur,
        'open' AS status
    FROM energy_readings er
    WHERE er.building_id IN (3, 17, 42)
    AND EXTRACT(DOW FROM er.timestamp) IN (0, 6)
    AND EXTRACT(HOUR FROM er.timestamp) BETWEEN 8 AND 18
    LIMIT 30
""")
conn.commit()
print("   ✅ Anomalies detected")

# ============================================================
# 8. RECOMMENDATIONS (10 rows)
# ============================================================
print("\n💡 Step 8: Generating recommendations...")

cur.execute("""
    INSERT INTO recommendations (building_id, anomaly_id, recommendation_text,
                                 estimated_savings_eur, implementation_cost_eur,
                                 roi_percentage, priority, status)
    SELECT 
        a.building_id,
        a.anomaly_id,
        'Install timer switches to reduce weekend HVAC usage in Building ' || a.building_id AS recommendation_text,
        ROUND(200 + 800 * RANDOM(), 2) AS estimated_savings_eur,
        ROUND(500 + 2000 * RANDOM(), 2) AS implementation_cost_eur,
        ROUND(50 + 250 * RANDOM(), 2) AS roi_percentage,
        'high' AS priority,
        'pending' AS status
    FROM anomalies a
    WHERE a.anomaly_type = 'weekend_waste'
    LIMIT 10
""")
conn.commit()
print("   ✅ Recommendations generated")

# ============================================================
# FINAL VERIFICATION
# ============================================================
print("\n" + "="*60)
print("🎉 ALL DATA GENERATED SUCCESSFULLY!")
print("="*60)

cur.execute("""
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
    SELECT 'recommendations', COUNT(*) FROM recommendations
    ORDER BY row_count DESC
""")

for row in cur.fetchall():
    print(f"   {row[0]}: {row[1]:,} rows")

# ============================================================
# CLOSE CONNECTION
# ============================================================
cur.close()
conn.close()

print("\n✅ Database fully populated!")
print("⏱️ Total time: ~30 minutes")