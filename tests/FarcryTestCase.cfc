<cfcomponent hint="Specialised test component for FarCry tests" extends="mxunit.framework.TestCase" output="false" bAbstract="true">
	
	<cffunction name="setUp" returntype="void" access="public">
	
		<cfset this.aPinObjects = arraynew(1) />
		<cfset this.aPinUsers = arraynew(1) />
		<cfset this.aPinScopes = arraynew(1) />
		<cfset this.aPinCategories = arraynew(1) />
		<cfset this.qPinNavigation = querynew("empty") />
	</cffunction>

	<cffunction name="tearDown" returntype="void" access="public">
		
		<!--- Revert data --->
		<cfset revertObjects() />
		
		<!--- Remove dirty users --->
		<cfset revertUsers() />
		
		<!--- Remove dirty scope variables --->
		<cfset revertScopes() />
		
		<!--- Remove dirty categories --->
		<cfset revertCategories() />
		
		<!--- Revert dirty navigation tree --->
		<cfset revertNavigation() />
	</cffunction>
	
	
	<cffunction name="createTemporaryObject" access="package" returntype="struct" output="false" hint="Creates an object and adds it to the pinned list">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		
		<cfset var o = application.fapi.getContentType(arguments.typename) />
		<cfset var stObj = duplicate(arguments) />
		<cfset var lCategories = "" />
		<cfset var oCategory = "" />
		
		<cfparam name="stObj.objectid" default="#createuuid()#" />
		
		<cfif structkeyexists(arguments,"categories")>
			<cfset lCategories = arguments.categories />
			<cfset structdelete(arguments,"categories") />
		</cfif>
		
		<cfset pinObjects(typename=arguments.typename,objectid=stObj.objectid) />
		<cfset o.setData(stProperties=stObj) />
		
		<cfif len(lCategories)>
			<cfset createobject("component","farcry.core.packages.farcry.category").assignCategories(stObj.objectid,lCategories) />
		</cfif>
		
		<cfreturn stObj />
	</cffunction>
	
	<cffunction name="createTemporaryCategory" access="package" returntype="struct" output="false" hint="Creates the specified category and adds it the the pinned list">
		<cfargument name="alias" type="string" required="true" hint="" />
		<cfargument name="parentid" type="uuid" required="false" default="#application.catid.root#" hint="The parent of the new category" />
		<cfargument name="categoryid" type="string" required="false" hint="" />
		<cfargument name="categorylabel" type="string" required="false" hint="" />
		
		<cfset var oCategory = createobject("component","farcry.core.packages.types.dmCategory") />
		
		<cfparam name="arguments.categoryid" default="#createuuid()#" />
		<cfparam name="arguments.categorylabel" default="#arguments.alias#" />
		
		<cfset pinCategories(arguments.categoryid) />
		<cfset oCategory.addCategory(arguments.categoryid,arguments.categorylabel,arguments.parentid) />
		<cfset oCategory.setAlias(arguments.categoryid,arguments.alias) />
		
		<cfreturn duplicate(arguments) />
	</cffunction>
	
	<cffunction name="createTemporaryNavigation" access="package" returntype="struct" output="false" hint="Creates the specified navigation node and adds it the the pinned list">
		<cfargument name="parentid" type="uuid" required="false" default="#application.catid.root#" hint="The parent of the new category" />
		
		<cfset var stObj = structnew() />
		
		<cfparam name="arguments.objectid" default="#createuuid()#" />
		<cfparam name="arguments.typename" default="dmNavigation" />
		
		<cfset pinNavigation() />
		<cfset stObj = createTemporaryObject(argumentCollection=arguments) />
		<cfset application.factory.oTree.setYoungest(parentid=arguments.parentid,objectid=stObj.objectid,objectname=stObj.label,typename="dmNavigation") />
		
		<cfreturn duplicate(arguments) />
	</cffunction>
	
	
	<cffunction name="getCategory" access="package" returntype="struct" output="false" hint="Returns the specified category">
		<cfargument name="category" type="string" required="true" hint="The category id or alias" />
		
		<cfset var qCategory = structnew() />
		<cfset var stCat = structnew() />
		<cfset var oTree = createobject("component","farcry.core.packages.farcry.tree") />
		<cfset var o = createobject("component",application.stCOAPI.dmCategory.packagepath) />
		
		<cfif isvalid("uuid",arguments.category)>
			<cfquery datasource="#application.dsn#" name="qCategory">
				select		*
				from		#application.dbowner#dmCategory
				where		objectid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.category#" />
			</cfquery>
		<cfelse><!--- Retrieve the category by alias --->
			<cfquery datasource="#application.dsn#" name="qCategory">
				select		*
				from		#application.dbowner#dmCategory
				where		alias=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.category#" />
			</cfquery>
		</cfif>
		
		<cfif qCategory.recordcount>
			<cfset stCat = o.getData(qCategory.objectid) />
			<cfset stCat.categoryid = stCat.objectid />
		</cfif>
		
		<cfreturn stCat />
	</cffunction>
	
	<cffunction name="getCategoryReferences" access="package" returntype="string" output="false" hint="Returns a list of references to the category">
		<cfargument name="categoryid" type="uuid" required="true" hint="The categoryid" />
		
		<cfset var qRefs = querynew("empty") />
		
		<cfquery datasource="#application.dsn#" name="qRefs">
			select	objectid
			from	#application.dbowner#refCategories
			where	categoryid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.categoryid#" />
		</cfquery>
		
		<cfreturn valuelist(qRefs.objectid) />
	</cffunction>
	
	<cffunction name="pinCategories" access="package" returntype="void" output="false" hint="Adds categories to the dirty list, to be reverted on tearDown">
		<cfargument name="category" type="string" required="true" hint="A list of objectids or aliases" />
		
		<cfset var thiscategory = "" />
		<cfset var stPin = structnew() />
		
		<cfloop list="#arguments.category#" index="thiscategory">
			<cfset stPin = structnew() />
			<cfset stPin.category = thiscategory />
			
			<!--- Add category information --->
			<cfset stPin.stPre = getCategory(thiscategory) />
			
			<!--- Add reference information --->
			<cfif not structisempty(stPin.stPre)>
				<cfset stPin.lPreRefs = getCategoryReferences(stPin.stPre.categoryid) />
			</cfif>
			
			<!--- Add to pinned list --->
			<cfset arrayappend(this.aPinCategories,stPin) />
		</cfloop>
	</cffunction>
	
	<cffunction name="revertCategory" access="package" returntype="void" output="false" hint="Reverts a specific category and its references">
		<cfargument name="stPin" type="struct" required="true" hint="The previous category values" />
		
		<cfset var stCurrent = getCategory(stPin.category) />
		<cfset var lReferences = "" />
		<cfset var thisreference = "" />
		<cfset var oCategory = createobject("component","farcry.core.packages.types.dmCategory") />
		
		<cfif not structisempty(stCurrent)>
			<cfset lReferences = getCategoryReferences(stCurrent.categoryid) />
		</cfif>
		
		<cfif structisempty(arguments.stPin.stPre) and not structisempty(stCurrent)><!--- CASE 1: Delete the category --->
			
			<cfset oCategory.deleteCategory(stCurrent.categoryid,application.dsn) />
			
		<cfelseif not structisempty(arguments.stPin.stPre) and structisempty(stCurrent)><!--- CASE 2: Re-add this category --->
			
			<cfset oCategory.addCategory(arguments.stPin.stPre.categoryid,arguments.stPin.stPre.categorylabel,arguments.stPin.stPre.parentid) />
			<cfset oCategory.setAlias(arguments.stPin.stPre.categoryid,arguments.stPin.stPre.alias) />
					
			<cfloop list="#arguments.stPin.lReferences#" index="thisreference">
				<cfquery datasource="#application.dsn#">
					insert 
					into 	#application.dbowner#refCategories
							(categoryid,objectid)
					values	(
								<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.stPin.stPre.categoryid#" />,
								<cfqueryparam cfsqltype="cf_sql_varchar" value="#thisreference#" />
							)
				</cfquery>
			</cfloop>
			
		<cfelse><!--- CASE 3: Revert this category --->
			
			<!--- Update category --->
			<cfset oCategory.setData(stProperties=arguments.stPin) />
			
			<!--- Check parent --->
			<cfif arguments.stPin.stPre.parentid neq stCurrent.parentid>
				<cfset oCategory.moveCategory(arguments.stPin.stPre.categoryid,arguments.stPin.stPre.parentid) />
			</cfif>
			
			<!--- Update references --->
			<cfloop list="#arguments.stPin.lReferences#" index="thisreference">
				<cfif not listcontains(lReferences,thisreference)><!--- Re-add reference --->
					<cfquery datasource="#application.dsn#">
						insert 
						into 	#application.dbowner#refCategories
								(categoryid,objectid)
						values	(
									<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.stPin.stPre.categoryid#" />,
									<cfqueryparam cfsqltype="cf_sql_varchar" value="#thisreference#" />
								)
					</cfquery>
				</cfif>
			</cfloop>
			<cfloop list="#lReferences#" index="thisreference">
				<cfif not listcontains(arguments.stPin.lReferences,thisreference)><!--- Delete reference --->
					<cfquery datasource="#application.dsn#">
						delete 
						from 	#application.dbowner#refCategories
						where 	categoryid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.stPin.stPre.categoryid#" />
								AND objectid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#thisreference#" />
					</cfquery>
				</cfif>
			</cfloop>
		</cfif>
	</cffunction>
	
	<cffunction name="revertCategories" access="package" returntype="void" output="false" hint="Reverts all pinned categories and their references">
		<cfset var i = 0 />
		<cfset var stPin = structnew() />
		<cfset var qCategory = querynew("empty") />
		
		<cfloop from="1" to="#arraylen(this.aPinCategories)#" index="i">
			<cfset revertCategory(this.aPinCategories[i]) />
		</cfloop>
	</cffunction>
	
	
	<cffunction name="pinNavigation" access="package" returntype="void" output="false" hint="Adds the navigation tree to the dirty list, to be reverted on tearDown">
		
		<cfif this.qPinNavigation.recordcount eq 0>
			<cfquery datasource="#application.dsn#" name="this.qPinNavigation">
				select	*
				from	nested_tree_objects
				where	typename='dmNavigation'
			</cfquery>
		</cfif>
	</cffunction>
	
	<cffunction name="revertNavigation" access="package" returntype="void" output="false" hint="Reverts the navigation tree">
		<cfset var q = "" />
		<cfset var qPin = "" />
		
		<cfif this.qPinNavigation.recordcount>
			<cfset qPin = this.qPinNavigation />
			<cfloop query="qPin">
				<cfquery datasource="#application.dsn#" name="q">
					select	* 
					from 	nested_tree_objects 
					where 	objectid='#qPin.objectid#'
							and typename='#qPin.typename#'
				</cfquery>
				
				<cfif q.recordcount and (q.ParentID neq qPin.ParentID or q.ObjectName neq qPin.ObjectName or q.Nleft neq qPin.Nleft or q.Nright neq qPin.Nright or q.Nlevel neq qPin.Nlevel)>
					<!--- Entry was changed and needs to be reverted --->
					<cfquery datasource="#application.dsn#">
						update	nested_tree_objects 
						set		ParentID='#qPin.ParentID#',
								ObjectName='#qPin.ObjectName#', 
								Nleft=#qPin.Nleft#, 
								Nright=#qPin.Nright#, 
								Nlevel=#qPin.Nlevel#
						where	objectid='#qPin.objectid#'
								and typename='#qPin.typename#'
					</cfquery>
				<cfelseif not q.recordcount>
					<!--- Entry was removed and needs to be readded --->
					<cfquery datasource="#application.dsn#">
						insert into nested_tree_objects 
								(ObjectID, ParentID, ObjectName, TypeName, Nleft, Nright, Nlevel)
						values	('#qPin.ObjectID#', 
								'#qPin.ParentID#', 
								'#qPin.ObjectName#', 
								'#qPin.TypeName#', 
								#qPin.Nleft#, 
								#qPin.Nright#, 
								#qPin.Nlevel#)
					</cfquery>
				</cfif>
			</cfloop>
			
			<cfquery datasource="#application.dsn#" name="q">
				select	*
				from	nested_tree_objects
				where	typename=<cfqueryparam cfsqltype="cf_sql_varchar" value="dmNavigation" />
			</cfquery>
			
			<cfloop query="q">
				<cfif not listfind(valuelist(qPin.objectid),q.objectid)>
					<!--- Entry was added and needs to be removed --->
					<cfquery datasource="#application.dsn#">
						delete from nested_tree_objects
						where	objectid='#q.objectid#'
								and typename='#q.typename#'
					</cfquery>
				</cfif>
			</cfloop>
		</cfif>
	</cffunction>
	
	
	<cffunction name="getObjects" access="package" returntype="query" output="false" hint="Returns a query containing information about objects that meet the specified filter">
		<cfargument name="typename" type="string" required="true" hint="The type of object to get" />
		<cfargument name="timeframe" type="numeric" required="false" hint="How old the objects are" />
		
		<cfset var qObjects = querynew("empty") />
		<cfset var thisproperty = "" />
		
		<cfquery datasource="#application.dsn#" name="qObjects" result="stResult">
		select		*
		from		#application.dbowner##arguments.typename#
		where		1=1
					<cfif structkeyexists(arguments,"timeframe")>
						AND datetimecreated><cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateadd('s',0-arguments.timeframe,now())#" />
					</cfif>
					<cfloop collection="#arguments#" item="thisproperty">
						<cfif not refindnocase("(^|,)(typename|timeframe|exceptobjectids)($|,)",thisproperty)>
							AND #thisproperty#=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments[thisproperty]#" />
						</cfif>
					</cfloop>
					<cfif structkeyexists(arguments,"exceptobjectids") and len(arguments.exceptobjectids)>
						AND objectid not in (<cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="#arguments.exceptobjectids#" />)
					</cfif>
		</cfquery>
		
		<cfreturn qObjects />
	</cffunction>

	<cffunction name="pinObjects" access="package" returntype="void" output="false" hint="Adds an object to the dirty list, to be removed on tearDown">
		<cfset var stPin = structnew() />
		<cfset var qObjects = getObjects(argumentCollection=arguments) />
		<cfset var o = createobject("component",application.stCOAPI[arguments.typename].packagepath) />
		
		<!--- Filter --->
		<cfset stPin.filter = duplicate(arguments) />
		
		<!--- Pre-test data --->
		<cfset stPin.aPre = arraynew(1) />
		<cfset stPin.lPre = "" />
		<cfloop query="qObjects">
			<cfset stPin.lPre = listappend(stPin.lPre,qObjects.objectid) />
			<cfset arrayappend(stPin.aPre,o.getData(objectid=qObjects.objectid)) />
		</cfloop>
		
		<cfset arrayappend(this.aPinObjects,stPin) />
	</cffunction>
	
	<cffunction name="revertObjects" access="package" returntype="void" output="false" hint="Reverts all pinned data">
		<cfset var qObjects = querynew("empty") />
		<cfset var o = "" />
		<cfset var thiscolumn = "" />
		<cfset var i = 0 />
		<cfset var j = 0 />
		
		<!--- Remove dirty objects --->
		<cfloop from="1" to="#arraylen(this.aPinObjects)#" index="i">
			<cfset o = createobject("component",application.stCOAPI[this.aPinObjects[i].filter.typename].packagepath) />
			
			<!--- Resave all objects in the old dataset --->
			<cfloop from="1" to="#arraylen(this.aPinObjects[i].aPre)#" index="j">
				<cfset o.setData(stProperties=this.aPinObjects[i].aPre[j]) />
			</cfloop>
			
			<!--- Remove objects that weren't in the old dataset and are in the new one --->
			<cfset this.aPinObjects[i].filter.exceptobjectids = this.aPinObjects[i].lPre />
			<cfset qObjects = getObjects(argumentCollection=this.aPinObjects[i].filter) />
			<cfloop query="qObjects">
				<cfset o.deleteData(objectid=qObjects.objectid) />
			</cfloop>
		</cfloop>
	</cffunction>
	
	
	<cffunction name="pinUsers" access="package" returntype="void" output="false" hint="Adds a user to the dirty list, to be removed on tearDown">
		<cfargument name="userlogins" type="string" required="true" hint="The user's login" />
		
		<cfset var thislogin = "" />
		
		<cfloop list="#arguments.userLogins#" index="thislogin">
			<cfset pinObjects(typename="farUser",userid=thislogin) />
		</cfloop>
	</cffunction>
	
	<cffunction name="revertUsers" access="package" returntype="void" output="false" hint="Reverts all pinned users">
		
		<!--- Nothing special required --->
	</cffunction>
	
	
	<cffunction name="pinScope" access="package" returntype="void" output="false" hint="Pins the specified scope variables">
		<cfargument name="variable" type="string" required="true" hint="The variable to pin" />
		
		<cfset var curval = "" />
		<cfset var stPin = structnew() />
		
		<cfset stPin.variable = arguments.variable />
		
		<cftry>
			<cfset curval = evaluate(arguments.variable) />
			<cfset stPin.value = duplicate(curval) />
			
			<cfcatch>
				<!--- The variable doesn't exist --->
			</cfcatch>
		</cftry>
		
		<cfset arrayappend(this.aPinScopes,stPin) />
	</cffunction>
	
	<cffunction name="revertScopes" access="package" returntype="void" output="false" hint="Reverts the pinned scopes">
		<cfset var i = 0 />
		<cfset var val = "" />
		
		<cfloop from="1" to="#arraylen(this.aPinScopes)#" index="i">
			<!--- If the variable didn't exist and does now, remove it --->
			<cfif not structkeyexists(this.aPinScopes[i],"value")>
				<cftry>
					<cfset val = evaluate(this.aPinScopes[i].variable) />
					<cfset structdelete(listdeleteat(this.aPinScopes[i].variable,listlen(this.aPinScopes[i].variable,"."),"."),listlast(this.aPinScopes[i].variable,".")) />
					
					<cfcatch>
						<!--- This variable doesn't exist --->
					</cfcatch>
				</cftry>
			</cfif>
			
			<!--- If the variable does exist, update it --->
			<cfif structkeyexists(this.aPinScopes[i],"value")>
				<cfset "#this.aPinScopes[i].variable#" = this.aPinScopes[i].value />
			</cfif>
		</cfloop>
	</cffunction>
	
	
	<cffunction name="assertContentTypeExists" access="package" returntype="boolean" hint="Returns true if the specified key exists">
		<cfargument name="typename" type="string" required="true" hint="The typename to attempt to instantiate" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cfset var o = "" />
		
		<cfif structkeyexists(application.stCOAPI,arguments.typename)>
			<cfset o = createobject("component",application.stCOAPI[arguments.typename].packagepath) />
		<cfelse>
			<cfinvoke method="fail" message="#arguments.message#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
	<cffunction name="assertObjectExists" access="package" returntype="boolean" hint="Tests that the specified object exists">
		<cfargument name="typename" type="string" required="true" hint="The type of the object to check for" />
		<cfargument name="timeframe" type="numeric" required="false" hint="Restricts the timeframe to check for logs" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cfset var qObjects = querynew("empty") />
		
		<cfquery datasource="#application.dsn#" name="qObjects">
			select		objectid
			from		#application.dbowner##arguments.typename#
			where		1=1
						<cfif structkeyexists(arguments,"timeframe")>
							AND datetimecreated><cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateadd('s',0-arguments.timeframe,now())#" />
						</cfif>
						<cfloop collection="#arguments#" item="thisproperty">
							<cfif isarray(arguments[thisproperty])>
								<cfif arraylen(arguments[thisproperty])>
									AND objectid in (<!--- Values in the array are all in the database --->
										select		parentid
										from		#application.dbowner##arguments.typename#_#thisproperty#
										where		data in (<cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="#arraytolist(arguments[thisproperty])#" />)
										group by	parentid
										having 		count(parentid)=<cfqueryparam cfsqltype="cf_sql_integer" value="#arraylen(arguments[thisproperty])#" />
									)
								</cfif>
								AND objectid not in (<!--- Values in the database are all in the array --->
									select		parentid
									from		#application.dbowner##arguments.typename#_#thisproperty#
									where		data not in (<cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="#arraytolist(arguments[thisproperty])#" />)
									group by	parentid
									having 		count(parentid)>0
								)
							<cfelseif not listcontainsnocase("typename,timeframe,message",thisproperty)>
								AND #thisproperty#=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments[thisproperty]#" />
							</cfif>
						</cfloop>
		</cfquery>
		
		<cfif not qObjects.recordcount>
			<cfinvoke method="fail" message="#arguments.message#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
	<cffunction name="assertNotObjectExists" access="package" returntype="boolean" hint="Tests that the specified object does not exist">
		<cfargument name="typename" type="string" required="true" hint="The type of the object to check for" />
		<cfargument name="timeframe" type="numeric" required="false" hint="Restricts the timeframe to check for logs" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cfset var qObjects = querynew("empty") />
		
		<cfquery datasource="#application.dsn#" name="qObjects">
			select		objectid
			from		#application.dbowner##arguments.typename#
			where		1=1
						<cfif structkeyexists(arguments,"timeframe")>
							AND datetimecreated><cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateadd('s',0-arguments.timeframe,now())#" />
						</cfif>
						<cfloop collection="#arguments#" item="thisproperty">
							<cfif not listcontainsnocase("typename,timeframe,message",thisproperty)>
								AND #thisproperty#=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments[thisproperty]#" />
							</cfif>
						</cfloop>
		</cfquery>
		
		<cfif qObjects.recordcount>
			<cfinvoke method="fail" message="#arguments.message# #createobject('component',application.stCOAPI[arguments.typename].packagepath).getData(objectid=qObjects.objectid[1]).toString()#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
	
	<cffunction name="assertUser" access="package" returntype="boolean" hint="Tests that the specified user exists">
		<cfargument name="userlogin" type="string" required="true" hint="The type of the object to check for" />
		<cfargument name="userdirectory" type="string" required="true" hint="Restricts the user to a specific user directory" />
		<cfargument name="userstatus" type="string" required="false" hint="Restricts the user to a specific status" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cfset var qObjects = querynew("empty") />
		
		<cfquery datasource="#application.dsn#" name="qObjects">
			select		userid
			from		#application.dbowner#farUser
			where		userid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.userlogin#" />
						<cfif structkeyexists(arguments,"userstatus")>
							AND userstatus=<cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.userstatus#" />
						</cfif>
		</cfquery>
		
		<cfif not qObjects.recordcount>
			<cfinvoke method="fail" message="#arguments.message#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
	<cffunction name="assertUserGroup" access="package" returntype="boolean" hint="Tests that a user is assigned to a group">
		<cfargument name="userlogin" type="string" required="true" hint="The type of the object to check for" />
		<cfargument name="userdirectory" type="string" required="true" hint="Restricts the user to a specific user directory" />
		<cfargument name="group" type="string" required="true" hint="The group to check" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cfset var qObjects = querynew("empty") />
		
		<cfquery datasource="#application.dsn#" name="qObjects">
			select		u.userid
			from		#application.dbowner#farUser u
						inner join
						#application.dbowner#farUser_aGroups ug
						on u.objectid=ug.parentid
						inner join
						#application.dbowner#farGroup g
						on ug.data=g.objectid
			where		u.userid=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.userlogin#" />
						and g.title=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.group#" />
		</cfquery>
		
		<cfif not qObjects.recordcount>
			<cfinvoke method="fail" message="#arguments.message#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
	
	<cffunction name="assertVariable" access="package" returntype="boolean" hint="Tests that a specified variable has been declared and has the specified value">
		<cfargument name="variable" type="string" required="true" hint="The variable to check" />
		<cfargument name="value" type="string" required="false" hint="The value to check for" />
		<cfargument name="message" type="string" required="false" default="" hint="The message to record on failure" />
		
		<cftry>
			<cfset var curval = evaluate(arguments.variable) />
			
			<cfif structkeyexists(arguments,"value") and curval neq arguments.value>
				<cfinvoke method="fail" message="#arguments.message#" />
			</cfif>
			
			<cfcatch>
				<cfinvoke method="fail" message="#arguments.message#" />
			</cfcatch>
		</cftry>
		
		<cfreturn true />
	</cffunction>
	
	
	<cffunction name="combineErrors" access="package" returntype="array" hint="Agregates errors into single structs">
		<cfargument name="errors" type="array" required="true" />
		<cfargument name="message" type="string" required="true" />
		<cfargument name="template" type="string" required="true" />
		<cfargument name="line" type="string" required="true" />
		<cfargument name="object" type="struct" required="false" />
		
		<cfset var i = 0 />
		<cfset var stError = structnew() />
		
		<cfparam name="arguments.errors" default="#arraynew(1)#" />
		
		<cfloop from="1" to="#arraylen(arguments.errors)#" index="i">
			<cfif arguments.errors[i].message eq arguments.message 
				and arguments.errors[i].template eq arguments.template
				and arguments.errors[i].line eq arguments.line>
				<cfset arguments.errors[i].count = arguments.errors[i].count + 1 />
				<cfif structkeyexists(arguments,"object")>
					<cfset arrayappend(arguments.errors[i].object,"#arguments.object.label# [#arguments.object.objectid#]") />
				</cfif>
				<cfreturn arguments.errors />
			</cfif>
		</cfloop>
		
		<cfset stError.message = arguments.message />
		<cfset stError.template = arguments.template />
		<cfset stError.line = arguments.line />
		<cfset stError.count = 1 />
		<cfset stError.object = arraynew(1) />
		<cfif structkeyexists(arguments,"object")>
			<cfset arrayappend(stError.object,"#arguments.object.label# [#arguments.object.objectid#]") />
		</cfif>
		<cfset arrayappend(arguments.errors,stError) />
		
		<cfreturn arguments.errors />
	</cffunction>
	
	<cffunction name="assertWebskins" access="package" returntype="boolean" hint="Tests webskins for a specified type / set of objects. This will throw an error with details instead of failing.">
		<cfargument name="typename" type="string" required="true" hint="Type being tested" />
		<cfargument name="stObject" type="struct" required="false" hint="Object to test with. One of stObject|aObjects|objectid|lObjectIDs|nRandom needs to be defined or only type webskins will be tested." />
		<cfargument name="aObjects" type="array" required="false" default="#arraynew(1)#" hint="Set of objects to test with. One of stObject|aObjects|objectid|lObjectIDs|nRandom needs to be defined or only type webskins will be tested." />
		<cfargument name="objectid" type="uuid" required="false" hint="ID of object to test with. One of stObject|aObjects|objectid|lObjectIDs|nRandom needs to be defined or only type webskins will be tested." />
		<cfargument name="lObjectIds" type="string" required="false" hint="Set of objects to test with. One of stObject|aObjects|objectid|lObjectIDs|nRandom needs to be defined or only type webskins will be tested." />
		<cfargument name="nRandom" type="numeric" required="false" hint="Number of random objects in the database to test with. One of stObject|aObjects|objectid|nRandom needs to be defined or only type webskins will be tested." />
		<cfargument name="viewbinding" type="string" required="false" default="all" hint="Restrict tests to webskins of a certain binding. NOTE: webskins that are bound to 'any' are treated as 'object' webskins." options="type,object,all" />
		<cfargument name="viewstack" type="string" required="false" default="all" hint="Restrict tests to webskins of a certain stack level. NOTE: webskins that are not at a particular stack level (i.e. any) are treated as 'fragment' webskins." options="all,page,body,ajax,fragment" />
		<cfargument name="lWebskins" type="string" required="false" hint="Only test the specified webskins." />
		<cfargument name="lExcludeWebskins" type="string" required="false" default="" hint="Exclude specified webskins from tests." />
		<cfargument name="regex" type="string" required="false" default="" hint="Additional test with regex. Default is to only text webskin execution, not specific content." />
		
		<cfset var qRandom = "" />
		<cfset var thisobject = 0 />
		<cfset var thiswebskin = "" />
		<cfset var stWebskinResult = structnew() />
		<cfset var thishtml = "" />
		<cfset var stError = structnew() />
		<cfset var counterrors = 0 />
		<cfset var aResults = arraynew(1) />
		<cfset var sResults = "" />
		<cfset var cfhttp = structnew() />
		
		<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
		
		<cfparam name="arguments.lWebskins" default="#structkeylist(application.stCOAPI[arguments.typename].stWebskins)#" />
		
		<cfif arraylen(arguments.aObjects)>
			<cfloop from="1" to="#arraylen(arguments.aObjects)#" index="thisobject">
				<cfset arguments.aObjects[thisobject] = application.fapi.getContentObject(typename=arguments.typename,objectid=arguments.aObjects[thisobject]) />
			</cfloop>
		<cfelseif structkeyexists(arguments,"stObject")>
			<cfset arrayappend(arguments.aObjects,arguments.stObject) />
		<cfelseif structkeyexists(arguments,"objectid")>
			<cfset arrayappend(arguments.aObjects,application.fapi.getContentObject(typename=arguments.typename,objectid=arguments.objectid)) />
		<cfelseif structkeyexists(arguments,"lObjectIDs")>
			<cfloop list="#arguments.lObjectIDs#" index="thisobject">
				<cfset arrayappend(arguments.aObjects, application.fapi.getContentObject(typename=arguments.typename,objectid=thisobject)) />
			</cfloop>
		<cfelseif structkeyexists(arguments,"nRandom")>
			<cfswitch expression="#application.dbtype#">
				<cfcase value="mysql,mysql5" delimiters=",">
					<cfset qRandom = application.fapi.getContentObjects(typename=arguments.typename,status="approved,pending,draft",maxRows=arguments.nRandom,orderBy="rand() asc") />
				</cfcase>
				<cfcase value="mssql">
					<cfset qRandom = application.fapi.getContentObjects(typename=arguments.typename,status="approved,pending,draft",maxRows=arguments.nRandom,orderBy="newid() asc") />
				</cfcase>
			</cfswitch>
			<cfloop query="qRandom">
				<cfset arrayappend(arguments.aObjects,application.fapi.getContentObject(typename=arguments.typename,objectid=qRandom.objectid)) />
			</cfloop>
		</cfif>
		
		<cfif not arraylen(arguments.aObjects)>
			<cfif arguments.viewbinding eq "object">
				<cfthrow message="No objects are available to test with" />
			<cfelseif listcontainsnocase(arguments.viewbinding,"object")>
				<cfset arguments.viewbinding = listdeleteat(arguments.viewbinding,listfindnocase(arguments.viewbinding,"object")) />
			<cfelseif arguments.viewbinding eq "all">
				<cfset arguments.viewbinding = "type" />
			</cfif>
		</cfif>
		<cfif arguments.viewbinding eq "all">
			<cfset arguments.viewbinding = "type,object" />
		</cfif>
		
		<cfif arguments.viewstack eq "all">
			<cfset arguments.viewstack = "page,body,ajax,fragment" />
		</cfif>
		
		<cfloop list="#arguments.lWebskins#" index="thiswebskin">
			<cfset stWebskinResult = structnew() />
			<cfset stWebskinResult.displayname = thiswebskin />
			<cfset stWebskinResult.path = application.stCOAPI[arguments.typename].stWebskins[thiswebskin].path />
			<cfif structkeyexists(application.stCOAPI[arguments.typename].stWebskins[thiswebskin],"displayname")>
				<cfset stWebskinResult.displayname = application.stCOAPI[arguments.typename].stWebskins[thiswebskin].displayname />
			</cfif>
			<cfif application.stCOAPI[arguments.typename].stWebskins[thiswebskin].viewbinding eq "any">
				<cfset stWebskinResult.viewbinding = "object" />
			<cfelse>
				<cfset stWebskinResult.viewbinding = application.stCOAPI[arguments.typename].stWebskins[thiswebskin].viewbinding />
			</cfif>
			<cfif application.stCOAPI[arguments.typename].stWebskins[thiswebskin].viewstack eq "any">
				<cfset stWebskinResult.viewstack = "fragment" />
			<cfelse>
				<cfset stWebskinResult.viewstack = application.stCOAPI[arguments.typename].stWebskins[thiswebskin].viewstack />
			</cfif>
			<cfset stWebskinResult.successes = 0 />
			<cfset stWebskinResult.errors = arraynew(1) />
			
			<cfif listcontainsnocase(arguments.viewbinding,stWebskinResult.viewbinding) and listcontainsnocase(arguments.viewstack,stWebskinResult.viewstack) and not listcontainsnocase(arguments.lExcludeWebskins,thiswebskin)>
				<cfif stWebskinResult.viewbinding eq "object">
					<cfloop from="1" to="#arraylen(arguments.aObjects)#" index="thisobject">
						<cfset pinObjects(typename=arguments.typename,objectid=arguments.aObjects[thisobject].objectid) />
						
						<cftry>
							<cfif stWebskinResult.viewstack eq "page">
								<cfhttp url="#application.fapi.getLink(objectid=arguments.aObjects[thisobject].objectid,view=thiswebskin,includedomain=1)#" timeout="15" redirect="false" />
								
								<cfif find("200",cfhttp.StatusCode)>
									<cfif len(arguments.regex) and not refindnocase(arguments.regex,cfhttp.FileContent)>
										<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,"Output failed to validate against the supplied regex",stWebskinResult.path,0,arguments.aObjects[thisobject]) />
									<cfelse>
										<cfset stWebskinResult.successes = stWebskinResult.successes + 1 />
									</cfif>
								<cfelse>
									<cfset cfhttp = duplicate(cfhttp) />
									<cfset cfhttp.url = application.fapi.getLink(objectid=arguments.aObjects[thisobject].objectid,view=thiswebskin,includedomain=1) />
									<cfwddx action="cfml2wddx" input="#cfhttp#" output="cfhttp" />
									<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,cfhttp,"",0,arguments.aObjects[thisobject]) />
								</cfif>
							<cfelse>
								<skin:view stObject="#arguments.aObjects[thisobject]#" typename="#arguments.typename#" webskin="#thiswebskin#" r_html="thishtml" />
								
								<cfif len(arguments.regex) and not refindnocase(arguments.regex,thishtml)>
									<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,"Output failed to validate against the supplied regex",stWebskinResult.path,0,arguments.aObjects[thisobject]) />
								<cfelse>
									<cfset stWebskinResult.successes = stWebskinResult.successes + 1 />
								</cfif>
							</cfif>
							
							<cfcatch>
								<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,cfcatch.message,cfcatch.tagcontext[1].template,cfcatch.tagcontext[1].line,arguments.aObjects[thisobject]) />
							</cfcatch>
						</cftry>
						
						<cfset revertObjects() />
					</cfloop>
				<cfelse>
					<cftry>
						<cfif stWebskinResult.viewstack eq "page">
							<cfhttp url="#application.fapi.getLink(typename=arguments.typename,view=thiswebskin,includedomain=1)#" timeout="15" redirect="false" />
							
							<cfif find("200",cfhttp.StatusCode)>
								<cfif not len(arguments.regex) or not refindnocase(arguments.regex,cfhttp.FileContent)>
									<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,"Output failed to validate against the supplied regex",stWebskinResult.path,0) />
								<cfelse>
									<cfset stWebskinResult.successes = stWebskinResult.successes + 1 />
								</cfif>
							<cfelse>
								<cfset cfhttp = duplicate(cfhttp) />
								<cfset cfhttp.url = application.fapi.getLink(typename=arguments.typename,view=thiswebskin,includedomain=1) />
								<cfwddx action="cfml2wddx" input="#cfhttp#" output="cfhttp" />
								<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,cfhttp,"",0) />
							</cfif>
						<cfelse>
							<skin:view typename="#arguments.typename#" webskin="#thiswebskin#" r_html="thishtml" />
							
							<cfif not len(arguments.regex) or not refindnocase(arguments.regex,thishtml)>
								<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,"Output failed to validate against the supplied regex",stWebskinResult.path,0) />
							<cfelse>
								<cfset stWebskinResult.successes = stWebskinResult.successes + 1 />
							</cfif>
						</cfif>
						
						<cfcatch>
							<cfset stWebskinResult.errors = combineErrors(stWebskinResult.errors,cfcatch.message,cfcatch.tagcontext[1].template,cfcatch.tagcontext[1].line) />
						</cfcatch>
					</cftry>
				</cfif>
				
				<cfset arrayappend(aResults,stWebskinResult) />
				<cfset counterrors = counterrors + arraylen(stWebskinResult.errors) />
			</cfif>
		</cfloop>
		
		<cfif counterrors>
			<cfwddx action="cfml2wddx" input="#aResults#" output="sResults" />
			<cfthrow message="Webskin tests failed" detail="#sResults#" />
		</cfif>
		
		<cfreturn true />
	</cffunction>
	
</cfcomponent>