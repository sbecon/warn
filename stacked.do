*Jacob Morris
*Edited 3/31/2020

global main_dir = "/Users/Jacob/Desktop"

clear
set more off
******************************


preserve
***************************** Imports/Calculates total layoffs from WARN for MAR 2019

*imports last 2019 layoffs
import delimited "${main_dir}/warn/CO19.csv", clear 

gen ldate=date(layoffdatestart,"MDY") // converts date to proper format

gen kdate=date(layoffdateend, "MDY") // converts date to proper format
format ldate kdate %td

drop if ldate > 21639 //excludes layoffs that start after 03/./2019

assert (21608<ldate<21640) | 21608<kdate<21640 //checks that a layoff occurs in march 2019

gen diff = kdate-ldate //calculates the number of days between the first layoff date and the last

gen layoffs_perday = layofftotal/diff //calculates the average number of layoffs per day

*calculates the nubmer of days between first layoff and end of march
gen num_days_march = (21639 - ldate + 1) if (kdate!=. & kdate >21639)
replace num_days_march = (kdate - ldate + 1) if (kdate <= 21639)


gen layoffs_2019 = layofftotal //creates total layoff variable for 2019

*calculates the floor of the number of layoffs in 2019
replace layoffs_2019 = floor(layoffs_perday*num_days_march) if num_days_march != .

*totals these layoffs
egen total_layoffs_MAR2019 = sum(layoffs_2019)

*saves the values to be recalled later
sca sca_total_layoffs_MAR2019 = total_layoffs_MAR2019

*****************************
restore


*program to draw google sheets data
*from: https://www.statalist.org/forums/forum/general-stata-discussion/general/1509190-import-data-from-google-spreadsheet-by-stata
capture program drop gsheet

program define gsheet

    syntax anything , key(string) id(string)
    
    local url "https://docs.google.com/spreadsheets/d/`key'/export?gid=`id'&format=csv"
    
    copy "`url'" `anything', replace
    
    noi disp `"saved in `anything'"'
    
    import delim using `anything', clear
	
end

*Imports data for colorado specifically
gsheet "${main_dir}/WARN/CO20.csv" , key("1U7l1g6aNFDNgrHVdgpaFqMzKSx3JPr6xBz4vWPwC6Sg") id("1355863211")


*data formatting
drop if companyname == "" | companyname == "Septodont Inc." | layoffdatestart == "" | naicscode == .
assert companyname !="" & layoffdatestart != ""

*converts social distancing dates to correct format
local varlist "sd cpv nesc"

*turns the dates in local varlist to proper format and saves them for recall later
foreach var in `varlist' {
	
	gen `var'_date = date(`var', "MDY")
	drop `var'
	gen `var' = `var'_date
	drop `var'_date
	
	sca sca_`var' = `var'
	
	drop `var'
}

*creates the date for layoffs for march 2020
gen edate=date(layoffdatestart,"MDY") 

*formats layoff dates
format edate %tdnn/dd/YY

*sorts according to industry, then date
sort naicscode edate

*sums total # of workers laidoff according to industry and date
collapse (sum) totalworkerslaidoff, by (naicscode naicstitle edate)

*sets parameters for time series
tsset naicscode edate

*fills data
tsfill, full

*replaces missing values with zero layoffs
replace totalworkerslaidoff = 0 if totalworkerslaidoff==.

*establishes data as panel
xtset naicscode edate

*creates cumulative total for # workers laid off, by industry 
gen cumworker=.
bys naicscode : replace cumworker = totalworkerslaidoff[1]
bys naicscode : replace cumworker=totalworkerslaidoff[_n]+ cumworker[_n-1] if _n>1

*seperates the cumulative total according to industry
seperate cumworker , by(naicscode) shortlabel

*reassigns cumworker values according to easier 1/8 format
gen cumworker1= cumworker2382
gen cumworker2= cumworker562
gen cumworker3= cumworker512
gen cumworker4= cumworker6212
gen cumworker5= cumworker5617
gen cumworker6= cumworker722
gen cumworker7= cumworker481
gen cumworker8= cumworker721

*collapses data such that we have 1 observation per date
collapse cumworker*, by(edate)

*initalizes a cumulative variable for the cumworkers——for stacked area plot
gen _cumworker1 = cumworker1

*generates the rest of the variables——for stacked area plot
forvalues i = 2/8 {
local j = `i' - 1
gen _cumworker`i' = _cumworker`j' + cumworker`i'
}

*brings back social distancing dates
foreach var in `varlist' {
	
	gen `var' = sca_`var'
	
	format `var' %tdnn/dd/YY	

}

*brings back social distancing dates
gen total_layoffs_MAR2019 = sca_total_layoffs_MAR2019

*graphs the cumulative area plot
graph twoway area _cumworker8 _cumworker7 _cumworker6 _cumworker5 edate, ///
	ytitle("Total Workers Laid Off") xtitle("Layoff Date") ///
	yla(, ang(h)) legend(off)  /// 
	color(gs2 gs4 gs6 gs8) ///
	text(100 22000 "   Other" 400 22000 "   Food Services" ///
	800 22000 "   Air Transportation" 1200 22000 "   Accomodation", color(white)) /// 
	title("Colorado Layoffs by Industry, 2020" " " " ", color(black)) /// 
	xlabel(#8)  ///
	ymtick(##5) ///
	graphregion(fcolor(white) lcolor(white)) 
	
*adds lines corresponding to social distancing dates and the # of layoffs from 2019
addplot: (scatteri 0 21998 2000 21998, recast(line) lw(medthick) lc(edkblue) text(2140 21998 "Social" "Distancing")) ///
	(scatteri 0 21994 2000 21994, recast(line) lw(medthick) lc(eltblue) text(2200 21994 "Non-Essential" " Services" "Close")) ///
	(scatteri 0 21991 2000 21991, recast(line) lw(medthick) lc(ebblue) text(2200 21991 "Public" "Venues" " Close")) ///
	(line total_layoffs_MAR2019 edate, lw(medthick) lc(olive_teal*1.2) lp(dash) text(600 21988 "   Layoffs" "   March 2019"))
	
*saves the graph
graph export "${main_dir}/WARN/stacked_plot.pdf", replace

