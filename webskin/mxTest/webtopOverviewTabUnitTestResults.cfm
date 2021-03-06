<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Unit Test Results --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset stLocal.qResults = application.fapi.getContentObjects(typename="mxTestResult",lProperties="objectid,datetimecreated,numberPassed,numberDependency,numberFailed,numberErrored,details",mxTestID_eq=stObj.objectid,orderBy="datetimecreated desc",maxRows=7) />
<cfquery dbtype="query" name="stLocal.qResults">
	select * from stLocal.qResults order by datetimecreated asc
</cfquery>

<skin:loadJS id="jquery" />
<skin:htmlHead><cfoutput>
	<script type="text/javascript">
		function showDetails(d){
			$j('.result-detail').hide();
			$j('div.details-'+d.replace(/[^\w]+/g,'-')+',span.details-'+d.replace(/[^\w]+/g,'-')).show();
		};
	</script>
</cfoutput></skin:htmlHead>

<cfoutput>
	<h2>Test Results</h2>
	<table style="border:0 none;">
		<tr>
			<td>
</cfoutput>
<cfchart format="png" chartwidth="500" chartheight="400" yaxistitle="Number" xaxistitle="Date" showlegend="true" seriesplacement="stacked" url="javascript:showDetails('$ITEMLABEL$')">
	<cfloop list="numberPassed:##00BF0D:Passed,numberDependency:##FFA500:Dependency Failure,numberFailed:##CC2504:Failed,numberErrored:##0000A0:Error" index="stLocal.thischart">
		<cfchartseries type="bar" serieslabel="#listlast(stLocal.thischart,':')#" seriescolor="#listgetat(stLocal.thischart,2,':')#">
			<cfloop query="stLocal.qResults"><cfchartdata item="#dateformat(stLocal.qResults.datetimecreated[stLocal.qResults.currentrow], 'd mmm')#" value="#stLocal.qResults[listfirst(stLocal.thischart,':')][stLocal.qResults.currentrow]#" /></cfloop>
		</cfchartseries>
	</cfloop>
</cfchart>
<cfoutput>
			</td>
			<td>
</cfoutput>

<cfquery dbtype="query" name="stLocal.qResults">
	select * from stLocal.qResults order by datetimecreated desc
</cfquery>
<cfloop query="stLocal.qResults">
	<cfif stLocal.qResults.currentrow eq 1 or dateformat(stLocal.qResults.datetimecreated,"short") neq dateformat(stLocal.qResults.datetimecreated[stLocal.qResults.currentrow-1],"short")>
		<cfoutput>
			<span class="details-#dateformat(stLocal.qResults.datetimecreated, 'd-mmm')# result-detail" style="display:none;">
				<skin:view typename="mxTestResult" objectid="#stLocal.qResults.objectid#" webskin="displayChart" />
			</span>
		</cfoutput>
	</cfif>
</cfloop>
<cfoutput>
			</td>
		</tr>
	</table>
</cfoutput>

<cfloop query="stLocal.qResults">
	<cfwddx action="wddx2cfml" input="#stLocal.qResults.details#" output="stLocal.details" />
	
	<cfif stLocal.qResults.currentrow eq 1 or dateformat(stLocal.qResults.datetimecreated,"short") neq dateformat(stLocal.qResults.datetimecreated[stLocal.qResults.currentrow-1],"short")>
		<cfoutput>
			<div class="details-#dateformat(stLocal.qResults.datetimecreated, 'd-mmm')# result-detail" style="display:none;">
				<skin:view typename="mxTestResult" objectid="#stLocal.qResults.objectid#" webskin="displayBody" />
			</div>
		</cfoutput>
		<!---<cfoutput>
			<div class="details-#dateformat(stLocal.qResults.datetimecreated, 'd-mmm')# result-detail" style="display:none;">
				<table class="objectAdmin" width="100%">
					<tr><th>Test</th><th>Result</th><th>Message</th></tr>
		</cfoutput>
		
		<cfloop from="1" to="#arraylen(stLocal.details.aResults)#" index="stLocal.i">
			<cfoutput><tr><td>#stLocal.details.aResults[stLocal.i].name#</td><td>#stLocal.details.aResults[stLocal.i].status#</td><td>#stLocal.details.aResults[stLocal.i].message#</td></tr></cfoutput>
		</cfloop>
		
		<cfoutput>
				</table>
			</div>
		</cfoutput>--->
	</cfif>
</cfloop>

<cfsetting enablecfoutputonly="false" />