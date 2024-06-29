#How many patients visited 
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

#How many procedures were covered by insurance?
SELECT 
      SUM(CASE WHEN PAYER_COVERAGE=0 THEN 1 END) AS NON_COVERAGE,
      SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END) AS COVERAGE,
      ROUND((SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END)/(SUM(CASE WHEN PAYER_COVERAGE>0 THEN 1 END)  
      +SUM (CASE WHEN PAYER_COVERAGE=0 THEN 1 END))),2) AS COVER_PERCENT
FROM(
      SELECT p.DESCRIPTION,e.TOTAL_CLAIM_COST,e.PAYER_COVERAGE
      FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
      JOIN `leafy-chariot-427609-e8.HospitalDataset.procedures` p ON e.PATIENT=p.PATIENT 
    ) AS sub


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
      JOIN `leafy-chariot-427609-e8.HospitalDataset.procedures` p ON e.PATIENT=p.PATIENT 
    ) AS sub
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
      WHERE e.PAYER_COVERAGE>0
    ) AS sub
ORDER BY COST_COVER_PERCENT DESC

#Average percent of cost covered for procedures covered by insurance
SELECT 
    ROUND(AVG(COST_COVER_PERCENT),2) AS avg_cost_cover_percent
FROM (
    SELECT 
        (e.PAYER_COVERAGE / e.TOTAL_CLAIM_COST) * 100 AS COST_COVER_PERCENT
    FROM `leafy-chariot-427609-e8.HospitalDataset.encounters` e
    JOIN `leafy-chariot-427609-e8.HospitalDataset.procedures` p 
    ON e.PATIENT = p.PATIENT 
    WHERE e.PAYER_COVERAGE > 0
) AS sub;

