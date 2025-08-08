
*********************************************************************
*  Title:         ChPRS annual report generation (Step 2 of 3)         
*                                                                    
*  Description:   Quality checking variables,
*				  generating frequency tables, highlight incidents w/ injuries				  
*                     
*------------------------------------------------------------------- 
*
*  Input:         SAS dataset 
*
*  Output:        PDF of frequency tables, summary statistics
*
*  Programmer:    Joyce Choe
*     
*  Created:       01-31-2025
*
*  Last updated:  03-21-2025
*                                            
********************************************************************;

options orientation=landscape;


/* For %let statements, edit after = */ 

/* Year of report */
%let year = 2024; 

/* Path for library name */
libname c '~/work';

libname freq '~/work/freq';

/* Path for PDF file */
ods pdf file="~/work/&year.report_step2.PDF";



ods noproctitle;


title1 "&year. report step 2 of 3";
title2 "Quality checking variables, generating frequency tables, highlighting incidents with injuries";
ods exclude EngineHost;
proc contents data=c.ds&year;
run;
title;

/*check for missing/invalid values */
/* Incidents freq by category */
%macro freq(var= , label=,  format= );

	%if &var=location or &var=county or &var=relstyp or
	&var=sub_typ or &var=sub1 or &var=date or &var=incident_wkday %then %do;
		title "Incidents by &label.";
		proc freq data=c.ds&year nlevels order=freq;
			tables &var / missing list nocum out=freq.&var.&year;
			format &var &format;
		run;
		title;
	%end;
	
	%else %do;
		%put error, check other vars; /*note to log*/
    %end;
      
%mend freq;
	
/*Incidents by county*/
%freq(var=county, label=county, format=county_.);

/*Incidents by location*/
%freq(var=location, label=location, format=location_.);

/*Incidents by release type*/
%freq(var=relstyp, label=release_type, format=relstyp_.);

/*Incidents by month*/
%freq(var=date, label=month, format=monname.);

/*Incidents by weekday*/
%freq(var=incident_wkday, label=weekday, format=weekdate9.);

/*Incidents by substance type*/
%freq(var=sub_typ, label=substance_type, format=sub_typ_.);


/*Incidents by substance1*substance type */
title 'Incidents by most common chemical substance';
proc freq data=c.ds&year nlevels order=freq;
	tables sub1*sub_typ / nocum list;
	format sub1 sub1_.;
run;
title;


/*Incidents by substance1_oth*substance type */
title 'Incidents by other chemical substance';
proc freq data=c.ds&year nlevels order=freq;
	tables sub1_oth*sub_typ/ nocum list;
	format sub1 sub1_.;
run;
title;

/*Incidents by substance1*substance type */
title 'Incidents by secondary chemical substance';
proc freq data=c.ds&year nlevels order=freq;
	tables sub2*sub_typ / nocum list;
	format sub1 sub1_.;
run;
title;



/*Sort incidents by total injuries */
title "Highlight incidents with injuries >=1 in &year";
proc sql number;
	select chprs_id, 
	county format=county_., 
	date, 
	tot_chem,
	relstyp format=relstyp_.,
	sub_typ format=sub_typ_.,
	location format=location_.,
	sub1 format=sub1_.,
	tot_vict, 
	comment, 
	sum(tot_vict) as total_injuries_in_&year
	from c.ds&year
	where tot_vict >= 1
	order by tot_vict desc; 
quit;
title;






title1 "Appendix";

title2 'Total number of chemicals per incident';
proc freq data=c.ds&year nlevels order=freq;
	tables tot_chem/ nocum list missing;
run;
title2;

title2 'Total number of injuries per incident';
proc freq data=c.ds&year nlevels order=freq;
	tables tot_vict/ nocum list missing;
run;
title2;


title2 "Count total number of injuries >=1 in &year";
proc print data=c.ds&year noobs;
	var chprs_id county date tot_chem relstyp sub_typ location sub1 tot_vict;
	where tot_vict >=1;
	sum tot_vict;
run;
title2;
title1;


title2 'Incidents by complete substance list';
proc freq data=c.ds&year nlevels order=freq;
	tables sub1*sub1_oth*sub2*sub_typ/ nocum list missing;
	format sub1 sub1_. sub2 sub1_.;
run;
title2;

/*
title 'Incidents by total substances > 1';
proc sql number;
	select chprs_id, 
	county format=county_., 
	date, 
	tot_chem,
	relstyp format=relstyp_.,
	sub_typ format=sub_typ_.,
	location format=location_.,
	sub1 format=sub1_.,
	sub1_oth, 
	sub2 format=sub1_.,
	tot_vict, 
	comment
	from c.ds&year
	where tot_chem > 1
	order by tot_chem desc; 
quit;
title;*/



/*
/*Incidents by substance1*release type 
title 'Incidents by sub1*releasetype';
proc freq data=c.ds&year nlevels order=freq;
	tables sub1*relstyp / nocum list;
	format sub1 sub1_. relstyp relstyp_.;
run;
title;


/*Incidents by substance1_oth*release type 
title 'Incidents by other_sub1*releasetype';
proc freq data=c.ds&year nlevels order=freq;
	tables sub1_oth*relstyp / nocum list;
	format sub1 sub1_. relstyp relstyp_.;
run;
title;
*/

/*Incidents by number of chemicals spilled */
*%freq(var=tot_chem, label=total_number_of_chemicals_spilled);

/*Incidents by number of injuries */
*%freq(var=tot_vict, label=total_number_of_injuries);



ods pdf close;


