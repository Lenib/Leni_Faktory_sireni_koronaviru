#--- 1. Promìnná poèasí

#--- 1.1. Pomocná tabulka s konvertovanýma hodnotama - T_convert_weather

CREATE TABLE T_convert_weather AS
SELECT 
	city,
	CASE WHEN city in ('Vienna') THEN 'Wien'
		WHEN city in ('Brussels') THEN 'Bruxelles [Brussel]'
		WHEN city in ('Brussels') THEN 'Bruxelles [Brussel]'
		WHEN city in ('Helsinki') THEN'Helsinki [Helsingfors]'
		WHEN city in ('Athens') THEN'Athenai'
		WHEN city in ('Rome') THEN'Roma'
		WHEN city in ('Luxembourg') THEN'Luxembourg [Luxemburg/L'
		WHEN city in ('Warsaw') THEN'Warszawa'
		WHEN city in ('Lisbon') THEN'Lisboa'
		WHEN city in ('Bucharest') THEN'Bucuresti'
		WHEN city in ('Kiev') THEN'Kyiv'	
		WHEN city in ('Prague') THEN'Praha'		
        ELSE city
        END AS city_new,
		convert(date,date)AS date,
		time,
		wind,
		RANK() OVER (PARTITION BY city, date ORDER BY wind DESC) AS max_wind_rank,
		REPLACE(temp,' °c','') AS temp,
		REPLACE(rain,' mm','') AS rain_mm,
	CASE WHEN time IN ('06:00','09:00','12:00','15:00') THEN 1 ELSE 2 END AS Day_night
FROM weather
WHERE MONTH(date) IN (2,3,4,5,6) AND year(date) IN ('2020') AND city IS NOT NULL

#--- 1.2. Prùmìrná denní (nikoli noèní!) teplota - V_avagarage_daily_temp

CREATE VIEW V_temp_day_Lenka AS
SELECT
	*
FROM T_convert_weather
WHERE day_night in ('1')

CREATE VIEW V_avagarage_daily_temp AS
SELECT
	city,
	date,
	Day_night,
	convert(avg (temp),char) AS Avg_daily_temp
FROM T_convert_weather
GROUP BY city, date

#--- 1.3. poèet hodin v daném dni, kdy byly srážky nenulové - V_Lenka_Rain_hours_during_day

CREATE VIEW V_Lenka_rain_not_null AS
SELECT
	*
FROM T_convert_weather
WHERE rain_mm NOT IN ('0.0')

CREATE VIEW V_Lenka_Rain_hours_during_day AS
SELECT
	city,
	date,
	count (time) AS hours_of_rain_per_day
FROM V_Lenka_rain_not_null
GROUP BY city, date

#--- 1.4. maximální síla vìtru v nárazech bìhem dne - V_Lenka_Max_wind 

CREATE VIEW V_Lenka_Max_wind AS
SELECT
	*
FROM T_convert_weather
WHERE max_wind_rank IN ('1') AND city IS NOT NULL

#--- 1.5. vysvìtlující promìnné: poèasí	 - T_L_Weather_variable
CREATE TABLE T_L_Weather_variable AS
SELECT 
	w.city,
	w.date,
	a.Avg_daily_temp,
	r.hours_of_rain_per_day,
	m.wind as max_wind,
	c.country 
FROM T_convert_weather w
LEFT JOIN V_avagarage_daily_temp a 
LEFT JOIN V_Lenka_Rain_hours_during_day r
ON w.city=r.city AND w.date=r.date
LEFT JOIN V_Lenka_Max_wind m
ON w.city=m.city AND w.date=m.date
LEFT JOIN countries c 
ON w.city_new =c.capital_city 

#--- 2. Promìnná èas

CREATE TABLE T_Lenka_Time_variable AS
SELECT
	country,
	date,
	CASE WHEN WEEKDAY(cbd.date) IN (5, 6) THEN 1 ELSE 0 END AS weekend,
	CASE WHEN month(cbd.date) IN (1,2,3) THEN 1
		WHEN month(cbd.date) IN (4,5,6) THEN 2
		WHEN month(cbd.date) IN (7,8,9) THEN 3
		ELSE 4 END AS quarter
FROM covid19_bASic_differences cbd 
GROUP BY country, date
HAVING month(date) IN (2,3,4,5,6)

#--- 3. Promìnná pro státy

#--- 3.1. Promìnná pro státy - population_density,median_age_2018 V_Lenka_Countries_variable

CREATE VIEW V_Lenka_Countries_variable AS
SELECT
	CASE WHEN country IN ('Czech Republic') THEN ('Czechia')
		WHEN country IN ('Micronesia, Federated States of') THEN 'Micronesia'
      	ELSE country
	END AS country,
	population_density,
	median_age_2018
FROM countries c 
ORDER BY country

#--- 3.2. Promìnná pro státy - rozdíl mezi oèekávanou dobou dožití v roce 1965 a v roce 2015 - 	V_Lenka_life_expectancy_variable

CREATE VIEW V_Lenka_life_expectancy_variable AS
SELECT 
	CASE WHEN a.country IN ('Czech Republic') THEN ('Czechia')
		WHEN a.country IN ('Micronesia (country)') THEN 'Micronesia'
      ELSE a.country
     END AS country, 
	a.life_exp_1965, 
	b.life_exp_2015,
    ROUND( b.life_exp_2015 - a.life_exp_1965, 2 ) AS life_exp_diff
FROM(
    SELECT 
	le.country , 
	year,
	le.life_expectancy AS life_exp_1965
    FROM life_expectancy le 
    WHERE year = 1965
    ) a JOIN (
    SELECT 
		le.country , 
		year,
		le.life_expectancy AS life_exp_2015
    FROM life_expectancy le
    WHERE year = 2015
    ) b
    ON a.country = b.country
    GROUP BY country


#--- 3.3. Promìnná pro státy - HDP na obyvatele, GINI koeficient, dìtská úmrtnost (mortality_under5) - V_Lenka_economies_variables

CREATE VIEW V_Lenka_economies_variables AS
SELECT
	CASE WHEN country IN ('Czech Republic') THEN ('Czechia')
		WHEN country IN ('Micronesia, Fed. Sts.') THEN 'Micronesia'
      ELSE country
     END AS country, 
	population,
	year,
	GINI,
	GDP,
	mortaliy_under5 
FROM economies e
WHERE year IN ('2020')

#--- 3.4. Promìnná pro státy  - podíly jednotlivých náboženství - v_Lenka_religion_variable

CREATE VIEW v_Lenka_religion_variable AS
SELECT 
	CASE WHEN r.country in ('Czech Republic') THEN ('Czechia')
		WHEN r.country in ('Micronesia, Federated States of') THEN 'Micronesia'
      ELSE r.country
     END AS country,
		r.religion, 
    ROUND( r.population / r2.total_population_2020 * 100, 2 ) AS religion_share_2020
FROM religions r 
JOIN (
        SELECT 
        	r.country , 
        	r.year,  
        	sum(r.population) AS total_population_2020
        FROM religions r 
        WHERE r.year = 2020 
        GROUP BY r.country
    ) r2
    ON r.country = r2.country
    AND r.year = r2.year
    AND r.population > 0


#--- 3.5. Promìnná pro státy  - všechny promìnné - T_Lenka_countries_all_variables

CREATE TABLE T_Lenka_countries_variables AS 
SELECT
	c.country,
	c.population_density,
	c.median_age_2018,
	l.life_exp_diff,
	e.gini,
	e.GDP,
	e.mortaliy_under5 AS mortality_under5,
	r.religion,
	r.religion_share_2020
FROM V_Lenka_Countries_variable c
LEFT JOIN V_Lenka_life_expectancy_variable l
ON c.country=l.country
LEFT JOIN V_Lenka_economies_variables e
ON c.country=e.country
LEFT JOIN v_Lenka_religion_variable r
ON e.country=r.country

#--- 4.Vysvìtlovanná promìnná - Poèty nakažených (denní nárusty nakažených), Poèty provedených testù, Poèet obyvatel v daných státech  - T_Lenka_tests_cases_population

#--- 4.1.Vysvìtlovanná promìnná - Poèty nakažených (denní nárusty nakažených) - T_Lenka_Cases

CREATE TABLE T_Lenka_Cases AS
SELECT
	REPLACE(country,'*','') AS country,
	date,
	confirmed 
FROM covid19_bASic_differences cbd  
HAVING month(date) IN (2,3,4,5,6) AND confirmed NOT IN ('0')
ORDER BY country, date

#--- 4.2. Vysvìtlovanná promìnná - Poèty provedených testù - T_Lenka_Tests_per_day

CREATE TABLE T_Lenka_Tests_per_day  AS
SELECT	
	CASE WHEN country IN ('Czech Republic') THEN 'Czechia'
		WHEN country IN ('South Korea') THEN 'Korea, South'
		WHEN country IN ('United States') THEN 'US'		
        ELSE country 
        END AS country,
        date,
	entity,
	tests_performed 
FROM covid19_tests ct
WHERE tests_performed IS NOT NULL AND entity LIKE'%test%'
GROUP BY country, date
ORDER BY country

#--- 4.3.Vysvìtlovanná promìnná - Poèet obyvatel v daných státech - T_Lenka_population_by_country

CREATE TABLE T_Lenka_population_by_country AS
SELECT
	CASE WHEN country IN ('Micronesia, Fed. Sts.') THEN ('Micronesia')
		WHEN country IN ('Czech Republic') THEN 'Czechia'
		WHEN country LIKE ('Korea, Dem. People%') THEN 'Korea, South'		 
	ELSE country 
        END AS country,
	year,
	population,
	ROUND(population/100000) AS population_per_100000
FROM economies e 
WHERE `year` IN ('2020') AND population IS NOT NULL
ORDER BY country

#--- 4.4. Vysvìtlovanná promìnná - Poèty nakažených (denní nárusty nakažených), Poèty provedených testù, Poèet obyvatel v daných státech  - T_Lenka_tests_cases_population

CREATE TABLE T_Lenka_tests_Cases_population AS
SELECT 
	c.country,
	c.date,
	c.confirmed,
	t.entity,
	t.tests_performed,
	p.population,
	p.population_per_100000,
	round((t.tests_performed /c.confirmed),2) AS ratio_confirmed_tested,
	 round(((t.tests_performed /c.confirmed)/p.population_per_100000),2)AS Ratio_Confirmed_tested_per_population_100000
FROM T_Lenka_Cases c
LEFT JOIN T_Lenka_Tests_per_day t
ON c.country=t.country AND c.date=t.date
LEFT JOIN T_Lenka_population_by_country p
ON c.country=p.country

#--- 5. Finální data - t_Lenka_Baklikova_projekt_SQL_final

CREATE TABLE t_Lenka_Baklikova_projekt_SQL_final AS
SELECT 
	p.country,
	p.date,
	p.confirmed,
	p.entity,
	p.tests_performed,
	p.population,
	p.population_per_100000,
	p.ratio_confirmed_tested,
	p.Ratio_Confirmed_tested_per_population_100000,
	t.weekend,
	t.quarter,
	c.population_density,
	c.median_age_2018,
	c.life_exp_diff,
	c.GINI,
	c.GDP,
	c.mortality_under5,
	c.religion,
	c.religion_share_2020,
	w.Avg_daily_temp,
	w.hours_of_rain_per_day,
	w.max_wind
FROM T_Lenka_tests_cases_population p
LEFT JOIN T_L_Weather_variable w
ON p.country=w.country AND p.date=w.date
LEFT JOIN T_Lenka_Time_variable t 
ON p.country=t.country AND p.date=t.date
LEFT JOIN T_Lenka_countries_variables c
ON p.country=c.country





