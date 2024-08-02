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

<%@ page import="java.io.ByteArrayInputStream"%>
<%@ page import="java.net.URLEncoder"%>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page import="java.util.ResourceBundle" %>
<%@ page import="javax.swing.text.rtf.RTFEditorKit"%>
<%@ page import="net.sf.json.JSONArray"%>
<%@ page import="net.sf.json.JSONException"%>
<%@ page import="net.sf.json.JSONObject"%>
<%@ page import="net.sf.json.JSONSerializer"%>
<%@ page import="org.apache.commons.codec.binary.Base64" %>
<%@ page import="org.apache.commons.lang.StringEscapeUtils"%>
<%@ page import="org.apache.commons.lang.StringUtils" %>
<%@ page import="org.apache.commons.lang.builder.ReflectionToStringBuilder"%>
<%@ page import="org.oscarehr.caisi_integrator.ws.CachedDemographicLabResult" %>
<%@ page import="org.oscarehr.casemgmt.model.CaseManagementNote"%>
<%@ page import="org.oscarehr.casemgmt.model.CaseManagementNoteLink"%>
<%@ page import="org.oscarehr.casemgmt.service.CaseManagementManager"%>
<%@ page import="org.oscarehr.common.dao.DemographicDao" %>
<%@ page import="org.oscarehr.common.dao.Hl7TextInfoDao"%>
<%@ page import="org.oscarehr.common.dao.Hl7TextMessageDao"%>
<%@ page import="org.oscarehr.common.dao.MeasurementMapDao" %>
<%@ page import="org.oscarehr.common.dao.PatientLabRoutingDao"%>
<%@ page import="org.oscarehr.common.dao.UserPropertyDAO"%>
<%@ page import="org.oscarehr.common.model.Demographic" %>
<%@ page import="org.oscarehr.common.model.Hl7TextInfo"%>
<%@ page import="org.oscarehr.common.model.Hl7TextMessage"%>
<%@ page import="org.oscarehr.common.model.MeasurementMap"%>
<%@ page import="org.oscarehr.common.model.PatientLabRouting"%>
<%@ page import="org.oscarehr.common.model.Tickler" %>
<%@ page import="org.oscarehr.common.model.UserProperty" %>
<%@ page import="org.oscarehr.managers.TicklerManager" %>
<%@ page import="org.oscarehr.myoscar.utils.MyOscarLoggedInInfo"%>
<%@ page import="org.oscarehr.phr.util.MyOscarUtils"%>
<%@ page import="org.oscarehr.util.LoggedInInfo"%>
<%@ page import="org.oscarehr.util.MiscUtils"%>
<%@ page import="org.oscarehr.util.SpringUtils"%>
<%@ page import="org.owasp.encoder.Encode" %>
<%@ page import="org.w3c.dom.Document"%>
<%@ page import="oscar.OscarProperties" %>
<%@ page import="oscar.oscarDB.*" %>
<%@ page import="oscar.oscarLab.FileUploadCheck" %>
<%@ page import="oscar.oscarLab.LabRequestReportLink" %>
<%@ page import="oscar.oscarLab.ca.all.*" %>
<%@ page import="oscar.oscarLab.ca.all.parsers.*" %>
<%@ page import="oscar.oscarLab.ca.all.util.*" %>
<%@ page import="oscar.oscarLab.ca.all.web.LabDisplayHelper" %>
<%@ page import="oscar.oscarMDS.data.ReportStatus,oscar.log.*" %>
<%@ page import="oscar.util.ConversionUtils"%>
<%@ page import="oscar.util.UtilDateUtilities" %>
<jsp:useBean id="oscarVariables" class="java.util.Properties" scope="session" />

<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean" %>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html" %>
<%@ taglib uri="/WEB-INF/struts-logic.tld" prefix="logic" %>
<%@ taglib uri="/WEB-INF/oscar-tag.tld" prefix="oscar" %>
<%@ taglib uri="/WEB-INF/oscarProperties-tag.tld" prefix="oscarProperties"%>
<%@ taglib uri="/WEB-INF/indivo-tag.tld" prefix="indivo"%>
<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
      String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");
	  boolean authed=true;
%>
<security:oscarSec roleName="<%=roleName$%>" objectName="_lab" rights="r" reverse="<%=true%>">
	<%authed=false; %>
	<%response.sendRedirect("../../../securityError.jsp?type=_lab");%>
</security:oscarSec>
<%
if(!authed) {
	return;
}
%>

<%
LoggedInInfo loggedInInfo=LoggedInInfo.getLoggedInInfoFromSession(request);
oscar.OscarProperties props = oscar.OscarProperties.getInstance();
boolean rememberComment = (!props.hasProperty("REMEMBER_LAST_LAB_COMMENT") || props.isPropertyActive("REMEMBER_LAST_LAB_COMMENT"));
ResourceBundle oscarRec = ResourceBundle.getBundle("oscarResources", request.getLocale());
String segmentID = request.getParameter("segmentID");
String providerNo =request.getParameter("providerNo");
String curUser_no = (String) session.getAttribute("user");
String searchProviderNo = StringUtils.trimToEmpty(request.getParameter("searchProviderNo"));
String patientMatched = request.getParameter("patientMatched");
String remoteFacilityIdString = request.getParameter("remoteFacilityId");
String remoteLabKey = request.getParameter("remoteLabKey");
String demographicID = request.getParameter("demographicId");
String showAllstr = request.getParameter("all");


List<String> allLicenseNames = new ArrayList<String>();
String lastLicenseNo = null, currentLicenseNo = null;

if(providerNo == null) {
	providerNo = loggedInInfo.getLoggedInProviderNo();
}


UserPropertyDAO userPropertyDAO = (UserPropertyDAO)SpringUtils.getBean("UserPropertyDAO");
UserProperty uProp = userPropertyDAO.getProp(providerNo, UserProperty.LAB_ACK_COMMENT);
boolean skipComment = false;
if( uProp != null && uProp.getValue().equalsIgnoreCase("yes")) {
	skipComment = true;
}

UserProperty  getRecallDelegate = userPropertyDAO.getProp(providerNo, UserProperty.LAB_RECALL_DELEGATE);
UserProperty  getRecallTicklerAssignee = userPropertyDAO.getProp(providerNo, UserProperty.LAB_RECALL_TICKLER_ASSIGNEE);
UserProperty  getRecallTicklerPriority = userPropertyDAO.getProp(providerNo, UserProperty.LAB_RECALL_TICKLER_PRIORITY);
boolean recall = false;
String recallDelegate = "";
String ticklerAssignee = "";
String recallTicklerPriority = "";

if(getRecallDelegate!=null){
recall = true;
recallDelegate = getRecallDelegate.getValue();
recallTicklerPriority = getRecallTicklerPriority.getValue();
if(getRecallTicklerAssignee.getValue().equals("yes")){
	ticklerAssignee = "&taskTo="+recallDelegate;
}
}

//reset session attributes
session.setAttribute("labLastName","");
session.setAttribute("labFirstName","");
session.setAttribute("labDOB","");
session.setAttribute("labHIN","");
session.setAttribute("labHphone","");
session.setAttribute("labWphone","");
session.setAttribute("labSex","");

//Need date lab was received by OSCAR
Hl7TextMessageDao hl7TxtMsgDao = (Hl7TextMessageDao)SpringUtils.getBean("hl7TextMessageDao");
MeasurementMapDao measurementMapDao = (MeasurementMapDao) SpringUtils.getBean("measurementMapDao");
Hl7TextMessage hl7TextMessage = hl7TxtMsgDao.find(Integer.parseInt(segmentID));

String dateLabReceived = "n/a";
if(hl7TextMessage != null){
	java.util.Date date = hl7TextMessage.getCreated();
	String stringFormat = "yyyy-MM-dd HH:mm";
    dateLabReceived = UtilDateUtilities.DateToString(date, stringFormat);
}

boolean isLinkedToDemographic=false;
ArrayList<ReportStatus> ackList=null;
String multiLabId = null;
MessageHandler handler=null;
String hl7 = null;
String reqID = null, reqTableID = null;
String remoteFacilityIdQueryString="";

boolean bShortcutForm = OscarProperties.getInstance().getProperty("appt_formview", "").equalsIgnoreCase("on") ? true : false;
String formName = bShortcutForm ? OscarProperties.getInstance().getProperty("appt_formview_name") : "";
String formNameShort = formName.length() > 3 ? (formName.substring(0,2)+".") : formName;
String formName2 = bShortcutForm ? OscarProperties.getInstance().getProperty("appt_formview_name2", "") : "";
String formName2Short = formName2.length() > 3 ? (formName2.substring(0,2)+".") : formName2;
boolean bShortcutForm2 = bShortcutForm && !formName2.equals("");
List<MessageHandler>handlers = new ArrayList<MessageHandler>();
String []segmentIDs = null;
Boolean showAll = showAllstr != null && !"null".equalsIgnoreCase(showAllstr);

if (remoteFacilityIdString==null) // local lab
{

	HashMap<String,Object> reqMap =  LabRequestReportLink.getLinkByReport("hl7TextMessage",Long.valueOf(segmentID));
	if(reqMap.get("id") != null) {
		reqID = reqMap.get("id").toString();
		reqTableID = reqMap.get("request_id").toString();
	} else {
		reqID = "";
		reqTableID = "";
	}


	PatientLabRoutingDao dao = SpringUtils.getBean(PatientLabRoutingDao.class);
	for(PatientLabRouting r : dao.findByLabNoAndLabType(ConversionUtils.fromIntString(segmentID), "HL7")) {
		demographicID = "" + r.getDemographicNo();
	}

	if(demographicID != null && !demographicID.equals("")&& !demographicID.equals("0")){
	    isLinkedToDemographic=true;
	    LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_HL7_LAB, segmentID, request.getRemoteAddr(),demographicID);
	}else{
	    LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_HL7_LAB, segmentID, request.getRemoteAddr());
	}


	if( showAll ) {
		multiLabId = request.getParameter("multiID");
		segmentIDs = multiLabId.split(",");
		for( int i = 0; i < segmentIDs.length; ++i) {
		    handlers.add(Factory.getHandler(segmentIDs[i]));
		}

		handler = handlers.get(0);
	}
	else {
		multiLabId = Hl7textResultsData.getMatchingLabs(segmentID);
		segmentIDs = multiLabId.split(",");

		List<String> segmentIdList = new ArrayList<String>();
		handler = Factory.getHandler(segmentID);
		handlers.add(handler);
		segmentIdList.add(segmentID);

		//this is where it gets weird. We want to show all messages with different filler order num but same accession in a single report
		segmentIDs = segmentIdList.toArray(new String[segmentIdList.size()]);

		hl7 = Factory.getHL7Body(segmentID);
		if (handler instanceof OLISHL7Handler) {
			%>
			<jsp:forward page="labDisplayOLIS.jsp" />
			<%
		}
	}

}
else // remote lab
{
	CachedDemographicLabResult remoteLabResult=LabDisplayHelper.getRemoteLab(loggedInInfo, Integer.parseInt(remoteFacilityIdString), remoteLabKey,Integer.parseInt(demographicID));
	MiscUtils.getLogger().debug("retrieved remoteLab:"+ReflectionToStringBuilder.toString(remoteLabResult));
	isLinkedToDemographic=true;

	LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_HL7_LAB, "segmentId="+segmentID+", remoteFacilityId="+remoteFacilityIdString+", remoteDemographicId="+demographicID);

	Document cachedDemographicLabResultXmlData=LabDisplayHelper.getXmlDocument(remoteLabResult);
	ackList=LabDisplayHelper.getReportStatus(cachedDemographicLabResultXmlData);
	multiLabId=LabDisplayHelper.getMultiLabId(cachedDemographicLabResultXmlData);
	handler=LabDisplayHelper.getMessageHandler(cachedDemographicLabResultXmlData);
	handlers.add(handler);
	segmentIDs = new String[] {"0"};  //fake segment ID for the for loop below to execute
	hl7=LabDisplayHelper.getHl7Body(cachedDemographicLabResultXmlData);

	try {
		remoteFacilityIdQueryString="&remoteFacilityId="+remoteFacilityIdString+"&remoteLabKey="+URLEncoder.encode(remoteLabKey, "UTF-8");
	} catch (Exception e) {
		MiscUtils.getLogger().error("Error", e);
	}
}

/********************** Converted to this spot *****************************/
DemographicDao demographicDao = SpringUtils.getBean(DemographicDao.class);
Demographic demographic = demographicDao.getDemographic(demographicID);

// check for errors printing
if (request.getAttribute("printError") != null && (Boolean) request.getAttribute("printError")){
%>
<script language="JavaScript">
    alert("The lab could not be printed due to an error. Please see the server logs for more detail.");
</script>
<%}


	String annotation_display = org.oscarehr.casemgmt.model.CaseManagementNoteLink.DISP_LABTEST;
	CaseManagementManager caseManagementManager = (CaseManagementManager) SpringUtils.getBean("caseManagementManager");

%>
<!DOCTYPE html>

<html>
    <head>
        <html:base/>
        <title><%=handler.getLastName()+", "+handler.getFirstName()+" Lab Results"%></title>
        <script src="<%=request.getContextPath() %>/share/javascript/Oscar.js" ></script>
        <script src="<%=request.getContextPath() %>/js/global.js"></script>
        <script src="<%=request.getContextPath() %>/library/jquery/jquery-3.6.4.min.js"></script>
        <script>jQuery.noConflict();</script>

	<oscar:customInterface section="labView"/>

	<script>
        // alternately refer to this function in oscarMDSindex.js as labDisplayAjax.jsp does
		function updateLabDemoStatus(labno){
            if(document.getElementById("DemoTable"+labno)){
                document.getElementById("DemoTable"+labno).style.backgroundColor="#FFF";
            }
            //top.opener.location.reload();
            if(window.top.opener.document.getElementById("labdoc_"+labno)){
                window.top.opener.document.getElementById("labdoc_"+labno).classList.remove("UnassignedRes");
            }
        }
	</script>
    <style type="text/css">
.RollRes     { font-weight: 700; font-size: 8pt; color: white; font-family:
               Verdana, Arial, Helvetica }
.RollRes a:link { color: white }
.RollRes a:hover { color: white }
.RollRes a:visited { color: white }
.RollRes a:active { color: white }
.AbnormalRollRes { font-weight: 700; font-size: 8pt; color: red; font-family:
               Verdana, Arial, Helvetica }
.AbnormalRollRes a:link { color: red }
.AbnormalRollRes a:hover { color: red }
.AbnormalRollRes a:visited { color: red }
.AbnormalRollRes a:active { color: red }
.CorrectedRollRes { font-weight: 700; font-size: 8pt; color: yellow; font-family:
               Verdana, Arial, Helvetica }
.CorrectedRollRes a:link { color: yellow }
.CorrectedRollRes a:hover { color: yellow }
.CorrectedRollRes a:visited { color: yellow }
.CorrectedRollRes a:active { color: yellow }
.AbnormalRes { font-weight: bold; font-size: 8pt; color: red; font-family:
               Verdana, Arial, Helvetica }
.AbnormalRes a:link { color: red }
.AbnormalRes a:hover { color: red }
.AbnormalRes a:visited { color: red }
.AbnormalRes a:active { color: red }
.NormalRes   { font-weight: bold; font-size: 8pt; color: black; font-family:
                      Verdana, Arial, Helvetica }
.TDISRes	{font-weight: bold; font-size: 10pt; color: black; font-family:
               Verdana, Arial, Helvetica}
.NormalRes a:link { color: black }
.NormalRes a:hover { color: black }
.NormalRes a:visited { color: black }
.NormalRes a:active { color: black }
.HiLoRes     { font-weight: bold; font-size: 8pt; color: blue; font-family:
               Verdana, Arial, Helvetica }
.HiLoRes a:link { color: blue }
.HiLoRes a:hover { color: blue }
.HiLoRes a:visited { color: blue }
.HiLoRes a:active { color: blue }
.CorrectedRes { font-weight: bold; font-size: 8pt; color: #E000D0; font-family:
               Verdana, Arial, Helvetica }
.CorrectedRes         a:link { color: #6da997 }
.CorrectedRes a:hover { color: #6da997 }
.CorrectedRes a:visited { color: #6da997 }
.CorrectedRes a:active { color: #6da997 }
.Field       { font-weight: bold; font-size: 8.5pt; color: black; font-family:
               Verdana, Arial, Helvetica }
.NarrativeRes { font-weight: 700; font-size: 10pt; color: black; font-family:
               Courier New, Courier, mono }
div.Field a:link { color: black }
div.Field a:hover { color: black }
div.Field a:visited { color: black }
div.Field a:active { color: black }
.Field2      { font-weight: bold; font-size: 8pt; color: #ffffff; font-family:
               Verdana, Arial, Helvetica }
div.Field2   { font-weight: bold; font-size: 8pt; color: #ffffff; font-family:
               Verdana, Arial, Helvetica }
div.FieldDatas { font-weight: normal; font-size: 8pt; color: black; font-family:
               Verdana, Arial, Helvetica }
div.Field3   { font-weight: normal; font-size: 8pt; color: black; font-style: italic;
               font-family: Verdana, Arial, Helvetica }
div.Title    { font-weight: 800; font-size: 10pt; color: white; font-family:
               Verdana, Arial, Helvetica; padding-top: 4pt; padding-bottom:
               2pt }
div.Title a:link { color: white }
div.Title a:hover { color: white }
div.Title a:visited { color: white }
div.Title a:active { color: white }
div.Title2   { font-weight: bolder; font-size: 9pt; color: black; text-indent: 5pt;
               font-family: Verdana, Arial, Helvetica; padding: 10pt 15pt 2pt 2pt}
div.Title2 a:link { color: black }
div.Title2 a:hover { color: black }
div.Title2 a:visited { color: black }
div.Title2 a:active { color: black }
.Cell        { background-color: #9999CC; border-left: thin solid #CCCCFF;
               border-right: thin solid #6666CC;
               border-top: thin solid #CCCCFF;
               border-bottom: thin solid #6666CC }
.Cell2       { background-color: #376c95; border-left-style: none; border-left-width: medium;
               border-right-style: none; border-right-width: medium;
               border-top: thin none #bfcbe3; border-bottom-style: none;
               border-bottom-width: medium }
.Cell3       { background-color: #add9c7; border-left: thin solid #dbfdeb;
               border-right: thin solid #5d9987;
               border-top: thin solid #dbfdeb;
               border-bottom: thin solid #5d9987 }
.CellHdr     { background-color: #cbe5d7; border-right-style: none; border-right-width:
               medium; border-bottom-style: none; border-bottom-width: medium }
.Nav         { font-weight: bold; font-size: 8pt; color: black; font-family:
               Verdana, Arial, Helvetica }
.PageLink a:link { font-size: 8pt; color: white }
.PageLink a:hover { color: red }
.PageLink a:visited { font-size: 9pt; color: yellow }
.PageLink a:active { font-size: 12pt; color: yellow }
.PageLink    { font-family: Verdana }
.text1       { font-size: 8pt; color: black; font-family: Verdana, Arial, Helvetica }
div.txt1     { font-size: 8pt; color: black; font-family: Verdana, Arial }
div.txt2     { font-weight: bolder; font-size: 6pt; color: black; font-family: Verdana, Arial }
div.Title3   { font-weight: bolder; font-size: 12pt; color: black; font-family:
               Verdana, Arial }
.red         { color: red }
.text2       { font-size: 7pt; color: black; font-family: Verdana, Arial }
.white       { color: white }
.title1      { font-size: 9pt; color: black; font-family: Verdana, Arial }
div.Title4   { font-weight: 600; font-size: 8pt; color: white; font-family:
               Verdana, Arial, Helvetica }
pre {
	display: block;
    font-family:  Verdana, Arial, Helvetica;
    white-space: -moz-pre-space;
    margin:0px;
    font-size: x-small;
    font-weight:600;
}

[id^=ticklerWrap]{position:relative;top:0px;background-color:#FF6600;width:100%;}

input[id^='acklabel_']{
    margin-top: 10px; /* align with bootstrap buttons */
}


.completedTickler{
    opacity: 0.8;
    filter: alpha(opacity=80); /* For IE8 and earlier */
}

@media print {
.DoNotPrint{display:none;}
}
    </style>

    <script>
    var labNo = '<%=segmentID%>';
    var providerNo = '<%=providerNo%>';
    var demographicNo = '<%=isLinkedToDemographic ? demographicID : ""%>';

    function popupStart(vheight,vwidth,varpage,windowname) {
            var page = varpage;
            windowprops = "height="+vheight+",width="+vwidth+",location=no,scrollbars=yes,menubars=no,toolbars=no,resizable=yes";
            var popup=window.open(varpage, windowname, windowprops);
    }

    function getComment(action, segmentId) {
       		var ret = true;
            var commentVal = jQuery('input[name="comment"]').val();
            var version = jQuery("#version_"+segmentId).val();
            var selector = "_" + providerNo + "_" + segmentId + "commentText";  // 0_101_866551commentText
            <% if (rememberComment) { %>
            if (version > 0 && jQuery("#"+(version -1)+selector).text().trim().length > 0){
	            commentVal = jQuery("#"+(version -1)+selector).text().trim();
            }
            <% } %>
            if( jQuery("#"+version+selector).text().trim().length > 0 ) {
	            commentVal = jQuery("#"+version+selector).text().trim();
            }
            if( commentVal == null ) {
	            commentVal = "";
	        }

            if ( action == "msgLabRecall") {
                if (commentVal == "" ) {
                    commentVal = "Recall";
                    document.forms['acknowledgeForm_'+ segmentId].comment.value = commentVal;
                    addComment('acknowledgeForm_'+segmentId,segmentId);
                }
                handleLab('acknowledgeForm_'+segmentId,segmentId,action);
                return;
            } else {
                var commentVal = prompt('<bean:message key="oscarMDS.segmentDisplay.msgComment"/>', commentVal);
            }

            if( commentVal == null ) {
            	ret = false;
            } else {
                if( commentVal.length > 0 ){
                    document.forms['acknowledgeForm_'+ segmentId].comment.value = commentVal;
                }
            }

           if(ret) handleLab('acknowledgeForm_'+segmentId,segmentId, action);

            return false;
    }

    function printPDF(labid){
        	var frm = "acknowledgeForm_" + labid;
        	document.forms[frm].action="PrintPDF.do";
        	document.forms[frm].submit();
    }

	function linkreq(rptId, reqId) {
	    var link = "../../LinkReq.jsp?table=hl7TextMessage&rptid="+rptId+"&reqid="+reqId + "<%=demographicID != null ? "&demographicNo=" + demographicID : ""%>";
	    window.open(link, "linkwin", "width=500, height=200");
	}

    function sendToPHR(labId, demographicNo) {
        	<%
        		MyOscarLoggedInInfo myOscarLoggedInInfo=MyOscarLoggedInInfo.getLoggedInInfo(session);

        		if (myOscarLoggedInInfo==null || !myOscarLoggedInInfo.isLoggedIn())
        		{
        			%>
    					alert('Please Login to MyOscar before performing this action.');
        			<%
        		}
        		else
        		{
        			%>
	                    popup(450, 600, "<%=request.getContextPath()%>/phr/SendToPhrPreview.jsp?labId=" + labId + "&demographic_no=" + demographicNo, "sendtophr");
        			<%
        		}
        	%>
    }

    function matchMe() {
            <% if ( !isLinkedToDemographic) {

                    session.setAttribute("labLastName",handler.getLastName());
					session.setAttribute("labFirstName",handler.getFirstName());
                    session.setAttribute("labDOB",handler.getDOB());
					session.setAttribute("labHIN",handler.getHealthNum);
                    session.setAttribute("labHINver",handler.getHealthNumVersion();
                    session.setAttribute("labHphone",handler.getHomePhone());
					session.setAttribute("labWphone",handler.getWorkPhone());
                    session.setAttribute("labSex",handler.getSex());

            %>
               	popupStart(360, 680, '../../../oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow');
            <% } %>
	}

    function next() {

        if(!window.opener || (typeof window.opener.openNext != 'function')){
            document.getElementById('next').style.display="none";
            console.log("not called from inbox so disabling Next");

        } else if (!window.opener.document.getElementById('ack_next_chk').checked) {
            document.getElementById('next').style.display="none";
            console.log("check box currently unchecked so disabling Next");
            }

    }

    function handleLab(formid, labid, action) {
        var url = '<%=request.getContextPath()%>/dms/inboxManage.do';
        var data = 'method=isLabLinkedToDemographic&labid=' + labid;
        jQuery.ajax({
            type: "POST",
            url: url,
            data: data,
            dataType: 'json',
            success: function(data) {
                var json = data;
                if (json != null) {
                    var success = json.isLinkedToDemographic;
                    var demoid = '';
                    if (success) {
                        if (action == 'ackLab') {
                            if (confirmAck()) {
                                jQuery("#labStatus_" + labid).val("A");
                                updateStatus(formid, labid);
                            }
                        } else if (action == 'msgLab') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0)
                                window.popup(700, 960, '<%=request.getContextPath()%>/oscarMessenger/SendDemoMessage.do?demographic_no=' + demoid, 'msg');
                        } else if (action == 'msgLabRecall') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0)
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarMessenger/SendDemoMessage.do?demographic_no=' + demoid + "&recall", 'msgRecall');
                            window.popup(450, 600, '<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId=' + labid + '&demographic_no=' + demoid + '<%=ticklerAssignee%>&priority=<%=recallTicklerPriority%>&recall', 'ticklerRecall');
                        } else if (action == 'ticklerLab') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0)
                                window.popup(450, 600, '<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId=' + labid + '&demographic_no=' + demoid, 'tickler')
                        } else if (action == 'addComment') {
                            addComment(formid, labid);
                        } else if (action == 'unlinkDemo') {
                            unlinkDemographic(labid);
                        } else if (action == 'msgLabMAM') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=MAM', 'prevention');
                                <%
                                if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) {
                                    %>
                                    window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q131A', 'billing');
                                <%
                                } %>
                                //window.popup(450,600,'<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId='+labid+'&demographic_no='+demoid+'<%=ticklerAssignee%>&priority=&recall','ticklerRecall');
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'msgLabPAP') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=PAP', 'prevention');
                                <%
                                if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) {
                                    %>
                                    window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q011A', 'billing');
                                <%
                                } %>
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'msgLabFIT') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=FOBT', 'prevention');
                                //window.popup(450,600,'<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId='+labid+'&demographic_no='+demoid+'<%=ticklerAssignee%>&priority=&recall','ticklerRecall');
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'msgLabCOLONOSCOPY') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=COLONOSCOPY', 'prevention');
                                <%
                                if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) {
                                    %>
                                    window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q142A', 'billing');
                                <%
                                } %>
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'msgLabBMD') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=BMD', 'prevention');
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'msgLabPSA') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=PSA', 'prevention');
                                window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            }
                        } else if (action == 'fileLab') {
                            demoid = json.demoId;
                            if (demoid != null && demoid.length > 0) {
                                fileDoc(labid);
                            }
                        }

                    } else { // not successfully linked to a demographic
                        if (action == 'ackLab') {
                            if (confirmAckUnmatched()) {
                                jQuery("#labStatus_" + labid).val("A");
                                updateStatus(formid, labid);
                            } else {
                                matchMe();
                            }

                        } else if (action == 'fileLab') {
                            if (confirmFileUnmatched()) {
                                fileDoc(labid);
                            } else {
                                matchMe();
                            }
                        } else {
                            alert("<bean:message key="oscarMDS.index.msgNotAttached"/>");
                            matchMe();
                        }
                    } //json.isLinkedToDemographic
                } // json is not null
            } //success function
        }); //ajax request
    } //end handlelab fcn


    function confirmAck(){
		<% if (props.getProperty("confirmAck", "").equals("yes")) { %>
            		return confirm('<bean:message key="oscarMDS.index.msgConfirmAcknowledge"/>');
            	<% } else { %>
            		return true;
            	<% } %>
	}

    function confirmCommentUnmatched(){
        return confirm('<bean:message key="oscarMDS.index.msgConfirmAcknowledgeUnmatched"/>');
    }

    function confirmAckUnmatched(){
        return confirm('<bean:message key="oscarMDS.index.msgConfirmAcknowledgeUnmatched"/>');
    }

    function confirmFileUnmatched(){
        return confirm('This lab has not been matched to a patient. Are you sure you want to File it? OK to File and Cancel to match to a patient');
    }

    function fileDoc(labid){
        jQuery.ajax({
            type: "POST",
            url: "<%= request.getContextPath() %>/oscarMDS/FileLabs.do",
            data: "method=fileLabAjax&flaggedLabId=" + labid + "&labType=HL7",
            success: function (data) {
                if( window.opener.document.getElementById('labdoc_'+labid) != null ) {
                    window.opener.hideLab('labdoc_'+labid);
                    window.opener.refreshCategoryList();
                    window.opener.updateCountTotal(0);
                    jQuery(':button').prop('disabled',true);
                    jQuery('#loader').show();
                    close = window.opener.openNext(labid);
            	} else {
                	window.close();
                }
            },
		    error: function(jqXHR, err, exception) {
            	console.log(jqXHR.status);
		    }
        });
    }



    function updateStatus(formid,labid){
            var url='<%=request.getContextPath()%>'+"/oscarMDS/UpdateStatus.do";
            var data=jQuery('#'+formid).serialize();
            jQuery.ajax({
                type: "POST",
                url: url,
                data: data,
                success: function(result) {

            	if( <%=showAll%> ) {
                	window.location.reload();
                }
            	else if( window.opener.document.getElementById('labdoc_'+labid) != null ) {
                    // opened from the Inbox
                	//window.opener.Effect.BlindUp('labdoc_'+labid); // invoke script.aculo.us to hide the entry
                    window.opener.hideLab('labdoc_'+labid);
                    window.opener.refreshCategoryList();
                    window.opener.updateCountTotal(0);
                    jQuery(':button').prop('disabled',true);
                    jQuery('#loader').show();
                    close = window.opener.openNext(labid);

            	}
                else {
                	window.close();
                }
            }});
    }

    function unlinkDemographic(labNo){
            var reason = "Incorrect demographic";
            reason = prompt('<bean:message key="oscarMDS.segmentDisplay.msgUnlink"/>', reason);
            //must include reason
            if( reason == null || reason.length == 0) {
            	return false;
            }

            var all = '<%=request.getParameter("all") != null ? request.getParameter("all") : ""%>';
        	if("true" == all) {
        		var multiID = '<%=request.getParameter("multiID") != null ? request.getParameter("multiID") : ""%>';
        		for(var x=0;x<multiID.split(",").length;x++) {
        			console.log('unlinking '  +multiID.split(",")[x] );
        			var urlStr='<%=request.getContextPath()%>'+"/lab/CA/ALL/UnlinkDemographic.do";
                    var dataStr="reason="+reason+"&labNo="+multiID.split(",")[x];
                    jQuery.ajax({
            			type: "POST",
            			url:  urlStr,
            			data: dataStr,
            			success: function (data) {
                            // refresh the opening page with new results
                            top.opener.location.reload();
                            // refresh the lab display page and offer dialog to rematch.
					        window.location.reload();
            			}
                    });
        		}
        	} else {
                console.log("unlinking " +labNo);
        		var urlStr='<%=request.getContextPath()%>'+"/lab/CA/ALL/UnlinkDemographic.do";
                var dataStr="reason="+reason+"&labNo="+labNo;
                jQuery.ajax({
        			type: "POST",
        			url:  urlStr,
        			data: dataStr,
        			success: function (data) {
                        // refresh the opening page with new results
                        //top.opener.location.reload();
                        if(window.top.opener.document.getElementById("labdoc_"+labNo)){
                            window.top.opener.document.getElementById("labdoc_"+labNo).classList.add("UnassignedRes");
                        }
                        // refresh the lab display page and offer dialog to rematch.
					    window.location.reload();
        			}
                });
        	}
    }

    function addComment(formid,labid) {
        	var url='<%=request.getContextPath()%>'+"/oscarMDS/UpdateStatus.do?method=addComment";
			if( jQuery("#labStatus_"+labid).val() == "" ) {
				jQuery("#labStatus_"+labid).val("N");
			}

        	var data=jQuery("#"+formid).serialize();
            jQuery.post(url, data, function( data) { window.location.reload();});

        }

        window.ForwardSelectedRows = function() {
    		var query = jQuery(document.reassignForm).formSerialize();
    		jQuery.ajax({
    			type: "POST",
    			url:  "<%=request.getContextPath()%>/oscarMDS/ReportReassign.do",
    			data: query,
    			success: function (data) {
    				self.close();
    			}
    		});
    }

    function submitLabel(lblval, segmentID){
       		document.forms['TDISLabelForm_'+segmentID].label.value = document.forms['acknowledgeForm_'+segmentID].label.value;
    }
    </script>
<link href="<%=request.getContextPath() %>/css/bootstrap.css" rel="stylesheet" type="text/css">

<!-- important leave this last to override the css above and match that in Index.jsp -->
<style>
    form {
        margin: 0px;
    }

    body {
        line-height: 12px;
    }

    pre {
        padding:2px;
        line-height: 12px;
    }

    hr  {
        border: 1px solid black;
        margin:1px;
    }

    .Cell {
        background-color:silver;
        border: black;
    }

    .Field2 {

    }
    .UnassignedRes {
        background-color: #FFCC00;
    }

    .MainTableTopRowRightColumn {
        background-color: silver;

    }

</style>
<style>
/* Dropdown Button */
.dropbtns {
/*  background-color: #4CAF50;
  color: white;
  padding: 16px;
  font-size: 16px;
  border: none;*/
}

/* The container <div> - needed to position the dropdown content */
.dropdowns {
  position: relative;
  display: inline-block;
}

/* Dropdown Content (Hidden by Default) */
.dropdowns-content {
  display: none;
  position: absolute;
  background-color: #f1f1f1;
  min-width: 160px;
  box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
  z-index: 1;
}

/* Links inside the dropdown */
.dropdowns-content a {
  color: black;
  padding: 8px 12px;
  text-decoration: none;
  display: block;
}

.dropdowns-content a.disabled {
  pointer-events: none;
  color: grey;
  padding: 8px 12px;
  text-decoration: none;
  display: block;
}

/* Change color of dropdown links on hover */
.dropdowns-content a:hover {background-color: #ddd;}

/* Show the dropdown menu on hover */
.dropdowns:hover .dropdowns-content {display: block;}

/* Change the background color of the dropdown button when the dropdown content is shown */
.dropdowns:hover .dropbtns {background-color: #e6e6e6;}

</style>
    <body onLoad="matchMe();next();">
<div id='loader' style="display:none"><img src='<%=request.getContextPath()%>/images/DMSLoader.gif'> <bean:message key="caseload.msgLoading"/></div>
        <!-- form forwarding of the lab -->
        <%
        	for( int idx = 0; idx < segmentIDs.length; ++idx ) {

        		if (remoteFacilityIdString==null) {
        			ackList = AcknowledgementData.getAcknowledgements(segmentID);
        			segmentID = segmentIDs[idx];
                	handler = handlers.get(idx);
        		}

        		boolean notBeenAcked = ackList.size() == 0;
        		boolean ackFlag = false;
        		String labStatus = "";
        		String providerComment = "";
        		if (ackList != null){
        		    for (int i=0; i < ackList.size(); i++){
        		        ReportStatus reportStatus = ackList.get(i);
        		        if (reportStatus.getOscarProviderNo() != null && reportStatus.getOscarProviderNo().equals(providerNo) ) {
        		        	labStatus = reportStatus.getStatus();
                            providerComment = reportStatus.getComment() != null ? reportStatus.getComment() : "";
        		        	if( labStatus.equals("A") ){
        		            	ackFlag = true;//lab has been ack by this provider.
        		            	break;
        		        	}
        		        }
        		    }
        		}

        		Hl7TextInfoDao hl7TextInfoDao = (Hl7TextInfoDao) SpringUtils.getBean("hl7TextInfoDao");
        		int lab_no = Integer.parseInt(segmentID);
        		Hl7TextInfo hl7Lab = hl7TextInfoDao.findLabId(lab_no);
        		String label = "";
        		if (hl7Lab != null && hl7Lab.getLabel()!=null) label = hl7Lab.getLabel();

        		String ackLabFunc;
        		if( skipComment ) {
        			ackLabFunc = "handleLab('acknowledgeForm_" + segmentID + "','" + segmentID + "','ackLab');";
        		}
        		else {
        			ackLabFunc = "getComment('ackLab', " + segmentID + ");";
        		}

        %>
        <script>

            jQuery(function() {
          	  jQuery("#createLabel_<%=segmentID%>").on( "click", function() {
          	    jQuery.ajax( {
          	      type: "POST",
          	      url: '<%=request.getContextPath()%>'+"/lab/CA/ALL/createLabelTDIS.do",
          	      dataType: "json",
          	      data: { lab_no: jQuery("#labNum_<%=segmentID%>").val(), accessionNum: jQuery("#accNum").val(), label: jQuery("#label_<%=segmentID%>").val(), ajaxcall: true }
          	    })
                  jQuery("#labelspan_<%=segmentID%> i").html("Label: " +  jQuery("#label_<%=segmentID%>").val());
                  document.forms['acknowledgeForm_<%=segmentID%>'].label.value = "";
          	});
          });

        </script>


		<script>
			//first check to see if lab is linked, if it is, we can send the demographicNo to the macro
			function runMacro(name,formid, closeOnSuccess) {
                var url = '<%=request.getContextPath()%>/dms/inboxManage.do';
                var data = 'method=isLabLinkedToDemographic&labid=<%= segmentID %>';
                jQuery.ajax( {
      	                type: "POST",
      	                url: url,
      	                dataType: "json",
                        data: data,
                        success: function(result) {
                            if(result!=null){
                                var success=result.isLinkedToDemographic;
                                var demoid='';
                                if (success) {
                                    demoid=result.demoId;
                                    runMacroInternal(name,formid,closeOnSuccess,demoid);
            	                 }
                            }
	                    }});


			}

			function runMacroInternal(name,formid,closeOnSuccess,demographicNo) {
				var url='<%=request.getContextPath()%>'+"/oscarMDS/RunMacro.do?name=" + name + (demographicNo.length>0 ? "&demographicNo=" + demographicNo : "");
	            var data=jQuery('#'+formid).serialize();
                var num=formid.split("_");
	            var labid=num[1];

                jQuery.ajax( {
      	                type: "POST",
      	                url: url,
      	                dataType: "json",
                        data: data,
                        success: function(result) {
	                    	if(closeOnSuccess) {
                                if(window.opener && (typeof window.opener.refreshCategoryList == 'function')) {
                        	        //window.opener.Effect.BlindUp('labdoc_'+labid);
                                    window.opener.hideLab('labdoc_'+labid);
                                    window.opener.refreshCategoryList();
                                    window.opener.updateCountTotal(0);
                                    jQuery('#loader').show();
                                    jQuery(':button').prop('disabled',true);
                                    close = window.opener.openNext(labid);
                                } else {
                                    if(parent.popup) parent.popup.close();
                                }
	                    	}
	                    }});

			}
		</script>

		<div id="lab_<%=segmentID%>">
        <form name="reassignForm_<%=segmentID%>" method="post" action="Forward.do">
            <input type="hidden" name="flaggedLabs" value="<%=segmentID%>" >
            <input type="hidden" name="selectedProviders" value="" >
            <input type="hidden" name="favorites" value="" >
            <input type="hidden" name="labType" value="HL7" >
            <input type="hidden" name="labType<%= segmentID %>HL7" value="imNotNull" >
            <input type="hidden" id="providerNo_<%=segmentID %>" name="providerNo" value="<%= providerNo %>" >
        </form>

        <form name="TDISLabelForm_<%=segmentID%>"  method='POST' action="../../../lab/CA/ALL/createLabelTDIS.do">
					<input type="hidden" id="labNum_<%=segmentID %>" name="lab_no" value="<%=lab_no%>">
					<input type="hidden" id="label_<%=segmentID %>" name="label" value="<%=label%>">
		</form>

        <form name="acknowledgeForm_<%=segmentID%>" id="acknowledgeForm_<%=segmentID%>" method="post" onsubmit="javascript:void(0);"  action="javascript:void(0);" >

            <table style="width:100%; height:100%; border:0px; border-spacing: 0px;" >
                <tr>
                    <td style="vertical-align: top;">
                        <table style="width:100%; border:0px; border-spacing: 0px;">
                            <tr>
                                <td style="text-align: left; width:100%;" class="MainTableTopRowRightColumn">
                                    <input type="hidden" name="segmentID" value="<%= segmentID %>">
                                    <input type="hidden" name="multiID" value="<%= multiLabId %>" >
                                    <input type="hidden" name="providerNo" id="providerNo" value="<%= providerNo %>">
                                    <input type="hidden" name="status" value="<%=labStatus%>" id="labStatus_<%=segmentID%>">
                                    <input type="hidden" name="comment" value="<%=Encode.forHtmlAttribute(providerComment)%>">
                                    <input type="hidden" name="labType" value="HL7">
                                    <%
                                    if ( !ackFlag ) {
                                    %>
									<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {
									%>
											  <div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key="global.macro"/><span class="caret" ></span></button>
											  <div class="dropdowns-content">


											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runMacro('<%=name%>','acknowledgeForm_<%=segmentID%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									        <% } %>
                                    <input type="button" class="btn btn-primary" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>" onclick="<%=ackLabFunc%>" >

                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" onclick="return getComment('addComment',<%=segmentID%>);">

                                    <% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(355, 675, '<%=request.getContextPath()%>/oscarMDS/SelectProvider.jsp?docId=<%=segmentID%>&labDisplay=true', 'providerselect')">
                                    <input type="button" class="btn" value="<bean:message key="global.btnClose"/>" onClick="window.close()">

                                     <input type="button" class="btn" value="<bean:message key="caseload.msgMsg"/>" onclick="handleLab('','<%=segmentID%>','msgLab');">

                                     <input type="button" class="btn" value="<bean:message key="global.tickler"/>"  onclick="handleLab('','<%=segmentID%>','ticklerLab');">
                            <% if(recall){%>
                                     <input type="button" class="btn" value="<bean:message key="oscarMDS.index.Recall"/>" onclick="getComment('msgLabRecall','<%=segmentID%>');">
                            <%}%>
                            <div class="dropdowns" >
                                <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret" ></span></button>
                                <div class="dropdowns-content">
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabFIT'); return false;">FIT</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabBMD'); return false;">BMD</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabPSA'); return false;">PSA</a>
                            <a href="javascript:;" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onClick="popupStart(700, 1280, '<%= request.getContextPath() %>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow');return false;"><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onClick="popupStart(700,1000,'<%= request.getContextPath() %>/demographic/demographiccontrol.jsp?demographic_no=<%=demographicID%>&displaymode=edit','MDR<%=demographicID%>');return false;"><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="popupStart(500,1024,'<%= request.getContextPath() %>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=<%=demographicID%>','Rx<%=demographicID%>');return false;"><bean:message key="global.prescriptions"/></a>
                                <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="popupStart(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing');return false;"><bean:message key="global.billingtag"/></a>
                                <% } %>
                            <a href="javascript:;" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% } %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="unlinkDemographic(<%=segmentID%>);//handleLab('','<%=segmentID%>','unlinkDemo');"><bean:message key="oscarMDS.segmentDisplay.btnUnlinkDemo"/></a>
                                    <a href="javascript:;" onclick="linkreq('<%=segmentID%>','<%=reqID%>');" >Req# <%=reqTableID%></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','fileLab'); return false;"><bean:message key="global.File"/></a>
                                </div>
                            </div>


                                   	<% if (bShortcutForm) { %>
									<input type="button" <%=isLinkedToDemographic ? "" : "disabled" %> class="btn" value="<%=formNameShort%>" onClick="popupStart(700, 1024, '<%=request.getContextPath()%>/form/forwardshortcutname.jsp?formname=<%=formName%>&demographic_no=<%=demographicID%>', '<%=formNameShort%>')" />
									<% } %>
									<% if (bShortcutForm2) { %>
									<input type="button" <%=isLinkedToDemographic ? "" : "disabled" %> class="btn" value="<%=formName2Short%>" onClick="popupStart(700, 1024, '<%=request.getContextPath()%>/form/forwardshortcutname.jsp?formname=<%=formName2%>&demographic_no=<%=demographicID%>', '<%=formName2Short%>')" />
									<% } %>
                                    <input type="button" class="btn"  value="<bean:message key="global.btnPDF"/>" onClick="printPDF('<%=segmentID%>')">
									<%
										if(remoteLabKey == null || "".equals(remoteLabKey.length())) {
									%>

                                    <% if (!label.equals(null) && !label.equals("")) { %>
										<input type="button" class="btn" id="createLabel_<%=segmentID%>" value="<bean:message key="global.Label"/>" onclick="submitLabel(this, '<%=segmentID%>');">
										<%} else { %>
										<input type="button" class="btn" id="createLabel_<%=segmentID%>" value="<bean:message key="global.Label"/>" onclick="submitLabel(this, '<%=segmentID%>');">
										<%} %>
										<input type="hidden"  name="lab_no" value="<%=lab_no%>"> <!-- id="labNum_<%=segmentID %>"-->
						                <input type="text" name="label" value="" class="input-small"> <!-- id="acklabel_<%=segmentID %>"-->

						                 <% String labelval="";
						                 if (label!="" && label!=null) {
						                 	labelval = label;
						                 }else {
						                	 labelval = oscarRec.getString("oscarMDS.index.notset");

						                 } %>
					                 <span id="labelspan_<%=segmentID%>" class="Field2"><i><bean:message key="global.Label"/>: <%=labelval %> </i></span><br>

									<% } %>
                                    <span class="Field2" onclick="javascript:popupStart('600','800','<%=request.getContextPath()%>/demographic/demographiccontrol.jsp?demographic_no=<%=demographicID%>&last_name=<%=java.net.URLEncoder.encode(handler.getFirstName())%>&first_name=<%=java.net.URLEncoder.encode(handler.getLastName())%>&orderby=appttime&displaymode=appt_history&dboperation=appt_history&limit1=0&limit2=25')" style="cursor:pointer;"><i><bean:message key="global.nextAppt"/>: <oscar:nextAppt demographicNo="<%=demographicID%>"/></i></span>
                                </td>
                            </tr>
                        </table>
                        <table style="width:100%; border:1px solid;  background-color:#9999CC;">
                            <%
                            if (multiLabId != null){
                                String[] multiID = multiLabId.split(",");
                                if (multiID.length > 1){
                                    %>
                                    <tr>
                                        <td class="Cell" colspan="2" style="padding: 3px; text-align:center">
                                            <div class="Field2">
                                                <bean:message key="global.Version"/>:&#160;&#160;
                                                <%
                                                for (int i=0; i < multiID.length; i++){
                                                    if (multiID[i].equals(segmentID)){
                                                        %>v<%= i+1 %>&#160;<%
                                                    }else{
                                                        if ( searchProviderNo != null ) { // null if we were called from e-chart
                                                            %><a href="labDisplay.jsp?segmentID=<%=multiID[i]%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&searchProviderNo=<%= searchProviderNo %>">v<%= i+1 %></a>&#160;<%
                                                        }else{
                                                            %><a href="labDisplay.jsp?segmentID=<%=multiID[i]%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>">v<%= i+1 %></a>&#160;<%
                                                        }
                                                    }
                                                }
                                                if( multiID.length > 1 ) {
                                                    if ( searchProviderNo != null ) { // null if we were called from e-chart
                                                        %><a href="labDisplay.jsp?segmentID=<%=segmentID%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&searchProviderNo=<%= searchProviderNo %>&all=true"><bean:message key="global.All"/></a>&#160;<%
                                                    }else{
                                                        %><a href="labDisplay.jsp?segmentID=<%=segmentID%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&all=true">All</a>&#160;<%
                                                    }
                                                }
                                                %>
                                            </div>
                                        </td>
                                    </tr>
                                    <%
                                }
                            }
                            %>
                            <tr>
                                <td class="Cell" style="width:66%; text-align:center;">
                                    <div class="Field2">
                                        <bean:message key="oscarMDS.segmentDisplay.formDetailResults"/>
                                    </div>
                                </td>
                                <td style="width:33%; text-align:center;" class="Cell">
                                    <div class="Field2">
                                        <bean:message key="oscarMDS.segmentDisplay.formResultsInfo"/>
                                    </div>
                                </td>
                            </tr>
                            <tr style="border:1px solid;">
                                <td style="background-color:white; vertical-align:top; border:1px solid;">
                                    <table style="vertical-align:top; border-width:0px; border-spacing:0px; width:100%;">
                                        <tr style="vertical-align:top;">
                                            <td style="padding:0px; vertical-align:top; width:33%; text-align:left">
                                                <table style="vertical-align:top; border-width:0px; border-spacing:0px; width:100%;  <% if ( !isLinkedToDemographic){ %> background-color:orange; <% } %>" id="DemoTable<%=segmentID%>" >                                                    <tr>
                                                        <td style="vertical-align:top; text-align:left">
                                                            <table style="vertical-align:top; width:100%; text-align:left">
                                                                <tr>
                                                                    <td style="white-space:nowrap; width:25%;">
                                                                        <div class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formPatientName"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap; width:25%;">
                                                                        <div class="FieldDatas" style="white-space:nowrap;">
                                                                            <% if ( searchProviderNo == null ) { // we were called from e-chart%>
                                                                            <a href="javascript:window.close()">
                                                                            <% } else { // we were called from lab module%>
                                                                            <a href="javascript:popupStart(360, 680, '<%=request.getContextPath()%>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow')">
                                                                                <% } %>
                                                                                <%=handler.getLastName()+", "+handler.getFirstName()%>
                                                                            </a>
                                                                        </div>
                                                                    </td>

                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formDateBirth"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas" style="white-space:nowrap;">
                                                                            <%=handler.getDOB()%>
                                                                        </div>
                                                                    </td>

                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formAge"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas">
                                                                            <%=handler.getAge()%>
                                                                        &nbsp;
                                                                            <bean:message key="oscarMDS.segmentDisplay.formSex"/>:
                                                                        &nbsp;
                                                                            <%=handler.getSex()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas">
                                                                            <strong>
                                                                                <bean:message key="oscarMDS.segmentDisplay.formHealthNumber"/>
                                                                            </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldDatas" style="white-space:nowrap;">
                                                                            <%=handler.getHealthNum()%>
                                                                        </div>
                                                                    </td>

                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">

                                                                    </td>
                                                                    <td style="white-space:nowrap;">

                                                                    </td>

                                                                </tr>
                                                            </table>
                                                        </td>
                                                        <td style="width:50%; vertical-align:top;">
                                                            <table style="width:100%; vertical-align:top; border-width:0px; border-spacing:0px;">
                                                                <tr>
                                                                    <td style="white-space:nowrap; ">
                                                                        <div style="text-align: left" class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formHomePhone"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left; white-space:nowrap;" class="FieldDatas" >
                                                                            <%=handler.getHomePhone()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formWorkPhone"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="white-space:nowrap; text-align:left" class="FieldDatas" >
                                                                            <%=handler.getWorkPhone()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldDatas">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formEmail"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left; white-space:nowrap;" class="FieldDatas">
                                                						<% if(demographicID != null && !demographicID.equals("") && !demographicID.equals("0")){
                                                    						if (demographic.getConsentToUseEmailForCare() != null && demographic.getConsentToUseEmailForCare()){ %>
                                                                            <a href="mailto:<%=Encode.forHtml(demographic.getEmail())%>?subject=Message%20from%20your%20Doctors%20Office" target="_blank" rel="noopener noreferrer" ><%=demographic.getEmail()%></a>
                                                                        <% } else { %>
                                                                            <span id="email"><%=Encode.forHtml(demographic.getEmail())%></span>
                                                                        <% } } %>
                                                                        </div>
                                                                    </td>
                                                                </tr>

                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldDatas">
                                                                         <% if ("ExcellerisON".equals(handler.getMsgType())) { %>
                                                                         	<strong>Reported by:</strong>
                                                                         <% } else { %>
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formPatientLocation"/>: </strong>
                                                                         <% } %>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left; white-space:nowrap;" class="FieldDatas">
                                                                            <%=handler.getPatientLocation()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                            </table>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                                <td style="background-color:white; vertical-align:top">
                                    <table style="width:100%;" >
                                        <tr>
                                            <td>
                                                <div class="FieldDatas">
                                                <% if ("CLS".equals(handler.getMsgType())) { %>
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formDateServiceCLS"/>:</strong>
												<% } else { %>
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formDateService"/>:</strong>
												<% } %>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= handler.getServiceDate() %>
                                                </div>
                                            </td>
                                        </tr>
                                        <% if ("ExcellerisON".equals(handler.getMsgType())) { %>
                                            <tr>
                                                <td>
                                                    <div class="FieldDatas">
                                                        <strong>Reported on:</strong>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div class="FieldDatas" style="white-space:nowrap;">
                                                        <%= ((ExcellerisOntarioHandler) handler).getReportStatusChangeDate(0) %>
                                                    </div>
                                                </td>
                                            </tr>
                                        <% } %>
                                         <tr>
                                             <td >
                                                <div class="FieldDatas">
                                               <strong>Date of Request:</strong>

                                                </div>
                                            </td>
                                             <td >
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= handler.getRequestDate(0) %>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                        	 <td >
                                        		<div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formDateReceivedCLS"/>:</strong>

                                                </div>
                                            </td>
                                             <td >
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= dateLabReceived %>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                             <td style="padding:1px;">
                                                <div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formReportStatus"/>:</strong>
                                                </div>
                                            </td>
                                             <td>
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= ( handler.getOrderStatus().equals("F") ? "Final" : handler.getOrderStatus().equals("C") ? "Corrected" : (handler.getMsgType().equals("PATHL7") && handler.getOrderStatus().equals("P")) ? "Preliminary": handler.getOrderStatus().equals("X") ? "DELETED": handler.getOrderStatus()) %>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="white-space:nowrap;">
                                                <div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formClientRefer"/>:</strong>
                                                </div>
                                            </td>
                                            <td style="white-space:nowrap;">
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= handler.getClientRef()%>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formAccession"/>:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= handler.getAccessionNum()%>
                                                </div>
                                            </td>
                                        </tr>
                                        <% if (handler.getMsgType().equals("ExcellerisON") && !((ExcellerisOntarioHandler)handler).getAlternativePatientIdentifier().isEmpty()) {  %>
                                          <tr>
                                            <td>
                                                <div class="FieldDatas">
                                                    <strong>Reference #:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                    <%= ((ExcellerisOntarioHandler)handler).getAlternativePatientIdentifier()%>
                                                </div>
                                            </td>
                                        </tr>
                                        <% } %>
                                        <% if (handler.getMsgType().equals("MEDVUE")) {  %>
                                        <tr>
                                        	<td>
                                                <div class="FieldDatas">
                                                    <strong>MEDVUE Encounter Id:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                   <%= handler.getEncounterId() %>
                                                </div>
                                            </td>
                                        </tr>
                                        <% }
                                        String comment = handler.getNteForPID();
                                        if (comment != null && !comment.equals("")) {%>
                                        <tr>
                                        	<td style="padding:1px;">
                                                <div class="FieldDatas">
                                                    <strong>Remarks:</strong>
                                                </div>
                                            </td>
                                            <td style="padding:1px;">
                                                <div class="FieldDatas" style="white-space:nowrap;">
                                                   <%= Encode.forHtmlContent(comment) %>
                                                </div>
                                            </td>
                                        </tr>
                                        <%} %>
                                    </table>
                                </td>
                            </tr>
                            <tr>
                                <td style="background-color:white; " colspan="2">
                                    <table style="width:100%; border-width:0px; border-color:#CCCCCC">
                                        <tr style="border-bottom: 1px solid;">
                                            <td style="background-color:white">
                                                <div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formRequestingClient"/>: </strong>
                                                    <%= handler.getDocName()%>
                                                </div>
                                            </td>

                                            <td style="background-color:white; text-align:right">
                                                <div class="FieldDatas">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formCCClient"/>: </strong>
                                                    <%= handler.getCCDocs()%>

                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2" style="padding:0px;  background-color:white; text-align:center" >
<%
String[] multiID = multiLabId.split(",");
boolean isTickler = false;
for(int mcount=0; mcount<multiID.length; mcount++){
	if(demographicID!=null && !demographicID.equals("")){
							    TicklerManager ticklerManager = SpringUtils.getBean(TicklerManager.class);
							    List<Tickler> LabTicklers = null;
							    if(demographicID != null) {
							    	LabTicklers = ticklerManager.getTicklerByLabIdAnyProvider(loggedInInfo, Integer.valueOf(multiID[mcount]), Integer.valueOf(demographicID));
							    }

							    if(LabTicklers!=null && LabTicklers.size()>0){
                                    if(!isTickler){
%>
                            <div id="ticklerWrap" class="DoNotPrint">
							    <h4 style="color:#fff"><a href="javascript:void(0)" id="open-ticklers" onclick="showHideItem('ticklerDisplay')">View Ticklers</a> Linked to this Lab</h4>
                                <div id="ticklerDisplay" style="display:none">
<%

                                        isTickler = true;
                                    }

							   String flag;
							   String ticklerClass;
							   String ticklerStatus;
							   for(Tickler tickler:LabTicklers){

							   ticklerStatus = tickler.getStatus().toString();
							   if(!ticklerStatus.equals("C") && tickler.getPriority().toString().equals("High")){
							   	flag="<span style='color:red'>&#9873;</span>";
							   }else if(ticklerStatus.equals("C") && tickler.getPriority().toString().equals("High")){
							   	flag="<span>&#9873;</span>";
							   }else{
							   	flag="";
							   }

							   if(ticklerStatus.equals("C")){
							  	 ticklerClass = "completedTickler";
							   }else{
							  	 ticklerClass="";
							   }
							   %>
							       <div style="text-align:left; background-color:#fff; padding:5px; width:600px; margin-left:auto; margin-right:auto" class="<%=ticklerClass%>">
							       	<table style="width:100%">
							       	<tr>
							       	<td><b>Priority:</b><br><%=flag%> <%=tickler.getPriority()%></td>
							       	<td><b>Service Date:</b><br><%=tickler.getServiceDate()%></td>
							       	<td><b>Assigned To:</b><br><%=tickler.getAssignee() != null ? Encode.forHtml(tickler.getAssignee().getLastName() + ", " + tickler.getAssignee().getFirstName()) : "N/A"%></td>
							       	<td style="width:90px"><b>Status:</b><br><%=ticklerStatus.equals("C") ? "Completed" : "Active" %></td>
							       	</tr>
							       	<tr>
							       	<td colspan="4"><%=Encode.forHtml(tickler.getMessage())%></td>
							       	</tr>
							       	</table>
							       </div>
							       <br>
							   <%
							   }
							   %>
							   		<!-- end ticklers for this v-->

							   <%}//no ticklers to display OR

	}

}
    if(isTickler){
    %>
                                </div><!-- end ticklerDisplay-->
                            </div><!-- end ticklerWrap-->
    <%
    }


                                    ReportStatus report;
                                    boolean startFlag = false;
                                    for (int j=multiID.length-1; j >=0; j--){
                                        ackList = AcknowledgementData.getAcknowledgements(multiID[j]);
                                        if (multiID[j].equals(segmentID))
                                            startFlag = true;
                                        if (startFlag) {
                                            //if (ackList.size() > 0){{%>
                                                <table style="width:100%; height:20px">
                                                    <tr>
                                                        <% if (multiID.length > 1){ %>
                                                            <td style="text-align:center; background-color:white; width:20%; vertical-align:top">
                                                                <div class="FieldDatas">
                                                                    <b><bean:message key="global.Version"/>:</b> v<%= j+1 %><input hidden id="version_<%=multiID[j]%>" value="<%=j%>">
                                                                </div>
                                                            </td>
                                                            <td style="text-align: left; background-color:white; width:80%; vertical-align:top">
                                                        <% }else{ %>
                                                            <td style="text-align:center; background-color:white;">
                                                        <% } %>
                                                            <div class="FieldDatas">
                                                                <!--center-->
                                                                    <% for (int i=0; i < ackList.size(); i++) {
                                                                        report = ackList.get(i); %>
                                                                        <%= Encode.forHtml(report.getProviderName()) %> :

                                                                        <% String ackStatus = report.getStatus();
                                                                            if(ackStatus.equals("A")){
                                                                                ackStatus = oscarRec.containsKey("oscarMDS.index.Acknowledged")? oscarRec.getString("oscarMDS.index.Acknowledged") : "Acknowledged";
                                                                            }else if(ackStatus.equals("F")){
                                                                                ackStatus = oscarRec.containsKey("oscarMDS.index.Acknowledged")? oscarRec.getString("oscarMDS.index.FiledbutnotAcknowledged") : "Filed but not Acknowledged";
                                                                            }else{
                                                                                ackStatus = oscarRec.containsKey("oscarMDS.index.Acknowledged")? oscarRec.getString("oscarMDS.index.NotAcknowledged") : "Not Acknowledged";
                                                                            }
                                                                            String nocom = oscarRec.containsKey("oscarMDS.index.nocomment")? oscarRec.getString("oscarMDS.index.nocomment") : "no comment";
                                                                            String com = oscarRec.containsKey("oscarMDS.index.comment")? oscarRec.getString("oscarMDS.index.comment") : "comment";
                                                                        %>
                                                                        <span style="color:red"><%= ackStatus %></span>
                                                                        <% if ( report.getStatus().equals("A") ) { %>
                                                                            <%= report.getTimestamp() %>,
                                                                        <% } %>
                                                                        <span id="<%=j + "_" + report.getOscarProviderNo() + "_" + segmentID%>commentLabel"><%=report.getComment() == null || report.getComment().equals("") ? nocom : com +": "%></span>
                                                                        <span id="<%=j + "_" + report.getOscarProviderNo() + "_" + segmentID%>commentText"><%=report.getComment()==null ? "" : Encode.forHtmlContent(report.getComment())%></span>
                                                                        <br>
                                                                    <% }
                                                                    if (ackList.size() == 0){
                                                                        %><span style='color:red'>N/A</span><%
                                                                    }
                                                                    %>
                                                                <!--/center-->
                                                            </div>
                                                        </td>
                                                    </tr>
                                                </table>

                                            <%//}
                                        }
                                    }%>

                                </td>
                            </tr>
                        </table>

                        <% int i=0;
                        int j=0;
                        int k=0;
                        int l=0;
                        int linenum=0;
                        String highlight = "#E0E0FF";

                        ArrayList<String> headers = handler.getHeaders();
                        int OBRCount = handler.getOBRCount();

                        if (handler.getMsgType().equals("MEDVUE")) { %>
<%-- MEDVUE Redirect. --%>
                        <table style="page-break-inside:avoid; border:0px; width:100%" >
                           <tr>
                               <td colspan="4" style="height:14px">&nbsp;</td>
                           </tr>
                           <tr>
                               <td style="background-color#FFCC00; width:300px; vertical-align:bottom">
                                   <div class="Title2">
                                      <%=headers.get(0)%>
                                   </div>
                               </td>
                               <td style="width:9px;">&nbsp;</td>
                               <td style="width:9px;">&nbsp;</td>
                               <td >&nbsp;</td>
                           </tr>
                       </table>
                       <table style="page-break-inside:avoid; border:0px; width:100%" id="tblDiscs1">
                           <tr class="Field2">
                               <td style="width:25%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
                               <td style="width:5%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formAbn"/></td>
                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formReferenceRange"/></td>
                               <td style="width:10%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formUnits"/></td>
                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
                               <td style="width:6%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formNew"/></td>
                               <td style="width:6%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formAnnotate"/></td>
                           </tr>
	                        <tr class="TDISRes">
		                      	<td style="vertical-align:top; text-align:left" colspan="8" ><pre  style="margin:0px 0px 0px 100px;"><b>Radiologist: </b><b><%=handler.getRadiologistInfo()%></b></pre>
		                      	</td>
	                     	 </tr>
	                        <tr class="TDISRes">
		                       	<td style="vertical-align:top; text-align:left" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><b><%=handler.getOBXComment(1, 1, 1)%></b></pre>
		                       	</td>
		                       	<td style="vertical-align:top; text-align:center">
                                    <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(1) + "-" + String.valueOf(1) %>','anwin','width=400,height=500');">
                                    	<img src="<%=request.getContextPath()%>/images/notes.gif" alt="rxAnnotation" height="16" width="13" >
                                    </a>
                                </td>
	                      	 </tr>
                     	 </table>
 <%-- ALL OTHERS Redirect. --%>
                     <% } else {

                      for(i=0;i<headers.size();i++){
                           linenum=0;
						boolean isUnstructuredDoc = false;
						boolean	isVIHARtf = false;
						boolean isSGorCDC = false;

							//Checks to see if the PATHL7 lab is an unstructured document, a VIHA RTF pathology report, or if the patient location is SG/CDC
							//labs that fall into any of these categories have certain requirements per Excelleris
							if(handler.getMsgType().equals("PATHL7")){
								isUnstructuredDoc = ((PATHL7Handler) handler).unstructuredDocCheck(headers.get(i));
								isVIHARtf = ((PATHL7Handler) handler).vihaRtfCheck(headers.get(i));
								if(handler.getPatientLocation().equals("SG") || handler.getPatientLocation().equals("CDC")){
									isSGorCDC = true;
								}

							} else if(handler.getMsgType().equals("CLS")){
	                            isUnstructuredDoc = ((CLSHandler) handler).isUnstructured();
	                        }


							if( handler.getMsgType().equals("MEDITECH") ) {
								isUnstructuredDoc = ((MEDITECHHandler) handler).isUnstructured();
							} %>
<% if (i>0) { %>
                        </table>
<% } %>
                    <tr><!-- the following yellow header table is nested so provide a row for it -->
                        <td>

		                   <table style="page-break-inside:avoid; width:100%; border:0px"><!-- segment no <%=i%> -->
                               <tr>
                                    <td colspan="4" style="height:14px">&nbsp;</td>
                               </tr>
	                           <tr>
	                               <td style="vertical-align:bottom; background-color:#FFCC00; width:300px;">
	                                   <div class="Title2">
	                                       <%=headers.get(i)%>
	                                   </div>
	                               </td>
                                   <td style="width:9px;">&nbsp;</td>
                                   <td style="width:9px;">&nbsp;</td>
                                   <td >&nbsp;</td>
	                           </tr>
	                       </table>

                        </td>
                    </tr>

                    <tr><!-- nest for results table tblDisc -->
                        <td>
	                   <% if ( ( handler.getMsgType().equals("MEDITECH") && isUnstructuredDoc) ||
	                		   ( handler.getMsgType().equals("MEDITECH") && ((MEDITECHHandler) handler).isReportData() ) ) { %>
	                       	<table style="width:100%;border-collapse:collapse;"><!-- id="tblDiscs2" -->
	                       	<tr><td colspan="4" style="padding-left:10px;">

                       	<%} else if( isUnstructuredDoc){%>
	                       <table style="width:100%; border:0px;"> <!-- id="tblDiscs3" -->

	                           <tr class="Field2">

	                               <td style="width:20%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
	                               <td style="width:60%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
								   <% if ("CLS".equals(handler.getMsgType())) { %>
									   <td style="width:20%; vertical-align:bottom; text-align:center" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompletedCLS"/></td>
								   <% } else { %>
									   <td style="width:20%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
								   <% } %>

	                               <td style="width:31%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
	                               <td style="width:31%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
	                               <td style="width:31%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>

	                           </tr><%
						} else {%>
                       <table style="width:100%; border:0px;"><!-- id="tblDiscs4"-->

                           <% if( handler instanceof MEDITECHHandler && "MIC".equals( ((MEDITECHHandler) handler).getSendingApplication() ) ) { %>
	                          		<tr>
			                   			<td colspan="8" ></td>
		                   			</tr>
		                   			<tr>
			                   			<td style="padding-left:20px;font-weight:bold; text-align:left; vertical-align:top" >SPECIMEN SOURCE: </td>
			                   			<td style="font-weight:bold; text-align:left; vertical-align:top" colspan="7"><%= ((MEDITECHHandler) handler).getSpecimenSource(i) %></td>
		                   			</tr>
		                   			<tr>
			                   			<td style="padding-left:20px;font-weight:bold; text-align:left; vertical-align:top">SPECIMEN DESCRIPTION: </td>
			                   			<td style="font-weight:bold; text-align:left; vertical-align:top" colspan="7"><%= ((MEDITECHHandler) handler).getSpecimenDescription(i) %></td>
		                   			</tr>
		                   			<tr>
			                   			<td colspan="8" ></td>
		                   			</tr>
		                   		<% }%>

                           <tr class="Field2">
                               <td style="width:25%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
                               <td style="width:5%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formAbn"/></td>
                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formReferenceRange"/></td>
                               <td style="width:10%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formUnits"/></td>
                               <% if ("CLS".equals(handler.getMsgType())) { %>
                                   <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompletedCLS"/></td>
							   <% } else { %>
                                   <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
							   <% } %>
                               <td style="width:6%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formNew"/></td>
                          	   <td style="width:6%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formAnnotate"/></td>
                          	   <% if ("ExcellerisON".equals(handler.getMsgType())) { %>
                          	   	<td style="width:6%; text-align:center; vertical-align:bottom" class="Cell">License #</td>
                          	   </tr>
                          	   <% } %>
                           </tr>

 							<%
						} // end else / if isUnstructured

                           for ( j=0; j < OBRCount; j++){

                        	   String lastObxSetId = "0";
                               boolean obrFlag = false;
                               int obxCount = handler.getOBXCount(j);
                               
                               if (handler.getMsgType().equals("ExcellerisON") && handler.getObservationHeader(j, 0).equals(headers.get(i))) {
                               String orderRequestStatus = ((ExcellerisOntarioHandler) handler).getOrderStatus(j);
                               %>
                                    <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" >
                                        <td style="text-align:left; vertical-align:top"><span style="font-size:16px;font-weight: bold;"><%=handler.getOBRName(j)%></span></td>
                                        <td colspan="1"><%=orderRequestStatus%></td>
                                    </tr>
                               <%
                               }   
                               
                               for (k=0; k < obxCount; k++){

                               	String obxName = handler.getOBXName(j, k);

								boolean isAllowedDuplicate = false;
								if(handler.getMsgType().equals("PATHL7")){
									//if the obxidentifier and result name are any of the following, they must be displayed (they are the Excepetion to Excelleris TX/FT duplicate result name display rules)
									if((handler.getOBXName(j, k).equals("Culture") && handler.getOBXIdentifier(j, k).equals("6463-4")) ||
									(handler.getOBXName(j, k).equals("Organism") && (handler.getOBXIdentifier(j, k).equals("X433") || handler.getOBXIdentifier(j, k).equals("X30011")))){
					   					isAllowedDuplicate = true;
					   				}
								}
                                   boolean b1=false, b2=false, b3=false;

                                   boolean fail = true;
                                   try {
                                   b1 = !handler.getOBXResultStatus(j, k).equals("DNS");
                                 	b2 = !obxName.equals("");
                                   String currheader = headers.get(i);
                                   String obsHeader = handler.getObservationHeader(j,k);
                                   b3 = handler.getObservationHeader(j, k).equals(headers.get(i));
                                   fail = false;
                                 } catch (Exception e){
                                   	//logger.info("ERROR :"+e);
                                   }

                                   if ( handler.getMsgType().equals("MEDITECH") ) {
                                	   b2=true;
                                   } if (handler.getMsgType().equals("EPSILON")) {
                                   	b2=true;
                                   	b3=true; //Because Observation header can never be the same as the header. Observation header = OBX-4.2 and header= OBX-4.1
                                   } else if(handler.getMsgType().equals("PFHT") || handler.getMsgType().equals("CML") || handler.getMsgType().equals("HHSEMR")) {
                                   	b2=true;
                                   }

                                    if (!fail && b1 && b2 && b3){ // <<--  DNS only needed for MDS messages

                                   	String obrName = handler.getOBRName(j);
                                   	b1 = !obrFlag && !obrName.equals("");
                                   	b2 = !(obxName.contains(obrName));
                                   	b3 = !(obxCount < 2 && !isUnstructuredDoc);
                                       if( b1 && b2 && b3 && !handler.getMsgType().equals("ExcellerisON")){
                                       %>
                                           <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" >
                                               <td style="vertical-align:top; text-align:left;"><span style="font-size:16px;font-weight: bold;"><%=obrName%></span></td>
                                               <td colspan="6">&nbsp;</td>
                                           </tr>
                                           <%obrFlag = true;
                                       }

                                       String lineClass = "NormalRes";
                                       String abnormal = handler.getOBXAbnormalFlag(j, k);
                                       if ( abnormal != null && abnormal.startsWith("L")){
                                           lineClass = "HiLoRes";
                                       } else if ( abnormal != null && ( abnormal.equals("A") || abnormal.startsWith("H") || handler.isOBXAbnormal( j, k) ) ){
                                           lineClass = "AbnormalRes";
                                       }

                                       boolean isPrevAnnotation = false;
                                       CaseManagementNoteLink cml = caseManagementManager.getLatestLinkByTableId(CaseManagementNoteLink.LABTEST,Long.valueOf(segmentID),j+"-"+k);
                                       CaseManagementNote p_cmn = null;
                                       if (cml!=null) {p_cmn = caseManagementManager.getNote(cml.getNoteId().toString());}
                                       if (p_cmn!=null){isPrevAnnotation=true;}

                                       String loincCode = null;
                                       try{
                                       	List<MeasurementMap> mmapList =  measurementMapDao.getMapsByIdent(handler.getOBXIdentifier(j, k));
                                       	if (mmapList.size()>0) {
	                                    	MeasurementMap mmap =mmapList.get(0);
	                                       	loincCode = mmap.getLoincCode();
                                       	}
                                       }catch(Exception e){
                                        	MiscUtils.getLogger().error("loincProb",e);
                                       }

                                       if (handler.getMsgType().equals("EPSILON")) {
	                                    	   if (handler.getOBXIdentifier(j,k).equals(headers.get(i)) && !obxName.equals("")) { %>

	                                        	<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">
		                                            <td style="vertical-align:top; text-align:left"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"><%=obxName %></a>
		                                            &nbsp;<%if(loincCode != null){ %>
                                                	<a href="javascript:popupStart('660','1000','http://apps.nlm.nih.gov/medlineplus/services/mpconnect.cfm?mainSearchCriteria.v.cs=2.16.840.1.113883.6.1&mainSearchCriteria.v.c=<%=loincCode%>&informationRecipient.languageCode.c=en')"> info</a>
                                                	<%} %>
                                                	</td>
		                                            <td style="text-align:right">
		                                            	<%= handler.getOBXResult( j, k) %>
		                                            	<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
		                                            </td>

		                                            <td style="text-align:center">
		                                                    <%= handler.getOBXAbnormalFlag(j, k)%>
		                                            </td>
		                                            <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
		                                            <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getOBXResultStatus( j, k) %></td>
		                                            <td style="text-align:center; vertical-align:top">
	                                                <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(j) + "-" + String.valueOf(k) %>','anwin','width=400,height=500');">
	                                                	<%if(!isPrevAnnotation){ %><img src="<%=request.getContextPath()%>/images/notes.gif" alt="rxAnnotation" height="16" width="13" ><%}else{ %><img src="<%=request.getContextPath()%>/images/filledNotes.gif" alt="rxAnnotation" height="16" width="13" > <%} %>
	                                                </a>
                                                </td>
	                                       		</tr>
	                                       <% } else if (handler.getOBXIdentifier(j,k).equals(headers.get(i)) && obxName.equals("")) { %>
	                                       			<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
	                                                    <td style="text-align:left; vertical-align:top" colspan="8">
	                                                    	<pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXResult( j, k)%><%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%></pre>
                                                    	</td>

	                                                </tr>
	                                       	<% }

                                      } else if (handler.getMsgType().equals("PFHT") || handler.getMsgType().equals("HHSEMR") || handler.getMsgType().equals("CML")) {
                                   	   if (!obxName.equals("")) { %>
	                                    		<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">
		                                            <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"><%=obxName %></a>
		                                            &nbsp;
		                                            <%if(loincCode != null){ %>
                                                	<a href="javascript:popupStart('660','1000','http://apps.nlm.nih.gov/medlineplus/services/mpconnect.cfm?mainSearchCriteria.v.cs=2.16.840.1.113883.6.1&mainSearchCriteria.v.c=<%=loincCode%>&informationRecipient.languageCode.c=en')"> info</a>
                                                	<%} %> </td>
		                                            <td style="text-align:right">
		                                            	<%= handler.getOBXResult( j, k) %>
		                                            	<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
	                                            	</td>

		                                            <td style="text-align:center">
		                                                    <%= handler.getOBXAbnormalFlag(j, k)%>
		                                            </td>
		                                            <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
		                                            <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getOBXResultStatus( j, k) %></td>
		                                            <td style="text-align:center; vertical-align:top">
	                                                <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(j) + "-" + String.valueOf(k) %>','anwin','width=400,height=500');">
	                                                	<%if(!isPrevAnnotation){ %><img src="<%=request.getContextPath()%>/images/notes.gif" alt="rxAnnotation" height="16" width="13"><%}else{ %><img src="<%=request.getContextPath()%>/images/filledNotes.gif" alt="rxAnnotation" height="16" width="13" > <%} %>
	                                                </a>
                                                </td>
	                                       		 </tr>

                                   	 	<%} else { %>
                                   		   <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
	      	                                     <td style="text-align:left; vertical-align:top" colspan="8">
	      	                                     	<pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXResult( j, k)%><%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%></pre>
    	                                     	</td>

	      	                                   </tr>
                                   	 	<%}
	                                    	if (!handler.getNteForOBX(j,k).equals("") && handler.getNteForOBX(j,k)!=null) { %>
		                                       <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
		                                       		<td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getNteForOBX(j,k)%></pre></td>
		                                       </tr>
		                                    <% }
			                                for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
			                                     <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
			                                        <td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
			                                     </tr>
			                                <%}

                                   } else if ((!handler.getOBXResultStatus(j, k).equals("TDIS") && handler.getMsgType().equals("Spire")) )  { %>
											<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">
                                           <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"><%=obxName %></a>
                                           &nbsp;<%if(loincCode != null){ %>
                                                	<a href="javascript:popupStart('660','1000','http://apps.nlm.nih.gov/medlineplus/services/mpconnect.cfm?mainSearchCriteria.v.cs=2.16.840.1.113883.6.1&mainSearchCriteria.v.c=<%=loincCode%>&informationRecipient.languageCode.c=en')"> info</a>
                                                	<%} %> </td>
                                           <% 	if (handler.getOBXResult( j, k).length() > 20) {
													%>

													<td style="text-align: left;" colspan="4">
														<%= handler.getOBXResult( j, k) %>
														<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
													</td>

													<% 	String abnormalFlag = handler.getOBXAbnormalFlag(j, k);
														if (abnormalFlag != null && abnormalFlag.length() > 0) {
													 %>
		                                           <td style="text-align:center">
		                                                   <%= abnormalFlag%>
		                                           </td>
		                                           <% } %>

		                                           <% 	String refRange = handler.getOBXReferenceRange(j, k);
														if (refRange != null && refRange.length() > 0) {
													 %>
		                                           <td style="text-align:left"><%=refRange%></td>
		                                           <% } %>

		                                           <% 	String units = handler.getOBXUnits(j, k);
														if (units != null && units.length() > 0) {
													 %>
		                                           <td style="text-align:left"><%=units %></td>
		                                           <% } %>
												<%
												} else {
												%>
												   <td style="text-align:right" colspan="1">
												   		<%= handler.getOBXResult( j, k) %>
												   		<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
												   </td>
		                                           <td style="text-align:center"> <%= handler.getOBXAbnormalFlag(j, k)%> </td>
		                                           <td style="text-align:left"> <%=handler.getOBXReferenceRange(j, k)%> </td>
		                                           <td style="text-align:left"> <%=handler.getOBXUnits(j, k) %> </td>
												<%
												}
												%>

                                           <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
                                           <td style="text-align:center"><%= handler.getOBXResultStatus(j, k) %></td>

                                      		<td style="text-align:center; vertical-align:top">
	                                                <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(j) + "-" + String.valueOf(k) %>','anwin','width=400,height=500');">
	                                                	<%if(!isPrevAnnotation){ %><img src="../../../images/notes.gif" alt="rxAnnotation" height="16" width="13"><%}else{ %><img src="../../../images/filledNotes.gif" alt="rxAnnotation" height="16" width="13"> <%} %>
	                                                </a>
                                                </td>
                                       </tr>

                                       <%for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
                                            <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
                                               <td style="text-align:center; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
                                            </tr>
                                       <%}


                                    } else if ((!handler.getOBXResultStatus(j, k).equals("TDIS") && !handler.getMsgType().equals("EPSILON")) )  {

                                    	if(isUnstructuredDoc){%>
                                   			<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%="NarrativeRes"%>"><%
                                   			if(handler.getOBXIdentifier(j, k).equalsIgnoreCase(handler.getOBXIdentifier(j, k-1)) && (obxCount>1) && ! handler.getMsgType().equals("MEDITECH") ){%>
                                   					<td style="text-align:center; vertical-align:top" ><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','.<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier='<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8")%>')"></a><%
                                   			}else if(! handler.getMsgType().equals("MEDITECH") ) {%>
                                   					<td style="text-align:center; vertical-align:top" ><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"><%=obxName %></a>
                                   			<%}%>
											<%if(isVIHARtf){

											    //create bytes from the rtf string
										    	byte[] rtfBytes = handler.getOBXResult(j, k).getBytes();
										    	ByteArrayInputStream rtfStream = new ByteArrayInputStream(rtfBytes);

										    	//Use RTFEditor Kit to get plaintext from RTF
										    	RTFEditorKit rtfParser = new RTFEditorKit();
										    	javax.swing.text.Document doc = rtfParser.createDefaultDocument();
										    	rtfParser.read(rtfStream, doc, 0);
										    	String rtfText = doc.getText(0, doc.getLength()).replaceAll("\n", "<br>");
										    	String disclaimer = "<br>IMPORTANT DISCLAIMER: You are viewing a PREVIEW of the original report. The rich text formatting contained in the original report may convey critical information that must be considered for clinical decision making. Please refer to the ORIGINAL report, by clicking 'Print', prior to making any decision on diagnosis or treatment.";%>
										    	<td style="text-align:left" ><%= rtfText + disclaimer %></td>
										    <%}else{%>
                                           		<td style="text-align:left">
	                                           		<span><%= handler.getOBXResult( j, k) %><%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%></span>
                                           		</td>
                                           	<%} %>

                                          	<% if(handler.getTimeStamp(j, k).equals(handler.getTimeStamp(j, k-1)) && (obxCount>1)){ %>
                                       			<td style="text-align:center"></td>
                                       		<%} else {%>
                                       			<td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
                                       		<%}

                                       		} else {//if it isn't a PATHL7 doc %>

                               				<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">

                               				<% if(handler.getMsgType().equals("PATHL7") && !isAllowedDuplicate && (obxCount>1) && handler.getOBXIdentifier(j, k).equalsIgnoreCase(handler.getOBXIdentifier(j, k-1)) && (handler.getOBXValueType(j, k).equals("TX") || handler.getOBXValueType(j, k).equals("FT"))){%>
                                   				<td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"></a><%
                                   			} else {


                               					if(handler instanceof AlphaHandler && lastObxSetId.equals(((AlphaHandler)handler).getObxSetId(j, k))) {
								%>
                               							<td></td>
                               					<% } else { %>
			                                           <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= URLEncoder.encode(handler.getOBXIdentifier(j, k).replaceAll("&","%26"),"UTF-8") %>')"><%=obxName %></a>

                                           				<% if(loincCode != null) { %>
                                                			<a href="javascript:popupStart('660','1000','http://apps.nlm.nih.gov/medlineplus/services/mpconnect.cfm?mainSearchCriteria.v.cs=2.16.840.1.113883.6.1&mainSearchCriteria.v.c=<%=loincCode%>&informationRecipient.languageCode.c=en')"> info</a>
                                                		<%} %>

                                                		</td>
                                           		<% }


                               				}%>


                                           <% if(handler instanceof AlphaHandler && "FT".equals(handler.getOBXValueType(j, k))) { %>
                                           		<td colspan="4">
                                           			<pre style="font-family:Courier New, monospace;">       <%= handler.getOBXResult( j, k) %><%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%></pre>
                                          		</td>
                                           <%
                                       			lastObxSetId = ((AlphaHandler)handler).getObxSetId(j,k);

                                           } else if(handler instanceof PATHL7Handler && "FT".equals(handler.getOBXValueType(j, k)) && (handler.getOBXReferenceRange(j,k).isEmpty() && handler.getOBXUnits(j,k).isEmpty())){
                                        	  %> <td colspan="4">
                                        	  		<%= handler.getOBXResult( j, k) %>
                                        	  		<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
                                       	  		</td> <%
                                           } else { %>
                                           <%
                                           	String align = "right";
                                          	//for pathl7, if it is an SG/CDC result greater than 100 characters, left justify it
                                           	if((handler.getOBXResult(j, k) != null && handler.getOBXResult(j, k).length() > 100) && (isSGorCDC)){
                                           		align="left";
                                           	}
                                           	if(handler instanceof PATHL7Handler && "FT".equals(handler.getOBXValueType(j, k))) {
                                           		align="left";
                                           	}
                                           	%>

                                           	<%
                                           		//CLS textual results - use 4 columns.
                                           		if(handler instanceof CLSHandler && ( (oscar.oscarLab.ca.all.parsers.CLSHandler) handler).isUnstructured()) {
                                           	%>
                                           		<td style="text-align: left;" colspan="4">
                                           			<%= handler.getOBXResult( j, k) %>
                                           			<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
                                          		</td>

                                           	<%
                                           		}

                                           		else if(handler.getMsgType().equals("MEDITECH")  && isUnstructuredDoc ) {
                                           	%>

				                                        <pre>
					                             		<%= handler.getOBXResult(j,k) %><%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
					                             		</pre>

											<% } else if(handler.getMsgType().equals("MEDITECH")  && ((MEDITECHHandler) handler).isReportData() ) { %>
				                                    	<tr>
				                                    		<td>
					                             				<%= handler.getOBXResult(j,k) %>
					                             				<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
					                             			</td>
					                             		</tr>

                                           	<%
                                           		}
                                           		// else {
                                           	%>

											<%
												if((handler.getMsgType().equals("ExcellerisON") || handler.getMsgType().equals("PATHL7")) && handler.getOBXValueType(j,k).equals("ED")) {
													String legacy = "";
													if(handler.getMsgType().equals("PATHL7") && ((PATHL7Handler)handler).isLegacy(j,k) ) {
														legacy ="&legacy=true";
													}

												%>
													 <td style="text-align:<%=align%>"><a href="<%=request.getContextPath() %>/lab/DownloadEmbeddedDocumentFromLab.do?labNo=<%=Encode.forHtmlAttribute(segmentID) %>&segment=<%=j%>&group=<%=k%><%=legacy%>">PDF Report</a></td>
													 <%
												} else {
											%>
                                           <td style="text-align:<%=align%>">
                                                <% if (handler.getMsgType().equals("ExcellerisON") && !((ExcellerisOntarioHandler) handler).getOBXSubId(j, k).isEmpty()) { %>
                                                <em><%= ((ExcellerisOntarioHandler) handler).getOBXSubIdWithObservationValue( j, k) %></em>
                                                <% } else { %>
                                           		<%= handler.getOBXResult( j, k) %>
                                                <% } %>
                                           		<%= handler.isTestResultBlocked(j, k) ? "<a href='#' title='Do Not Disclose Without Explicit Patient Consent'>(BLOCKED)</a>" : ""%>
                                           </td>

                                          	<% } %>
                                           <td style="text-align:center">
                                                   <%= handler.getOBXAbnormalFlag(j, k)%>
                                           </td>
                                           <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
                                           <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>

                                           <%}%>

                                           <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
                                           <td style="text-align:center">
                                           	<%
                                           		String status = handler.getOBXResultStatus( j, k);
                                           		if("GDML".equals(handler.getMsgType()) && ((GDMLHandler)handler).isTestResultBlocked(j, k) ) {
                                           			if(!StringUtils.isEmpty(status)) {
                                           				status += "/";
                                           			}
                                           			status += "BLOCKED";
                                           		}
                                           	%>
                                           	<%=status %>

                                           	</td>
                                      		<td style="text-align:center; vertical-align:top">                                           <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(j) + "-" + String.valueOf(k) %>','anwin','width=400,height=500');">
	                                                	<%if(!isPrevAnnotation){ %><img src="../../../images/notes.gif" alt="rxAnnotation" height="16" width="13" ><%}else{ %><img src="../../../images/filledNotes.gif" alt="rxAnnotation" height="16" width="13" > <%} %>
	                                                </a>
                                                </td>

                                            <% if ("ExcellerisON".equals(handler.getMsgType())) {
                                            	lastLicenseNo = currentLicenseNo;
                        						currentLicenseNo = ((ExcellerisOntarioHandler)handler).getLabLicenseNo(j, k);
                        						String licenseName = ((ExcellerisOntarioHandler)handler).getLabLicenseName(j, k);
                        						if(!allLicenseNames.contains(licenseName)) {
                        							allLicenseNames.add(licenseName);
                        						}
                                            %>
                                            	<td><%= !currentLicenseNo.equals(lastLicenseNo)?currentLicenseNo:""%></td>
                                            <% } %>
                                       </tr>

										<%}

                                        for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
                                        <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
                                           <td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
                                        </tr>
                                   		<%}


                                    } else { %>
                                       	<%for (l=0; l < handler.getOBXCommentCount(j, k); l++){
                                       			if (!handler.getOBXComment(j, k, l).equals("")) {
                                       		%>
                                            <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="TDISRes">
                                               <td style="text-align:left; vertical-align:top"  colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
                                            	<td style="text-align:center; vertical-align:top">
	                                                <a href="javascript:void(0);" title="Annotation" onclick="window.open('<%=request.getContextPath()%>/annotation/annotation.jsp?display=<%=annotation_display%>&amp;table_id=<%=segmentID%>&amp;demo=<%=demographicID%>&amp;other_id=<%=String.valueOf(1) + "-" + String.valueOf(1) %>','anwin','width=400,height=500');">
	                                                	<%if(!isPrevAnnotation){ %><img src="../../../images/notes.gif" alt="rxAnnotation" height="16" width="13"><%}else{ %><img src="../../../images/filledNotes.gif" alt="rxAnnotation" height="16" width="13" > <%} %>
	                                                </a>
                                             </td>
                                            </tr>
                                       			<%}
                                       	} // end for loop %>

                                 <%  }

                                  }

                               }


                           if (!handler.getMsgType().equals("PFHT")) {
                               if (headers.get(i).equals(handler.getObservationHeader(j, 0))) {
                               	 %>
                               <%for (k=0; k < handler.getOBRCommentCount(j); k++){
                                   // the obrName should only be set if it has not been
                                   // set already which will only have occured if the
                                   // obx name is "" or if it is the same as the obr name
                                   if(!obrFlag && handler.getOBXName(j, 0).equals("")){  %>
                                       <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" >
                                           <td style="text-align:left; vertical-align:top"><%=handler.getOBRName(j)%> </td>
                                           <td colspan="6">&nbsp;</td>
                                       </tr>
                                       <%obrFlag = true;
                                   }%>
                               <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
                              	 <td style="text-align:left; vertical-align:top" colspan="1"></td>
                                   <td style="text-align:left; vertical-align:top" colspan="7"><pre  style="margin:0px 0px 0px 0px;"><%=handler.getOBRComment(j, k)%></pre></td>
                               </tr>
                               <% if  (!handler.getMsgType().equals("HHSEMR") || !handler.getMsgType().equals("TRUENORTH")) {
                               		if(handler.getOBXName(j,k).equals("")){
	                                        String result = handler.getOBXResult(j, k);%>
	                                         <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" >
	                                                 <td colspan="7" style="text-align:left; vertical-align:top"><%=result%></td>
	                                         </tr>
	                              		<%}
                               	}
                                }//end for k=0


                             }//end if handler.getObservation..
                          } // end for if (PFHT)

                              } //end for j=0; j<obrCount;
                          } // // end for headersfor i=0... (headers) line 625

							if (handler.getMsgType().equals("Spire")) {

								int numZDS = ((SpireHandler)handler).getNumZDSSegments();
								String lineClass = "NormalRes";
								int lineNumber = 0;
								MiscUtils.getLogger().info("HERE: " + numZDS);

								if (numZDS > 0) { %>
									<tr class="Field2">
		                               <td style="width:25%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
		                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
		                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formProvider"/></td>
		                               <td style="width:15%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
		                               <td style="width:6%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formNew"/></td>
		                            </tr>
								<%
								}

								for (int m=0; m < numZDS; m++) {
									%>
									<tr style="background-color:<%=(lineNumber % 2 == 1 ? highlight : "")%>" class="<%=lineClass%>">
										<td style="text-align:left; vertical-align:top"> <%=((SpireHandler)handler).getZDSName(m)%> </td>
										<td style="text-align:right"><%= ((SpireHandler)handler).getZDSResult(m) %></td>
										<td style="text-align:center"><%= ((SpireHandler)handler).getZDSProvider(m) %></td>
										<td style="text-align:center"><%= ((SpireHandler)handler).getZDSTimeStamp(m) %></td>
										<td style="text-align:center"><%= ((SpireHandler)handler).getZDSResultStatus(m) %></td>
									</tr>
									<%
									lineNumber++;
								}
							}

                           %>
                       </table>
                       </td>
                       </tr>
                       <%

                       } // end for handler.getMsgType().equals("MEDVUE")

                       %>
<%-- FOOTER --%>
                    <tr>
                        <td>
                        <table style="width:100%; border:0px; background-color:silver" class="MainTableBottomRowRightColumn" >
                            <tr>
                                <td style="text-align: left; width:100%">
                                                                        <%
                                    if ( !ackFlag ) {
                                    %>
									<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {
									%>
											  <div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key="global.macro"/><span class="caret" ></span></button>
											  <div class="dropdowns-content">


											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runMacro('<%=name%>','acknowledgeForm_<%=segmentID%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									<% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>" onclick="<%=ackLabFunc%>" >

                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" onclick="return getComment('addComment',<%=segmentID%>);">

                                    <% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(355, 675, '../../../oscarMDS/SelectProvider.jsp?docId=<%=segmentID%>&labDisplay=true', 'providerselect')">
                                    <input type="button" class="btn" value="<bean:message key="global.btnClose"/>" onClick="window.close()">

                                     <input type="button" class="btn" value="<bean:message key="caseload.msgMsg"/>" onclick="handleLab('','<%=segmentID%>','msgLab');">

                                     <input type="button" class="btn" value="<bean:message key="global.tickler"/>"  onclick="handleLab('','<%=segmentID%>','ticklerLab');">
                            <% if(recall){%>
                                     <input type="button" class="btn" value="<bean:message key="oscarMDS.index.Recall"/>" onclick="handleLab('','<%=segmentID%>','msgLabRecall');">
                            <%}%>
                            <div class="dropdowns" >
                                <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret" ></span></button>
                                <div class="dropdowns-content">
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabFIT'); return false;">FIT</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabBMD'); return false;">BMD</a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','msgLabPSA'); return false;">PSA</a>
                            <a href="javascript:;" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onClick="popupStart(700, 1280, '<%= request.getContextPath() %>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow');return false;"><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onClick="popupStart(700,1000,'<%= request.getContextPath() %>/demographic/demographiccontrol.jsp?demographic_no=<%=demographicID%>&displaymode=edit','MDR<%=demographicID%>');return false;"><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="popupStart(500,1024,'<%= request.getContextPath() %>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=<%=demographicID%>','Rx<%=demographicID%>');return false;"><bean:message key="global.prescriptions"/></a>
                                <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="popupStart(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing');return false;"><bean:message key="global.billingtag"/></a>
                                <% } %>
                            <a href="javascript:;" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% } %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:;" onclick="handleLab('','<%=segmentID%>','unlinkDemo');"><bean:message key="oscarMDS.segmentDisplay.btnUnlinkDemo"/></a>
                                    <a href="javascript:;" onclick="linkreq('<%=segmentID%>','<%=reqID%>');" >Req# <%=reqTableID%></a>
                                    <a href="javascript:;" onclick="handleLab('','<%=segmentID%>','fileLab'); return false;"><bean:message key="global.File"/></a>
                                </div>
                            </div>
                                   	<% if (bShortcutForm) { %>
									<input type="button" <%=isLinkedToDemographic ? "" : "disabled" %> class="btn" value="<%=formNameShort%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName%>&demographic_no=<%=demographicID%>', '<%=formNameShort%>')" >
									<% } %>
									<% if (bShortcutForm2) { %>
									<input type="button" <%=isLinkedToDemographic ? "" : "disabled" %> class="btn" value="<%=formName2Short%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName2%>&demographic_no=<%=demographicID%>', '<%=formName2Short%>')" >
									<% } %>
									<input type="button" class="btn" value="<bean:message key="global.btnPDF"/>" onClick="printPDF('<%=segmentID%>')">
                                    <input type="button" class="btn" id="next" value="<bean:message key="global.Next"/>" onclick="jQuery(':button').prop('disabled',true); jQuery('#loader').show(); close = window.opener.openNext(<%=segmentID%>);">
                                </td>
                            </tr><tr>
                                <td style="text-align:center">
                                <% if ("CLS".equals(handler.getMsgType())) { %>
									<span class="Field2"><i><bean:message key="oscarMDS.segmentDisplay.msgReportEndCLS"/></i></span>
								<% } else { %>
									<span class="Field2"><i><bean:message key="oscarMDS.segmentDisplay.msgReportEnd"/></i></span>
								<% } %>
                                </td>
                            </tr>
                        </table>
                        </td>
                        </tr>
                        <tr>
                        <td>
                        <table>
                        	<%
                        		for(String lName : allLicenseNames) {
                        	%>
                        	<tr>
                        		<td><%=lName %></td>
                        	</tr>

                        	<% } %>
                        </table>
                    </td>
                </tr>
            </table>

        </form>

        <%String s = ""+System.currentTimeMillis();%>
        <a style="color:white;" href="javascript: void(0);" onclick="showHideItem('rawhl7<%=s%>');" >show</a>
        <pre id="rawhl7<%=s%>" style="display:none;"><%=hl7%></pre>
        </div>
        <%} %>

    </body>
</html>
<%!
    public String[] divideStringAtFirstNewline(String s){
        int i = s.indexOf("<br />");
        String[] ret  = new String[2];
        if(i == -1){
               ret[0] = new String(s);
               ret[1] = null;
            }else{
               ret[0] = s.substring(0,i);
               ret[1] = s.substring(i+6);
            }
        return ret;
    }
%>
 <%--
    AD Address
    CE Coded Entry
    CF Coded Element With Formatted Values
    CK Composite ID With Check Digit
    CN Composite ID And Name
    CP Composite Price
    CX Extended Composite ID With Check Digit
    DT Date
    ED Encapsulated Data
    FT Formatted Text (Display)
    MO Money
    NM Numeric
    PN Person Name
    RP Reference Pointer
    SN Structured Numeric
    ST String Data.
    TM Time
    TN Telephone Number
    TS Time Stamp (Date & Time)
    TX Text Data (Display)
    XAD Extended Address
    XCN Extended Composite Name And Number For Persons
    XON Extended Composite Name And Number For Organizations
    XPN Extended Person Number
    XTN Extended Telecommunications Number
 --%>