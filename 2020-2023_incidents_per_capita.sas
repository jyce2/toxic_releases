*********************************************************************
*  Title:         County Population Estimates (Step 1 of 1)         
*                                                                    
*  Description:   Importing certified county population estimates from NC state census, 
*				  formatting variables, 
*				  cleaning data,
*				  checking for missing values, 
*				  exploratory data analysis,
*				  exporting as SAS dataset
*
*------------------------------------------------------------------- 
*
*  Input:         County_totalEstimate.csv
*
*  Output:        SAS data file, PDF
*
*  Programmer:    Joyce Choe
*
*  Created:       07-25-2025
*
*  Last updated:  07-28-2025
*                                             
********************************************************************;
options nodate;

/* Path for PDF file */
ods pdf file="~/work/pop/incident_pop_estimates.PDF";


* 1 - Set libname;
libname lib "~/work/pop";  

* 2 - Import csv;
options validvarname=v7;
proc import out=census
    datafile="~/work/pop/County_totalEstimate2023.csv"
    dbms=csv
    replace;
    getnames=yes;
run;

* 3 - Preview SAS data file with valid var names;
/*proc contents data=census;
run;
*/
* 4 - Format vars to correct type and rename vars;
options validvarname=v7;
data lib.census;
	infile '~/work/pop/County_totalEstimate2023.csv' dsd firstobs=2;
	informat County $50. 
			 April_1__2020_Census_Base comma10.
			 July_1__2020 comma10.
			 July_1__2021 comma10.
			 July_1__2022 comma10. 
 			 July_1__2023 comma10.;
	input county $ 
		  April_1__2020_Census_Base 
		  July_1__2020
		  July_1__2021
		  July_1__2022 
 		  July_1__2023;
 	rename April_1__2020_Census_Base = apr_2020
 		   July_1__2020 = jul_2020
 		   July_1__2021 = jul_2021
 		   July_1__2022 = jul_2022
 		   July_1__2023 = jul_2023;
run;

* 5 - Check for missing or invalid values;
/*proc freq data=lib.census nlevels;
	table county*apr_2020*jul_2020*jul_2021*jul_2022*jul_2023 / missing list nocum nofreq;
run;
*/
proc export data=lib.census
	outfile="~/work/pop/census.csv"
	dbms=CSV 
	replace;
run;

* 6 - Combine chprs data (2020-2023);
libname c "~/work/climate/import";
data all_chprs;
	set c.chprs2020 c.chprs2021 c.chprs2022 c.chprs2023;
	year = year(date);
run;

proc export data=all_chprs
	outfile="~/work/pop/chprs_total.csv"
	dbms=CSV 
	replace;
run;

* 7 - Merge pop estimates by counties per year (2020-2023)
then, calculate county-wide incidents per capita;
%macro merge(year =);
proc sql;
CREATE TABLE lib.pop&year. AS
	SELECT DISTINCT a.year AS year,
				    c_county AS county, 
					count(chprs_id) AS incidents_per_county, 
				    jul_&year. AS county_pop, 
				    (count(chprs_id)/jul_&year.) AS incidents_per_capita,
				    100000*(count(chprs_id)/jul_&year.) AS incidents_per_capita_100000,
				    'incidents per 100000 persons' AS unit
	FROM all_chprs(WHERE=(year=&year.)) AS a
		LEFT JOIN lib.census AS b
		ON a.c_county = b.county
	GROUP BY a.c_county;
quit;

title "County-wide incidents per capita: &year";
proc print data=lib.pop&year.;
	sum incidents_per_county;
run;
title;

title "Number of counties: &year";
proc freq data=lib.pop&year. nlevels;
	table year*county*county_pop*incidents_per_capita_100000*unit / noprint;
run;
title;


%mend merge;

%merge(year=2020);
%merge(year=2021);
%merge(year=2022);
%merge(year=2023);


* 8 - Remerge year datasets into one dataset;
proc sql;
CREATE TABLE lib.poptotal AS 
	SELECT * 
	FROM lib.pop2020
	UNION ALL
	SELECT *
	FROM lib.pop2021
	UNION ALL
	SELECT *
	FROM lib.pop2022
	UNION ALL
	SELECT *
	FROM lib.pop2023;
quit;

proc export data=lib.poptotal
	outfile="~/work/pop/pop_total.csv"
	dbms=CSV 
	replace;
run;

* 9 - Exploratory data analysis;
title 'Summary statistics: Incidents per Capita from 2020-2023';
proc means data=lib.poptotal nmiss min q1 mean median q3 max std maxdec=2;
	class year;
	var incidents_per_capita_100000;
run;

title 'Summary statistics: Incidents per Capita by County from 2020-2023';
proc means data=lib.poptotal nmiss min q1 mean median q3 max std maxdec=2;
	class county;
	var incidents_per_capita_100000;
run;


/*
title 'Plot: County populations from 2020-2023';
proc sgplot data=lib.poptotal noautolegend;
	series x=year y=county_pop/ group=county curvelabel groupdisplay=cluster;
	xaxis type=discrete;
	yaxis type=log logstyle=linear;
run;
*/
ods graphics on / height = 8in;
title 'Incidents per County-level Capita from 2020-2023';
proc sgplot data=lib.poptotal noautolegend;
	scatter x=year y=incidents_per_capita_100000 / jitter
      filledoutlinedmarkers 
      markerfillattrs=(color=lightblue) 
      markeroutlineattrs=(color=grey thickness=1)
      markerattrs=(symbol=circlefilled size=8)
      transparency=0.5;
	vbox incidents_per_capita_100000 / nofill category=year displaystats=(n median mean std);
	label incidents_per_capita_100000 = 'Incidents per 100,000 persons';
	label year = "Year";
	yaxis grid values=(0 TO 66 BY 3);
run;


* 10 - Map;
/*exact location (lat, long) for mapping data set */
proc gproject
	data=maps.counties out = nc;
	where state = 37;
	id state county;
run;

/* cross-reference FIPS county codes for county data set*/
proc sql number;
	create table cnty as 
	select state, county, statename, countynm 
	from mapssas.cntyname
	where statename = "North Carolina";
quit;

/* merge to match by county name for final mapping data set*/
proc sql number;
	create table c.nc(drop=state county rename=(countynm=county)) as 
	select * from nc as a
		inner join cnty as b
		on a.county = b.county;
quit;
	


/* apply working format values to county var in ds */
proc format;
	value county_ 
	1='Alamance' 2='Alexander' 
		3='Alleghany' 4='Anson' 
		5='Ashe' 6='Avery' 
		7='Beaufort' 8='Bertie' 
		9='Bladen' 10='Brunswick' 
		11='Buncombe' 12='Burke' 
		13='Cabarrus' 14='Caldwell' 
		15='Camden' 16='Carteret' 
		17='Caswell' 18='Catawba' 
		19='Chatham' 20='Cherokee' 
		21='Chowan' 22='Clay' 
		23='Cleveland' 24='Columbus' 
		25='Craven' 26='Cumberland' 
		27='Currituck' 28='Dare' 
		29='Davidson' 30='Davie' 
		31='Duplin' 32='Durham' 
		33='Edgecombe' 34='Forsyth' 
		35='Franklin' 36='Gaston' 
		37='Gates' 38='Graham' 
		39='Granville' 40='Greene' 
		41='Guilford' 42='Halifax' 
		43='Harnett' 44='Haywood' 
		45='Henderson' 46='Hertford' 
		47='Hoke' 48='Hyde' 
		49='Iredell' 50='Jackson' 
		51='Johnston' 52='Jones' 
		53='Lee' 54='Lenoir' 
		55='Lincoln' 56='McDowell' 
		57='Macon' 58='Madison' 
		59='Martin' 60='Mecklenburg' 
		61='Mitchell' 62='Montgomery' 
		63='Moore' 64='Nash' 
		65='New Hanover' 66='Northampton' 
		67='Onslow' 68='Orange' 
		69='Pamlico' 70='Pasquotank' 
		71='Pender' 72='Perquimans' 
		73='Person' 74='Pitt' 
		75='Polk' 76='Randolph' 
		77='Richmond' 78='Robeson' 
		79='Rockingham' 80='Rowan' 
		81='Rutherford' 82='Sampson' 
		83='Scotland' 84='Stanly' 
		85='Stokes' 86='Surry' 
		87='Swain' 88='Transylvania' 
		89='Tyrrell' 90='Union' 
		91='Vance' 92='Wake' 
		93='Warren' 94='Washington' 
		95='Watauga' 96='Wayne' 
		97='Wilkes' 98='Wilson' 
		99='Yadkin' 100='Yancey';
run;



/* remerge with 100 counties from NC */
proc sql;
	CREATE TABLE tot_map_release AS
	SELECT  UPCASE(county) AS county, 
			incidents_per_capita_100000,
			avg(incidents_per_capita_100000) as avg_incidents
	FROM lib.poptotal
	GROUP BY county
	UNION 
	SELECT DISTINCT (county) FROM c.nc
	WHERE county NOT IN (SELECT UPCASE(county) FROM lib.poptotal);
quit;


/* display map releases by county */
goptions reset=all border;

proc format;
	value qty_
	0-1 = '0-1'
	1<-2 = '>1-2'
	2<-5 = '>2-5'
	5-high = '>5'
	;
run;

title1 "Average Incidents per County-level Capita";
title2 "North Carolina: 2020 to 2023";

/*blue shades*/
pattern1 v=ms c=white; 
pattern2 v=ms c=CXc6dbef; 
pattern3 v=ms c=CX6baed6; 
pattern4 v=ms c=CX08519c; 
pattern5 v=ms c=CX142233;

LEGEND1 LABEL=(HEIGHT=1 POSITION=TOP justify=CENTER "Incidents per 100,000 persons")
ACROSS=1 DOWN=5 POSITION = (bottom outside left) value=(justify=center)
FRAME
MODE=PROTECT ;


proc gmap
	data=tot_map_release map=c.nc all;
	format avg_incidents qty_.;
	id county;
	choro avg_incidents / 
		discrete legend=legend1 coutline=black levels=all;
run;
quit;

ods pdf close;

