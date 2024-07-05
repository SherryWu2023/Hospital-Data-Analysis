#This project is about a dataset from a hospital where there are an encounter table, a payer table, 
#a patient table and a procedures table. The following are queries used to explore the dataset and 
#extract insights. 

#How many patients visited every year   
SELECT EXTRACT(YEAR FROM START) AS YEAR,
      COUNT (DISTINCT patient) as num_patient
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY YEAR
ORDER BY YEAR

#How many different patients ever visited the hospital
SELECT COUNT (DISTINCT patient) as num_patient
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`


#How many patients and how much hospital received from different encounter classes?
SELECT ENCOUNTERCLASS,COUNT(Id) AS NUM_ENCOUNTER,
       ROUND(SUM(TOTAL_CLAIM_COST),2) AS COST,
       ROUND(SUM(PAYER_COVERAGE),2) AS COVERAGE,
       ROUND((SUM(TOTAL_CLAIM_COST)-SUM(PAYER_COVERAGE)),2) AS PATIENT_PAYMENT,
       ROUND(((SUM(PAYER_COVERAGE)/SUM(TOTAL_CLAIM_COST))*100),2) AS COVER_PERCENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY ENCOUNTERCLASS
ORDER BY NUM_ENCOUNTER DESC


#What is the revenue of hospital ,payer coverage and patient payment?
SELECT 
       ROUND(SUM(TOTAL_CLAIM_COST),2) AS COST,
       ROUND(SUM(PAYER_COVERAGE),2) AS COVERAGE,
       ROUND((SUM(TOTAL_CLAIM_COST)-SUM(PAYER_COVERAGE)),2) AS PATIENT_PAYMENT      
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`


#How many patients and how much hospital received from different procedures?
SELECT DESCRIPTION,COUNT(Id) AS NUM_ENCOUNTER,
       ROUND(SUM(TOTAL_CLAIM_COST),2) AS COST,
       ROUND(SUM(PAYER_COVERAGE),2) AS COVERAGE,
       ROUND((SUM(TOTAL_CLAIM_COST)-SUM(PAYER_COVERAGE)),2) AS PATIENT_PAYMENT,
       ROUND(((SUM(PAYER_COVERAGE)/SUM(TOTAL_CLAIM_COST))*100),2) AS COVER_PERCENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
WHERE TOTAL_CLAIM_COST>0
GROUP BY DESCRIPTION
ORDER BY COST DESC


#What are the reasons why patients visited the hospital
SELECT DESCRIPTION, COUNT(PATIENT) AS NUM_PATIENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY DESCRIPTION
ORDER BY NUM_PATIENT DESC


#How many patients have been admitted or readmitted every year
SELECT 
       YEAR,
       SUM(CASE WHEN sub.num_admission=1 THEN 1 END) as admitted_patient,
       SUM(CASE WHEN sub.num_admission>1 THEN 1 END) as readmitted_patient,
       
FROM (SELECT EXTRACT(YEAR FROM START) AS YEAR,PATIENT, count(Id) as num_admission
      FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 
      WHERE lower(DESCRIPTION) like '%admission%'
      GROUP BY PATIENT,YEAR) as sub
GROUP BY YEAR
ORDER BY YEAR


#What is the 30-day readmission rate?
WITH discharged_patients AS (
    SELECT 
        PATIENT,
        MIN(STOP) AS DISCHARGE_DATE,
        COUNT(*) AS DISCHARGE_COUNT
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
    WHERE LOWER(description) LIKE '%admission%'
    GROUP BY PATIENT
),
readmitted_patients AS (
    SELECT 
        PATIENT,
        START AS READMISSION_DATE
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
    WHERE LOWER(description) LIKE '%admission%'
)
SELECT 
    COUNT(d.PATIENT) AS total_discharged,
    COUNT(r.PATIENT) AS total_readmitted,
    ROUND((COUNT(r.PATIENT) / COUNT(d.PATIENT)) * 100, 2) AS readmission_rate
FROM 
    discharged_patients d
LEFT JOIN 
    readmitted_patients r
ON 
    d.PATIENT = r.PATIENT 
    AND r.READMISSION_DATE BETWEEN d.DISCHARGE_DATE AND DATE_ADD(d.DISCHARGE_DATE, INTERVAL 30 DAY);


#What is the 30-day readmission rate for different age groups?
WITH PATIENTS AS (
    SELECT
        Id, 
        CASE 
            WHEN s.DEATHDATE IS NOT NULL THEN DATETIME_DIFF(s.DEATHDATE, s.BIRTHDATE, YEAR)
            ELSE DATETIME_DIFF(CURRENT_DATETIME(), s.BIRTHDATE, YEAR)
        END AS PATIENT_AGE
    FROM `leafy-chariot-427609-e8.HospitalDataset.patients` s
),
ENCOUNTERS AS (
    SELECT 
        e.PATIENT,
        e.TOTAL_CLAIM_COST,
        e.PAYER_COVERAGE,
        CASE 
            WHEN p.PATIENT_AGE <21 THEN 'BELOW 21'
            WHEN p.PATIENT_AGE BETWEEN 21 AND 30 THEN '21-30'
            WHEN p.PATIENT_AGE BETWEEN 31 AND 40 THEN '31-40'
            WHEN p.PATIENT_AGE BETWEEN 41 AND 50 THEN '41-50'
            WHEN p.PATIENT_AGE BETWEEN 51 AND 60 THEN '51-60'
            WHEN p.PATIENT_AGE BETWEEN 61 AND 70 THEN '61-70'
            WHEN p.PATIENT_AGE BETWEEN 71 AND 80 THEN '71-80'
            WHEN p.PATIENT_AGE BETWEEN 81 AND 90 THEN '81-90'
            ELSE 'ABOVE 90'
        END AS AGE_GROUP
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN PATIENTS p ON p.Id = e.PATIENT
),
discharged_patients AS (
    SELECT 
        e.PATIENT,
        MIN(e.STOP) AS DISCHARGE_DATE,
        COUNT(*) AS DISCHARGE_COUNT,
        p.AGE_GROUP
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN ENCOUNTERS p ON e.PATIENT = p.PATIENT
    WHERE LOWER(e.description) LIKE '%admission%'
    GROUP BY e.PATIENT, p.AGE_GROUP
),
readmitted_patients AS (
    SELECT 
        e.PATIENT,
        e.START AS READMISSION_DATE,
        p.AGE_GROUP
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN ENCOUNTERS p ON e.PATIENT = p.PATIENT
    WHERE LOWER(e.description) LIKE '%admission%'
)
SELECT 
    d.AGE_GROUP,
    COUNT(DISTINCT d.PATIENT) AS total_discharged,
    COUNT(DISTINCT r.PATIENT) AS total_readmitted,
    ROUND((COUNT(DISTINCT r.PATIENT) / COUNT(DISTINCT d.PATIENT)) * 100, 2) AS readmission_rate
FROM 
    discharged_patients d
LEFT JOIN 
    readmitted_patients r
ON 
    d.PATIENT = r.PATIENT 
    AND r.READMISSION_DATE BETWEEN d.DISCHARGE_DATE AND DATE_ADD(d.DISCHARGE_DATE, INTERVAL 30 DAY)
GROUP BY 
    d.AGE_GROUP
ORDER BY 
    d.AGE_GROUP;


#How long do patients stayed in the hospital?
SELECT ROUND(AVG(DURATION),2) AS AVG_DURATION,
       ROUND(AVG(CASE WHEN LOWER(DESCRIPTION) LIKE '%admission%' THEN SUB.DURATION END),2) AS 
       AVG_ADMITTED_DURATION,
       ROUND(AVG(CASE WHEN LOWER(DESCRIPTION) NOT LIKE '%admission%' THEN SUB.DURATION END),2) AS       
       AVG_OTHER_DURATION
FROM(
    SELECT DESCRIPTION, TIMESTAMP_DIFF(STOP, START, HOUR) AS DURATION
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 
    )AS SUB


#How much is the average cost for a visit
SELECT ROUND(AVG(TOTAL_CLAIM_COST),2) AS AVG_COST
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`


#How much is the average cost for different procedures?
SELECT DESCRIPTION,ROUND(AVG(TOTAL_CLAIM_COST),2) AS AVG_COST,ROUND(AVG(PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY DESCRIPTION
ORDER BY AVG_COST DESC


#How many procedures were covered by insurance?
SELECT 
      COUNT(CASE WHEN PAYER_COVERAGE=0 THEN 1 END) AS NON_COVERAGE,
      COUNT(CASE WHEN PAYER_COVERAGE>0 THEN 1 END) AS COVERAGE,
      ROUND((COUNT(CASE WHEN PAYER_COVERAGE>0 THEN 1 END)/(COUNT(CASE 
      WHEN PAYER_COVERAGE>0 THEN 1 END)  
      +COUNT(CASE WHEN PAYER_COVERAGE=0 THEN 1 END))),2) AS COVER_PERCENT
FROM  `leafy-chariot-427609-e8.HospitalDataset.encounters` 


#Percent of encounters covered by insurance for different procedures?
SELECT 
      DESCRIPTION,
      SUM(CASE WHEN PAYER_COVERAGE=0 THEN 1 END) AS NON_COVERAGE,
      SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END) AS COVERAGE,
      ROUND((SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END)/(SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END)  
      +SUM (CASE WHEN PAYER_COVERAGE=0 THEN 1 END))),2) AS COVER_PERCENT
FROM(
      SELECT p.DESCRIPTION,e.TOTAL_CLAIM_COST,e.PAYER_COVERAGE
      FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
      JOIN `leafy-chariot-427609-e8.HospitalDataset.procedures` p ON e.Id=p.ENCOUNTER 
    ) AS sub
GROUP BY DESCRIPTION
ORDER BY COVER_PERCENT DESC


#Average percent of cost covered for procedures covered by insurance
SELECT 
    ROUND((SUM(PAYER_COVERAGE) / SUM(TOTAL_CLAIM_COST)),2) * 100 AS COST_COVER_PERCENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 



#What is the average cost covered by different insurance companies?
SELECT p.NAME,ROUND((SUM(e.PAYER_COVERAGE)/SUM(e.TOTAL_CLAIM_COST))*100,2) AS AVG_COVERAGE_RATE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
JOIN `leafy-chariot-427609-e8.HospitalDataset.payers` p
ON p.Id=e.PAYER
GROUP BY p.NAME
ORDER BY AVG_COVERAGE_RATE DESC


#What are the numbers of encounters covered by different insurance companies?
WITH CoveredEncounters AS (
    SELECT p.NAME, COUNT(e.PAYER_COVERAGE) AS COVERED_ENCOUNTER
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN `leafy-chariot-427609-e8.HospitalDataset.payers` p
    ON p.Id = e.PAYER
    WHERE e.PAYER_COVERAGE > 0
    GROUP BY p.NAME
),
TotalEncounters AS (
    SELECT p.NAME, COUNT(e.Id) AS TOTAL_ENCOUNTER
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN `leafy-chariot-427609-e8.HospitalDataset.payers` p
    ON p.Id = e.PAYER
    GROUP BY p.NAME
)
SELECT t.NAME, t.TOTAL_ENCOUNTER, 
       COALESCE(c.COVERED_ENCOUNTER,0) AS COVERED_ENCOUNTER, 
       COALESCE(ROUND(((c.COVERED_ENCOUNTER)/(t.TOTAL_ENCOUNTER))*100,2),0) AS PERCENT 
FROM TotalEncounters t
LEFT JOIN CoveredEncounters c ON t.NAME = c.NAME
ORDER BY PERCENT DESC


#What is the average covered cost for patients?
 WITH PATIENTS AS(
     SELECT
        Id, 
        CONCAT(
               REGEXP_REPLACE(s.FIRST,r'[^a-zA-Z\s]'," "),
               " ",
               REGEXP_REPLACE(s.LAST,r'[^a-zA-Z\s]'," "))AS PATIENT_NAME,
         
        CASE 
             WHEN s.DEATHDATE IS NOT NULL THEN DATETIME_DIFF(s.DEATHDATE,s.BIRTHDATE,YEAR)
             ELSE DATETIME_DIFF(CURRENT_DATETIME(),s.BIRTHDATE,YEAR) END AS PATIENT_AGE
     FROM `leafy-chariot-427609-e8.HospitalDataset.patients` s)
SELECT PATIENTS.PATIENT_NAME,AVG(PATIENTS.PATIENT_AGE) AS AGE,
       ROUND(AVG(E.TOTAL_CLAIM_COST),2) AS AVG_COST,
       ROUND(AVG(E.PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` E
JOIN PATIENTS ON PATIENTS.Id=E.PATIENT
GROUP BY PATIENTS.PATIENT_NAME
ORDER BY AVG_COST DESC


#What is the average covered cost for patients in different age groups?
WITH PATIENTS AS (
    SELECT
        Id, 
        CONCAT(
            REGEXP_REPLACE(s.FIRST, r'[^a-zA-Z\s]', ''), 
            ' ', 
            REGEXP_REPLACE(s.LAST, r'[^a-zA-Z\s]', '')
        ) AS PATIENT_NAME,
        CASE 
            WHEN s.DEATHDATE IS NOT NULL THEN DATETIME_DIFF(s.DEATHDATE, s.BIRTHDATE, YEAR)
            ELSE DATETIME_DIFF(CURRENT_DATETIME(), s.BIRTHDATE, YEAR)
        END AS PATIENT_AGE
    FROM `leafy-chariot-427609-e8.HospitalDataset.patients` s
),
ENCOUNTERS AS (
    SELECT 
        e.PATIENT,
        e.TOTAL_CLAIM_COST,
        e.PAYER_COVERAGE,
        CASE 
            WHEN p.PATIENT_AGE <21 THEN 'BELOW 21'
            WHEN p.PATIENT_AGE BETWEEN 21 AND 30 THEN '21-30'
            WHEN p.PATIENT_AGE BETWEEN 31 AND 40 THEN '31-40'
            WHEN p.PATIENT_AGE BETWEEN 41 AND 50 THEN '41-50'
            WHEN p.PATIENT_AGE BETWEEN 51 AND 60 THEN '51-60'
            WHEN p.PATIENT_AGE BETWEEN 61 AND 70 THEN '61-70'
            WHEN p.PATIENT_AGE BETWEEN 71 AND 80 THEN '71-80'
            WHEN p.PATIENT_AGE BETWEEN 81 AND 90 THEN '81-90'
            ELSE 'ABOVE 90'
        END AS AGE_GROUP
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN PATIENTS p ON p.Id = e.PATIENT
)
SELECT 
    AGE_GROUP,
    COUNT(DISTINCT e.PATIENT) AS PATIENT_COUNT,
    ROUND(AVG(e.TOTAL_CLAIM_COST), 2) AS AVG_COST,
    ROUND(AVG(e.PAYER_COVERAGE),2) AS AVG_COVERAGE,
    ROUND((SUM(e.PAYER_COVERAGE)/SUM(e.TOTAL_CLAIM_COST)),2) AS COVERAGE_PERCENT
FROM ENCOUNTERS e
GROUP BY AGE_GROUP
ORDER BY AGE_GROUP;


#What procedures do patients in 31-40 age group receive?
WITH PATIENTS AS (
    SELECT
        Id, 
        CASE 
            WHEN s.DEATHDATE IS NOT NULL THEN DATETIME_DIFF(s.DEATHDATE, s.BIRTHDATE, YEAR)
            ELSE DATETIME_DIFF(CURRENT_DATETIME(), s.BIRTHDATE, YEAR)
        END AS PATIENT_AGE
    FROM `leafy-chariot-427609-e8.HospitalDataset.patients` s
),
ENCOUNTERS AS (
    SELECT 
        e.PATIENT,
        e.TOTAL_CLAIM_COST,
        e.PAYER_COVERAGE,
        e.DESCRIPTION,
        CASE 
            WHEN p.PATIENT_AGE <21 THEN 'BELOW 21'
            WHEN p.PATIENT_AGE BETWEEN 21 AND 30 THEN '21-30'
            WHEN p.PATIENT_AGE BETWEEN 31 AND 40 THEN '31-40'
            WHEN p.PATIENT_AGE BETWEEN 41 AND 50 THEN '41-50'
            WHEN p.PATIENT_AGE BETWEEN 51 AND 60 THEN '51-60'
            WHEN p.PATIENT_AGE BETWEEN 61 AND 70 THEN '61-70'
            WHEN p.PATIENT_AGE BETWEEN 71 AND 80 THEN '71-80'
            WHEN p.PATIENT_AGE BETWEEN 81 AND 90 THEN '81-90'
            ELSE 'ABOVE 90'
        END AS AGE_GROUP
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN PATIENTS p ON p.Id = e.PATIENT
)
SELECT 
    DESCRIPTION,
    COUNT(DISTINCT e.PATIENT) AS PATIENT_COUNT,
    ROUND(AVG(e.TOTAL_CLAIM_COST), 2) AS AVG_COST,
    ROUND(AVG(e.PAYER_COVERAGE),2) AS AVG_COVERAGE,
    ROUND((SUM(e.PAYER_COVERAGE)/SUM(e.TOTAL_CLAIM_COST)),2) AS COVERAGE_PERCENT
FROM ENCOUNTERS e
WHERE AGE_GROUP='31-40'
GROUP BY DESCRIPTION
ORDER BY AVG_COST DESC;

#What is the average covered cost for patients of different races?
SELECT p.RACE,COUNT(DISTINCT p.Id) AS PATIENT_COUNT,
       ROUND(AVG(e.TOTAL_CLAIM_COST), 2) AS AVG_COST,
       ROUND(AVG(e.PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
JOIN `leafy-chariot-427609-e8.HospitalDataset.patients` p
ON e.PATIENT=p.Id
GROUP BY p.RACE
ORDER BY AVG_COST DESC


#What is the average covered cost for patients of different gender?
SELECT p.GENDER,COUNT(DISTINCT p.Id) AS PATIENT_COUNT,
       ROUND(AVG(e.TOTAL_CLAIM_COST), 2) AS AVG_COST,
       ROUND(AVG(e.PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
JOIN `leafy-chariot-427609-e8.HospitalDataset.patients` p
ON e.PATIENT=p.Id
GROUP BY p.GENDER
ORDER BY AVG_COST DESC
