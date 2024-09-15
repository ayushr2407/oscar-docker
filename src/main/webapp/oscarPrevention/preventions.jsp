<%--

    Copyright (c) 2001-2002. Department of Family Medicine, McMaster University. All Rights Reserved.
    This software is published under the GPL GNU General Public License.
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

    This software was written for the
    Department of Family Medicine
    McMaster University
    Hamilton
    Ontario, Canada

--%>

<%@page import="oscar.OscarProperties"%>

<%@page import="oscar.oscarPrevention.*"%>
<%@page import="org.oscarehr.managers.SecurityInfoManager"%>
<%@page import="org.oscarehr.util.LoggedInInfo"%>
<%@page import="org.oscarehr.util.SpringUtils"%>
<%@page import="org.oscarehr.util.MiscUtils"%>
<%@page import="org.oscarehr.managers.PreventionManager"%>
<%@page import="org.oscarehr.common.model.CVCMapping"%>
<%@page import="org.oscarehr.common.dao.CVCMappingDao"%>
<%@page import="org.oscarehr.common.model.DHIRSubmissionLog"%>
<%@page import="org.oscarehr.managers.DHIRSubmissionManager"%>
<%@page import="org.oscarehr.common.model.Consent"%>
<%@page import="org.oscarehr.common.dao.ConsentDao"%>

<%@page import="java.util.ArrayList"%>
<%@page import="java.util.*"%>
<%@page import="java.text.SimpleDateFormat"%>

<%@page import="org.apache.commons.lang.StringUtils"%>
<%@page import="org.apache.commons.lang.StringEscapeUtils"%>
<%@page import="org.apache.logging.log4j.Logger"%>
<%@page import="org.owasp.encoder.Encode"%>

<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean"%>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html"%>
<%@ taglib uri="/WEB-INF/oscar-tag.tld" prefix="oscar"%>
<%@ taglib uri="/WEB-INF/rewrite-tag.tld" prefix="rewrite"%>
<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
    String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");
	boolean authed=true;
%>
<security:oscarSec roleName="<%=roleName$%>" objectName="_prevention"
	rights="r" reverse="<%=true%>">
	<%authed=false; %>
	<%response.sendRedirect(request.getContextPath() + "/securityError.jsp?type=_prevention");%>
</security:oscarSec>
<%
if(!authed) {
	return;
}
%>
<%!
	public String getFromFacilityMsg(Map<String,Object> ht)
	{
		if (ht.get("id")==null)	return("<br /><span style=\"color:#990000\">(At facility : "+ht.get("remoteFacilityName")+")<span>");
		else return("");
	}
%>

<%
	long startTime = System.nanoTime();
    long endTime = System.nanoTime();
    Logger logger = MiscUtils.getLogger();
    logger.info("Starting loading preventions themselves");
    PreventionDisplayConfig pdc = PreventionDisplayConfig.getInstance();
    ArrayList<HashMap<String,String>> prevList = pdc.getPreventions();
    ArrayList<Map<String,Object>> configSets = pdc.getConfigurationSets();
	String demographic_no = request.getParameter("demographic_no");
    Integer demographicId=Integer.parseInt(demographic_no);
	LoggedInInfo loggedInInfo=LoggedInInfo.getLoggedInInfoFromSession(request);
    boolean bIntegrator = loggedInInfo.getCurrentFacility().isIntegratorEnabled();
    boolean bComment = OscarProperties.getInstance().getBooleanProperty("prevention_show_comments","yes");
    boolean bShowAll = OscarProperties.getInstance().getBooleanProperty("showAllPreventions","yes");
    Date demographicDateOfBirth=PreventionData.getDemographicDateOfBirth(loggedInInfo, Integer.valueOf(demographic_no));
    CVCMappingDao cvcMappingDao = SpringUtils.getBean(CVCMappingDao.class);

	DHIRSubmissionManager submissionManager = SpringUtils.getBean(DHIRSubmissionManager.class);
    boolean dhirEnabled=false;
  	if("true".equals(OscarProperties.getInstance().getProperty("dhir.enabled", "false"))) {
  		dhirEnabled=true;
  	}
	ConsentDao consentDao = SpringUtils.getBean(ConsentDao.class);
	Consent ispaConsent =  consentDao.findByDemographicAndConsentType(demographicId, "dhir_ispa_consent");
	Consent nonIspaConsent =  consentDao.findByDemographicAndConsentType(demographicId, "dhir_non_ispa_consent");

	boolean isSSOLoggedIn = session.getAttribute("oneIdEmail") != null;
	boolean hasIspaConsent = ispaConsent != null && !ispaConsent.isOptout();
	boolean hasNonIspaConsent = nonIspaConsent != null && !nonIspaConsent.isOptout();
%>
    <form name="printFrm" method="post" onsubmit="return onPrint();"
	    action="<rewrite:reWrite jspPage="printPrevention.do"/>">
	    <input type="hidden" name="immunizationOnly" value="false" />
<%
    if (!oscar.OscarProperties.getInstance().getBooleanProperty("PREVENTION_CLASSIC_VIEW","yes")){
        ArrayList<Map<String,Object>> hiddenlist = new ArrayList<Map<String,Object>>();
        Map<String,String> shownBefore = new HashMap<String,String>();//See explanation below.
        for (int i = 0 ; i < prevList.size(); i++){
            HashMap<String,String> h = prevList.get(i);
            String prevName = h.get("name");
            //This is here because the CVC integration adds all the CVC Immunizations as possible types BUT the list is not unique.
            //So there are two Mumps types. If a mumps vaccine is added without this two lines will show with the same preventions.
            if(shownBefore.containsKey(prevName)){
                continue;
            }else{
                shownBefore.put(prevName, prevName);
            }
            ArrayList<Map<String,Object>> alist = PreventionData.getPreventionData(loggedInInfo, prevName, Integer.valueOf(demographic_no));
            if (bIntegrator){PreventionData.addRemotePreventions(loggedInInfo, alist, demographicId,prevName,demographicDateOfBirth);}
            boolean show = pdc.display(loggedInInfo, h, demographic_no,alist.size());
            if(!show){
                Map<String,Object> h2 = new HashMap<String,Object>();
                h2.put("prev",h);
                h2.put("list",alist);
                hiddenlist.add(h2);
            }else{
%>
        <div class="preventionSection">
		    <!-- <%=prevName%> <%=i%> of <%=prevList.size()%> -->
            <input type="hidden" id="preventionHeader<%=i%>"
				name="preventionHeader<%=i%>" value="<%=h.get("name")%>">
    <%
                String snomedId = h.get("snomedConceptCode") != null ? h.get("snomedConceptCode") : null;
                boolean ispa = h.get("ispa") != null ? Boolean.valueOf(h.get("ispa")) : false;
                String ispa1 = "";
                if (ispa) {
				    ispa1 = "*";
			    }
			    if (alist.size() > 0) {
    %>
		    <div style="position: relative; float: left; padding-right: 10px;">
			    <input style="display: none;" type="checkbox" name="printHP"
				    value="<%=i%>" checked />
        <%
			    } else {
	    %>
			<div style="position: relative; float: left; padding-right: 25px;">
			    <span style="display: none;" name="printSp">&nbsp;</span>
		<%
		        }
		%>
            </div>
            <div class="headPrevention">
			    <p>
    <%
			    List<CVCMapping> mappings = cvcMappingDao.findMultipleByOscarName(prevName);
			    String displayName = h.get("displayName") != null ? h.get("displayName") : prevName;
			    if (mappings != null && mappings.size() > 1) {
	    %>
			    <a href="javascript: function myFunction() {return false; }"
				    onclick="javascript:popup(600,1100,'AddPreventionDataDisambiguate.jsp?1=1&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%=java.net.URLEncoder.encode(h.get("name"))%>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%=java.net.URLEncoder.encode(h.get("resultDesc"))%>','addPreventionData<%=Math.abs((h.get("name")).hashCode())%>')">
			        <span title="<%=h.get("desc")%>" style="font-weight: bold;"><%=ispa1%><%=displayName%></span>
				</a>
	    <%
				} else {
	    %>
				<a href="javascript: function myFunction() {return false; }"
				    onclick="javascript:popup(820,800,'AddPreventionData.jsp?1=1&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%=java.net.URLEncoder.encode(h.get("name"))%>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%=java.net.URLEncoder.encode(h.get("resultDesc"))%>','addPreventionData<%=Math.abs((h.get("name")).hashCode())%>')">
				    <span title="<%=h.get("desc")%>" style="font-weight: bold;"><%=ispa1%><%=displayName%></span>
				</a>
	    <%
			    }
	    %>
			    <br />
			    </p>
			</div>
    <%
                endTime = System.nanoTime();
                logger.info("Iterating " + h.get("name") + " at " + ((endTime - startTime)/1000)/1000 + " milliseconds");
			    String result;
			    for (int k = 0; k < alist.size(); k++) {
			    Map<String, Object> hdata = alist.get(k);
			    Map<String, String> hExt = PreventionData.getPreventionKeyValues((String) hdata.get("id"));
			    result = hExt.get("result");
                String onClickCode = "javascript:popup(820,800,'AddPreventionData.jsp?id=" + hdata.get("id")
				    + "&amp;demographic_no=" + demographic_no + "','addPreventionData')";
			    if (hdata.get("id") == null)
				    onClickCode = "popup(300,500,'display_remote_prevention.jsp?remoteFacilityId="
				    + hdata.get("integratorFacilityId") + "&remotePreventionId=" + hdata.get("integratorPreventionId")
					+ "&amp;demographic_no=" + demographic_no + "')";
    %>

            <input type="hidden" id="preventProcedureProvider<%=i%>-<%=k%>" name="preventProcedureProvider<%=i%>-<%=k%>" value="<%=hdata.get("provider_name")%>" />
            <input type="hidden" id="preventProcedureStatus<%=i%>-<%=k%>" name="preventProcedureStatus<%=i%>-<%=k%>" value="<%=hdata.get("refused")%>">
            <input type="hidden" id="preventProcedureAge<%=i%>-<%=k%>" name="preventProcedureAge<%=i%>-<%=k%>" value="<%=hdata.get("age")%>">
            <input type="hidden" id="preventProcedureDate<%=i%>-<%=k%>" name="preventProcedureDate<%=i%>-<%=k%>" value="<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>">

         <%  String comments = hExt.get("comments");
			if (comments != null && !comments.isEmpty()) {%>
				<input type="hidden" id="preventProcedureComments<%=i%>-<%=k%>"
					name="preventProcedureComments<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(comments)%>">
		<%  } %>

		<%
			if (result != null && !result.isEmpty()) {%>
				<input type="hidden" id="preventProcedureResult<%=i%>-<%=k%>"
					name="preventProcedureResult<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(result)%>">
		<%  } %>

		<%  String reason = hExt.get("reason");
			if (reason != null && !reason.isEmpty()) {%>
				<input type="hidden" id="preventProcedureReason<%=i%>-<%=k%>"
					name="preventProcedureReason<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(reason)%>">
		<%  } %>

		<%  String nameOfVaccine = hExt.get("name");
			if (nameOfVaccine != null && !nameOfVaccine.isEmpty()) {%>
				<input type="hidden" id="preventProcedureNameOfVaccine<%=i%>-<%=k%>"
					name="preventProcedureNameOfVaccine<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(nameOfVaccine)%>">
		<%  } %>

		<%  String manufacture = hExt.get("manufacture");
			if (manufacture != null && !manufacture.isEmpty()) {%>
				<input type="hidden" id="preventProcedureManufacture<%=i%>-<%=k%>"
					name="preventProcedureManufacture<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(manufacture)%>">
		<%  } %>

		<%  String lotID = hExt.get("lot");
			if (lotID != null && !lotID.isEmpty()) {%>
				<input type="hidden" id="preventProcedureLotID<%=i%>-<%=k%>"
					name="preventProcedureLotID<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(lotID)%>">
		<%  } %>

		<%  String doseAdministered = hExt.get("dose");
			if (doseAdministered != null && !doseAdministered.isEmpty()) {%>
				<input type="hidden" id="preventProcedureDoseAdministered<%=i%>-<%=k%>"
					name="preventProcedureDoseAdministered<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(doseAdministered)%>">
		<%  } %>

		<%  String locationOfShot = hExt.get("location");
			if (locationOfShot != null && locationOfShot.matches("\\d+")) {
				// for CVC the location is a numeric code, get the human readable location display
				locationOfShot = hExt.get("locationDisplay");
			}
			if (locationOfShot != null && !locationOfShot.isEmpty() && !locationOfShot.matches("\\d+")) { %>
				<input type="hidden" id="preventProcedureLocationOfShot<%=i%>-<%=k%>"
					name="preventProcedureLocationOfShot<%=i%>-<%=k%>"
					value="<%=StringEscapeUtils.escapeHtml(locationOfShot)%>">
		<%  } %>

            <div class="preventionProcedure" onclick="<%=onClickCode%>"
			    title="fade=[on] header=[<%=StringEscapeUtils.escapeHtml((String) hdata.get("age"))%> -- Date:<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>] body=[<%=StringEscapeUtils.escapeHtml((String) hExt.get("comments"))%>&lt;br/&gt;Administered By: <%=StringEscapeUtils.escapeHtml((String) hdata.get("provider_name"))%>]">
                <p <%=r(hdata.get("refused"), result)%>>
				    Age:<%=StringEscapeUtils.escapeHtml((String) hdata.get("age"))%>
    <%
			    if (result != null && result.equals("abnormal")) {
				    out.print("result:" + StringEscapeUtils.escapeHtml(result));
			    }
	%>
				<br />

				    Date:<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>
    <%
			    if (hExt.get("comments") != null && (hExt.get("comments")).length() > 0) {
				    if (bComment) {
	    %>
				<div class="comments">
				    <span><%=StringEscapeUtils.escapeHtml((String) hExt.get("comments"))%></span>
			    </div>
	    <%
				    } else {
	    %>
				    <span class="footnote">1</span>
	    <%
				    }
			    }
    %>
    <%
				/* Integrated results dont have an "ID" key */
				if (hdata.containsKey("id")) {
				    List<DHIRSubmissionLog> dhirLogs = submissionManager.findByPreventionId(Integer.parseInt((String) hdata.get("id")));
                    if (!dhirLogs.isEmpty()) {
	        %>
			    <span class="footnote"
				    style="background-color: black; color: white"><%=dhirLogs.get(0).getStatus()%></span>
		    <%
					} else {
					    if (dhirEnabled && !StringUtils.isEmpty(snomedId)) {
						    if ((ispa && hasIspaConsent) || (!ispa && hasNonIspaConsent)) {
                %>
                <span class="footnote"
				    style="background-color: orange; color: black; white-space: nowrap">Not Submitted</span>
			    <%
				            }
					    }
				    }
			    }
    %>

				    <%=getFromFacilityMsg(hdata)%></p>
			    </div>
    <%
            }
    %>
			</div>
    <%
        }
    }
%>
<%if(bShowAll){
									%>

									<a href="#"
										onclick="Element.toggle('otherElements'); return false;"
										style="font-size: xx-small;">show/hide all other
										Preventions</a>
									<div style="display: none;" id="otherElements">
										<%
                                        endTime = System.nanoTime();
                                        logger.info("Starting to render otherElements after " + ((endTime - startTime)/1000)/1000 + " milliseconds");

										for (int i = 0; i < hiddenlist.size(); i++) {
											Map<String, Object> h2 = hiddenlist.get(i);
											HashMap<String, String> h = (HashMap<String, String>) h2.get("prev");
											String prevName = h.get("name");
											String displayName = h.get("displayName") != null ? h.get("displayName") : prevName;
											ArrayList<HashMap<String, String>> alist = (ArrayList<HashMap<String, String>>) h2.get("list");
										%>
										<div class="preventionSection">
											<!-- start div -->
											<%
											if (alist.size() > 0) {
											%>
											<div
												style="position: relative; float: left; padding-right: 10px;">
												<input style="display: none;" type="checkbox" name="printHP"
													value="<%=i%>" checked />
												<%
												} else {
												%>
												<div
													style="position: relative; float: left; padding-right: 25px;">
													<span style="display: none;" name="printSp">&nbsp;</span>
													<%
													}
													String snomedId = h.get("snomedConceptCode") != null ? h.get("snomedConceptCode") : null;
													boolean ispa = h.get("ispa") != null ? Boolean.valueOf(h.get("ispa")) : false;
													String ispa1 = "";
													if (ispa) {
													ispa1 = "*";
													}
													%>
												</div>
												<div class="headPrevention">
													<p>
														<a
															href="javascript: function myFunction() {return false; }"
															onclick="javascript:popup(820,800,'AddPreventionData.jsp?2=2&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%=java.net.URLEncoder.encode(h.get("name"))%>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%=java.net.URLEncoder.encode(h.get("resultDesc"))%>','addPreventionData<%=Math.abs((h.get("name")).hashCode())%>')">
															<span title="<%=h.get("desc")%>"
															style="font-weight: bold;"><%=ispa1%><%=displayName%></span>
														</a> <br />
													</p>
												</div>
												<%
												String result;
												for (int k = 0; k < alist.size(); k++) {
													Map<String, String> hdata = alist.get(k);
													Map<String, String> hExt = PreventionData.getPreventionKeyValues(hdata.get("id"));
													result = hExt.get("result");
												%>
												<div class="preventionProcedure"
													onclick="javascript:popup(820,800,'AddPreventionData.jsp?id=<%=hdata.get("id")%>&amp;demographic_no=<%=demographic_no%>','addPreventionData')"
													title="fade=[on] header=[<%=StringEscapeUtils.escapeHtml((String) hdata.get("age"))%> -- Date:<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>] body=[<%=StringEscapeUtils.escapeHtml((String) hExt.get("comments"))%>&lt;br/&gt;Administered By: <%=StringEscapeUtils.escapeHtml((String) hdata.get("provider_name"))%>]">
													<p <%=r(hdata.get("refused"), result)%>>
														Age:
														<%=hdata.get("age")%>
														<br />
														<!--<%=refused(hdata.get("refused"))%>-->
														Date:
														<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>
														<%
														if (hExt.get("comments") != null && (hExt.get("comments")).length() > 0) {
															if (oscar.OscarProperties.getInstance().getBooleanProperty("prevention_show_comments", "yes")) {
														%>
														<div class="comments">
															<span><%=StringEscapeUtils.escapeHtml((String) hExt.get("comments"))%></span>
														</div>
														<%
														} else {
														%>
														<span class="footnote">1</span>
														<%
														}
														}
														%>
														<%
														/* Integrated results dont have an "ID" key */
														if (hdata.containsKey("id")) {
															List<DHIRSubmissionLog> dhirLogs = submissionManager.findByPreventionId(Integer.parseInt((String) hdata.get("id")));

															if (!dhirLogs.isEmpty()) {
														%>
														<span class="footnote"
															style="background-color: black; color: white"><%=dhirLogs.get(0).getStatus()%></span>
														<%
														} else {
														if (dhirEnabled && !StringUtils.isEmpty(snomedId)) {
															if ((ispa && hasIspaConsent) || (!ispa && hasNonIspaConsent)) {
														%><span class="footnote"
															style="background-color: orange; color: black">Not
															Submitted</span>
														<%
														}
														}
														}
														}
														%>
													</p>
												</div>
												<%
												}
												%>
											</div>

											<%
											}
											%>
										</div>
										<%
										} else { //OLD
    if(bShowAll){
										if (configSets == null) {
											configSets = new ArrayList<Map<String, Object>>();
										}

										for (int setNum = 0; setNum < configSets.size(); setNum++) {
											Map<String, Object> setHash = configSets.get(setNum);
											String[] prevs = (String[]) setHash.get("prevList");
										%>
										<div class="immSet">
											<h2 style="display: block;"><%=setHash.get("title")%>
												<span><%=setHash.get("effective")%></span>
											</h2>
											<!--a style="font-size:xx-small;" onclick="javascript:showHideItem("prev" + setNumtNum%>')" href="javascript: function myFunction() {return false; }" >show/hide</a-->
											<a href="#"
												onclick="Element.toggle('<%="prev" + setNum%>'); return false;"
												style="font-size: xx-small;">show/hide</a>
											<div class="preventionSet"
												<%=pdc.getDisplay(loggedInInfo, setHash, demographic_no)%>;"  id="<%="prev" + setNum%>">
												<%
												for (int i = 0; i < prevs.length; i++) {
													HashMap<String, String> h = pdc.getPrevention(prevs[i]);
												%>
												if(h == null) { //this happens with private entries
												continue; } %>
												<div class="preventionSection">
													<div class="headPrevention">
														<p>
															<a
																href="javascript: function myFunction() {return false; }"
																onclick="javascript:popup(820,800,'AddPreventionData.jsp?3=3&prevention=<%=java.net.URLEncoder.encode(h.get("name"))%>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%=java.net.URLEncoder.encode(h.get("resultDesc"))%>','addPreventionData<%=Math.abs(h.get("name").hashCode())%>')">
																<span title="<%=h.get("desc")%>"
																style="font-weight: bold;"><%=h.get("name")%></span>
															</a> <br />
														</p>
													</div>
													<%
													String prevType = h.get("name");
													ArrayList<Map<String, Object>> alist = PreventionData.getPreventionData(loggedInInfo, prevType,
															Integer.valueOf(demographic_no));
													if (bIntegrator){PreventionData.addRemotePreventions(loggedInInfo, alist, demographicId, prevType, demographicDateOfBirth);}
													String result;
													for (int k = 0; k < alist.size(); k++) {
														Map<String, Object> hdata = alist.get(k);
														Map<String, String> hExt = PreventionData.getPreventionKeyValues((String) hdata.get("id"));
														result = hExt.get("result");

														String onClickCode = "javascript:popup(820,800,'AddPreventionData.jsp?id=" + hdata.get("id")
														+ "&amp;demographic_no=" + demographic_no + "','addPreventionData')";
														if (hdata.get("id") == null)
															onClickCode = "popup(300,500,'display_remote_prevention.jsp?remoteFacilityId="
															+ hdata.get("integratorFacilityId") + "&remotePreventionId=" + hdata.get("integratorPreventionId")
															+ "&amp;demographic_no=" + demographic_no + "')";
													%>
													<div class="preventionProcedure" onclick="<%=onClickCode%>">
														<p <%=r(hdata.get("refused"), result)%>>
															Age:
															<%=hdata.get("age")%>
															<br />
															<!--<%=refused(hdata.get("refused"))%>-->
															Date:
															<%=StringEscapeUtils.escapeHtml((String) hdata.get("prevention_date_no_time"))%>
															<%=getFromFacilityMsg(hdata)%></p>
													</div>
													<%
													}
													%>
												</div>
												<%
												}
												%>
											</div> <!--immSet-->
    <% }%>
										</div> <!--end otherElements-->
<% }%>

										<%
                                        endTime = System.nanoTime();
                                        logger.info("Thats all folks after " + ((endTime - startTime)/1000)/1000 + " milliseconds");
										}
										}
										%>
<%!
String refused(Object re){
        String ret = "Given";
        if (re instanceof java.lang.String){

        if (re != null && re.equals("1")){
           ret = "Refused";
        }
        }
        return ret;
    }

String r(Object re, String result){
        String ret = "";
        if (re instanceof java.lang.String){
           if (re != null && re.equals("1")){
              ret = "style=\"background: #FFDDDD;\"";
           }else if(re !=null && re.equals("2")){
              ret = "style=\"background: #FFCC24;\"";
           }
           else if( result != null && result.equalsIgnoreCase("pending")) {
               ret = "style=\"background: #FF00FF;\"";
           }
           else if( result != null && result.equalsIgnoreCase("other")) {
               ret = "style=\"background: #BDFCC9;\"";
           }
           else if(result!=null && result.equals("abnormal")){
	        	   ret = "style=\"background: #ee5f5b;\"";

           }
        }
        return ret;
    }

%>
            <span id="print_buttons">
                <input type="button" class="noPrint btn"
					name="printButton" onclick="EnablePrint(this)" value="Enable Print">
				</input>
			    <br>
			    <!--<input type="button" class="btn" name="sendToPhrButton" value="Send To MyOscar (PDF)" style="display: none;" onclick="sendToPhr(this)">-->
			    <input type="hidden" name="demographicNo"
				    value="<%=demographic_no%>" />
            </span>
</form>