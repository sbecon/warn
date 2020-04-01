*Jacob Morris
*Edited 3/31/2020

global main_dir = "/Users/Jacob/Desktop"

clear
set more off
******************************

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
gsheet "${main_dir}/WARN/CO.csv" , key("1U7l1g6aNFDNgrHVdgpaFqMzKSx3JPr6xBz4vWPwC6Sg") id("1355863211")

drop if companyname == "" | companyname == "Septodont Inc." | layoffdatestart == "" | naicscode == .
assert companyname !="" & layoffdatestart != ""

/*Labels industries
label define mylab `=naicscode [`n']' "`=naicstitle [`n']'"
label values naicscode mylab
*/

gen edate=date(layoffdatestart,"MDY")

format edate %tdnn/dd/YY

sort naicscode edate

collapse (sum) totalworkerslaidoff, by (naicscode naicstitle edate)

tsset naicscode edate

tsfill, full

replace totalworkerslaidoff = 0 if totalworkerslaidoff==.

xtset naicscode edate

*creates running total by industry 
gen cumworker=.
bys naicscode : replace cumworker = totalworkerslaidoff[1]
bys naicscode : replace cumworker=totalworkerslaidoff[_n]+ cumworker[_n-1] if _n>1

seperate cumworker , by(naicscode) shortlabel

local plotvar "cumworker2382 562 512 6212 5617 722 481"

gen cumworker1= cumworker2382
gen cumworker2= cumworker562
gen cumworker3= cumworker512
gen cumworker4= cumworker6212
gen cumworker5= cumworker5617
gen cumworker6= cumworker722
gen cumworker7= cumworker481
gen cumworker8= cumworker721

collapse cumworker*, by(edate)

gen _cumworker1 = cumworker1

forvalues i = 2/8 {
local j = `i' - 1
gen _cumworker`i' = _cumworker`j' + cumworker`i'
}


twoway area _cumworker8 _cumworker7 _cumworker6 _cumworker5 edate, ///
	ytitle("Total Workers Laid Off") xtitle("Layoff Date") ///
	yla(, ang(h)) legend(off)  /// 
	color(gs2 gs4 gs6 gs8) ///
	text(100 22000 "Other" 400 22000 "Food Services" ///
	800 22000 "Air Transportation" 1200 22000 "Accomodation", color(white)) /// 
	xlabel(#8)  ///
	ymtick(##5) ///
	graphregion(fcolor(white) lcolor(white)) 

	 

graph export "${main_dir}/WARN/stacked_plot.pdf", replace

