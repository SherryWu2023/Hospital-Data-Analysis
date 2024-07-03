#This project is about a dataset from a hospital where there are an encounter table, a payer table, a patient table and a procedures table. The following are queries used to explore the dataset and extract insights. 

#How many patients visited  Ans:974 
SELECT COUNT (DISTINCT patient) as num_patient
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`

#Reasons why patients visited the hospital
SELECT DESCRIPTION, COUNT(PATIENT) AS NUM_PATIENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY DESCRIPTION
ORDER BY NUM_PATIENT DESC


#How many patients have been admitted or readmitted
SELECT SUM(CASE WHEN sub.num_admission=1 THEN 1 END) as admitted_patient,
       SUM(CASE WHEN sub.num_admission>1 THEN 1 END) as readmitted_patient
FROM (SELECT PATIENT, count(Id) as num_admission 
      FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 
      WHERE lower(DESCRIPTION) like '%admission%'
      GROUP BY PATIENT) as sub

#How long patients stayed in the hospital
SELECT ROUND(AVG(DURATION),2) AS AVG_DURATION,
       ROUND(AVG(CASE WHEN LOWER(DESCRIPTION) LIKE '%admission%' THEN SUB.DURATION END),2) AS AVG_ADMITTED_DURATION,
       ROUND(AVG(CASE WHEN LOWER(DESCRIPTION) NOT LIKE '%admission%' THEN SUB.DURATION END),2) AS AVG_OTHER_DURATION
FROM(
    SELECT DESCRIPTION, TIMESTAMP_DIFF(STOP, START, HOUR) AS DURATION
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 
    )AS SUB

#How much is the average cost for a visit
SELECT ROUND(AVG(TOTAL_CLAIM_COST),2) AS AVG_COST
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`

#How much is the average cost for different purposes of visits?
SELECT DESCRIPTION,ROUND(AVG(TOTAL_CLAIM_COST),2) AS AVG_COST,ROUND(AVG(PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters`
GROUP BY DESCRIPTION
ORDER BY AVG_COST DESC

#How many procedures were covered by insurance?
SELECT 
      COUNT(CASE WHEN LOWER(DESCRIPTION) LIKE '%procedure%' AND PAYER_COVERAGE=0 THEN 1 END) AS NON_COVERAGE,
      COUNT(CASE WHEN LOWER(DESCRIPTION) LIKE '%procedure%' AND PAYER_COVERAGE>0 THEN 1 END) AS COVERAGE,
      ROUND((COUNT(CASE WHEN LOWER(DESCRIPTION) LIKE '%procedure%' AND PAYER_COVERAGE>0 THEN 1 END)/(COUNT(CASE 
      WHEN LOWER(DESCRIPTION) LIKE '%procedure%' AND PAYER_COVERAGE>0 THEN 1 END)  
      +COUNT(CASE WHEN LOWER(DESCRIPTION) LIKE '%procedure%' AND PAYER_COVERAGE=0 THEN 1 END))),2) AS COVER_PERCENT
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
WHERE LOWER(DESCRIPTION) LIKE '%procedure%' 
GROUP BY DESCRIPTION
ORDER BY COVER_PERCENT DESC


#Percent of cost covered for different procedures?
SELECT 
       DISTINCT DESCRIPTION,
       (PAYER_COVERAGE/TOTAL_CLAIM_COST)*100 AS COST_COVER_PERCENT
FROM(
      SELECT p.DESCRIPTION,e.TOTAL_CLAIM_COST,e.PAYER_COVERAGE
      FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
      JOIN `leafy-chariot-427609-e8.HospitalDataset.procedures` p ON e.PATIENT=p.PATIENT 
      WHERE e.PAYER_COVERAGE>0 AND LOWER(e.DESCRIPTION) LIKE '%procedure%' 
    ) AS sub
ORDER BY COST_COVER_PERCENT DESC

#Average percent of cost covered for procedures covered by insurance
SELECT 
    ROUND((SUM(PAYER_COVERAGE) / SUM(TOTAL_CLAIM_COST)),2) * 100 AS COST_COVER_PERCENT
FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` 
WHERE PAYER_COVERAGE > 0 AND LOWER(DESCRIPTION) LIKE '%procedure%'


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
    ROUND(AVG(e.PAYER_COVERAGE),2) AS AVG_COVERAGE
FROM ENCOUNTERS e
GROUP BY AGE_GROUP
ORDER BY AGE_GROUP;
