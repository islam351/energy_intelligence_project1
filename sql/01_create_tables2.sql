-- 1. Buildings table
CREATE TABLE buildings (
    building_id SERIAL PRIMARY KEY,
    building_name VARCHAR(100) NOT NULL,
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    building_type VARCHAR(50),
    floor_area_m2 DECIMAL(10,2),
    construction_year INT,
    occupancy_rate DECIMAL(5,2),
    hvac_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Energy Readings table
CREATE TABLE energy_readings (
    reading_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    timestamp TIMESTAMP NOT NULL,
    energy_kwh DECIMAL(10,3),
    demand_kw DECIMAL(10,3),
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    source VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Energy Tariffs table
CREATE TABLE energy_tariffs (
    tariff_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    tariff_name VARCHAR(100),
    effective_from DATE,
    effective_to DATE,
    price_per_kwh DECIMAL(10,4),
    peak_price_per_kwh DECIMAL(10,4),
    offpeak_price_per_kwh DECIMAL(10,4),
    daily_fixed_fee DECIMAL(10,2),
    demand_charge_per_kwh DECIMAL(10,2),
    currency VARCHAR(3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Peak Demand table
CREATE TABLE peak_demand (
    peak_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    peak_date DATE,
    peak_start_time TIME,
    peak_end_time TIME,
    energy_kwh DECIMAL(12,3),
    demand_kw DECIMAL(10,3),
    cost_impact_eur DECIMAL(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Weather Data table
CREATE TABLE weather_data (
    weather_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    weather_date DATE,
    temperature_avg DECIMAL(5,2),
    temperature_min DECIMAL(5,2),
    temperature_max DECIMAL(5,2),
    humidity_avg DECIMAL(5,2),
    precipitation DECIMAL(10,2),
    wind_speed DECIMAL(5,2),
    weather_condition VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Building Metadata table
CREATE TABLE building_metadata (
    metadata_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    occupancy_type VARCHAR(50),
    occupancy_hours_per_day DECIMAL(5,2),
    number_of_occupants INT,
    lighting_type VARCHAR(50),
    lighting_power_kw DECIMAL(10,3),
    equipment_power_kw DECIMAL(10,3),
    hvac_type VARCHAR(50),
    hvac_capacity_kw DECIMAL(10,3),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Energy Forecasts table
CREATE TABLE energy_forecasts (
    forecast_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    forecast_timestamp TIMESTAMP,
    forecast_horizon VARCHAR(20),
    forecast_energy_kwh DECIMAL(12,3),
    forecast_demand_kw DECIMAL(10,3),
    model_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Anomalies table
CREATE TABLE anomalies (
    anomaly_id SERIAL PRIMARY KEY,
    building_id INT REFERENCES buildings(building_id),
    reading_id INT REFERENCES energy_readings(reading_id),
    description TEXT,
    detected_at TIMESTAMP,
    status VARCHAR(20),
    cost_impact_eur DECIMAL(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
