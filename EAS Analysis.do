clear

// Step 1: Import/Read the attendance (EAS) data.
cd "C:\Users\dell\Downloads\DA_Test_Set_B"
insheet using "eas_oct_2016_cleaned.txt", delimiter("*") clear names

// Step 2: Keep/Filter only the sewing sub-department for a single chosen factory unit.
keep if subdept == "SEWING" & unit == 1

// Step 3: Check for data quality issues and address concerns.
foreach var of varlist leave holidays sundays a01_status-a31_status a01_in-a31_in a01_out-a31_out {
    summarize `var', meanonly
    count if missing(`var')
}
egen any_na = rowmiss(a01_in-a31_out)
drop if any_na

// Step 4: Rename and label variables.
rename unit factory_unit
rename tkn_no worker_ID
rename subdept sub_department
rename batch line_batch

label variable factory_unit "Factory Unit"
label variable worker_ID "Worker ID"
label variable sub_department "Sub-Department"
label variable line_batch "Line/Batch"

// Step 5: Generate binary/dummy variables indicating worker's presence each day.
forval i = 1/31 {
    local day_label = string(`i', "%02.0f")
    gen present_day`day_label' = (a`day_label'_status == "P" | a`day_label'_status == "P/A")
    replace present_day`day_label' = 0 if missing(a`day_label'_status)
}

// Step 6: Drop attendance status string variables.
drop a*_status

// Step 7: Calculate total monthly attendance for each worker.
egen total_attendance = rowtotal(present_day* holidays sundays)

// Step 8: Reshape data to worker-day level.
duplicates report worker_ID present_day* a*_in a*_out
duplicates drop worker_ID, force
reshape long present_day a_in a_out, i(worker_ID) j(day)
drop a_in a_out

// Step 9: Generate time variables in proper format and label them.
forval i = 1/31 {
    local day_number = string(`i', "%02.0f") 
    
    destring a`day_number'_in, replace 
    gen hours_a_in`day_number' = floor(a`day_number'_in)
    gen minutes_a_in`day_number' = round(60 * (a`day_number'_in - hours_a_in`day_number'))
    gen arrival_time_a_in`day_number' = clock(hours_a_in`day_number', minutes_a_in`day_number', 0)
    label variable arrival_time_a_in`day_number' "Arrival Time on Day `day_number'"
}

forval i = 1/31 {
    local day_number = string(`i', "%02.0f")
   
    destring a`day_number'_out, replace
    gen hours_a_out`day_number' = floor(a`day_number'_out)
    gen minutes_a_out`day_number' = round(60 * (a`day_number'_out - hours_a_out`day_number'))
    gen arrival_time_a_out`day_number' = clock(hours_a_out`day_number', minutes_a_out`day_number', 0)
    label variable arrival_time_a_out`day_number' "Leaving Time on Day `day_number'"
}

// Step 10: Summarize data at the day level and store temporarily.
preserve
collapse (mean) present_day* hours_a_in* minutes_a_in* hours_a_out* minutes_a_out*, by(factory sub_department line_batch)
save "temp_preserved_data.dta", replace

// Step 11: Import/Read the production (Sipmon) data.
import excel using "SipmonOct16Feb17.xlsx", firstrow clear

// Step 12: Filter production data for October 2016 and specific factory unit.
gen date = date(SCHEDULE_DATE, "MDY")
format date %tdnn/dd/CCYY
keep if date >= mdy(10, 1, 2016) & date <= mdy(10, 31, 2016) & UNIT_CODE == "UNIT-1"
