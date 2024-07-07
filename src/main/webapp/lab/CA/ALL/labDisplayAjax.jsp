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
<%@ page errorPage="../provider/errorpage.jsp" %>


<%@ page import="oscar.oscarDB.*"%>
<%@ page import="oscar.oscarLab.ca.all.*"%>
<%@ page import="oscar.oscarLab.ca.all.util.*"%>
<%@ page import="oscar.util.ConversionUtils"%>

<%@ page import="oscar.oscarLab.ca.all.parsers.*"%>
<%@ page import="oscar.oscarLab.LabRequestReportLink"%>
<%@ page import="oscar.oscarMDS.data.ReportStatus,oscar.log.*"%>
<%@ page import="oscar.OscarProperties"%>

<%@ page import="org.oscarehr.common.dao.Hl7TextInfoDao"%>
<%@ page import="org.oscarehr.common.model.Hl7TextInfo"%>
<%@ page import="org.oscarehr.common.dao.UserPropertyDAO"%>
<%@ page import="org.oscarehr.common.model.UserProperty"%>
<%@ page import="org.oscarehr.common.model.PatientLabRouting"%>
<%@ page import="org.oscarehr.common.dao.PatientLabRoutingDao"%>
<%@ page import="org.oscarehr.common.model.Tickler" %>
<%@ page import="org.oscarehr.managers.TicklerManager" %>
<%@ page import="org.oscarehr.common.model.Demographic" %>
<%@ page import="org.oscarehr.common.dao.DemographicDao" %>
<%@ page import="org.oscarehr.util.SpringUtils"%>
<%@ page import="org.oscarehr.util.LoggedInInfo"%>
<%@ page import="org.oscarehr.util.MiscUtils"%>

<%@ page import="javax.swing.text.rtf.RTFEditorKit"%>
<%@ page import="java.util.*"%>
<%@ page import="java.sql.*"%>
<%@ page import="java.io.ByteArrayInputStream"%>

<%@ page import="org.apache.commons.codec.binary.Base64"%>
<%@ page import="org.apache.commons.lang.StringUtils" %>
<%@ page import="org.apache.commons.lang.StringEscapeUtils"%>

<%@ page import="net.sf.json.JSONException"%>
<%@ page import="net.sf.json.JSONSerializer"%>
<%@ page import="net.sf.json.JSONObject"%>
<%@ page import="net.sf.json.JSONArray"%>

<%@ page import="org.owasp.encoder.Encode" %>


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
    boolean bShortcutForm = props.getProperty("appt_formview", "").equalsIgnoreCase("on") ? true : false;
    String formName = bShortcutForm ? props.getProperty("appt_formview_name") : "";
    String formNameShort = formName.length() > 3 ? (formName.substring(0,2)+".") : formName;
    String formName2 = bShortcutForm ? props.getProperty("appt_formview_name2", "") : "";
    String formName2Short = formName2.length() > 3 ? (formName2.substring(0,2)+".") : formName2;
    boolean bShortcutForm2 = bShortcutForm && !formName2.equals("");

    UserPropertyDAO userPropertyDao = SpringUtils.getBean(UserPropertyDAO.class);
	String curUser_no = (String) session.getAttribute("user");
	UserProperty tabViewProp = userPropertyDao.getProp(curUser_no, UserProperty.OPEN_IN_TABS);
    boolean openInTabs = false;
    if ( tabViewProp == null ) {
        openInTabs = oscar.OscarProperties.getInstance().getBooleanProperty("open_in_tabs", "true");
    } else {
        openInTabs = oscar.OscarProperties.getInstance().getBooleanProperty("open_in_tabs", "true") || Boolean.parseBoolean(tabViewProp.getValue());
    }

String segmentID = request.getParameter("segmentID");
String providerNo = request.getParameter("providerNo");
String searchProviderNo = request.getParameter("searchProviderNo");
String patientMatched = request.getParameter("patientMatched");

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
String ackLabFunc;
if( skipComment ) {
	ackLabFunc = "handleLab('acknowledgeForm_" + segmentID + "','" + segmentID + "','ackLab');";
} else {
	ackLabFunc = "getComment('ackLab','" + segmentID + "');";
}
%>
<script language="JavaScript">
    console.log("openInTabs is <%=openInTabs%>, skipComment is <%=skipComment%> with an ackLabFunc of:\n<%=ackLabFunc%>");
</script>
<%
Long reqIDL = LabRequestReportLink.getIdByReport("hl7TextMessage",Long.valueOf(segmentID.trim()));
String reqID = reqIDL==null ? "" : reqIDL.toString();
reqIDL = LabRequestReportLink.getRequestTableIdByReport("hl7TextMessage",Long.valueOf(segmentID.trim()));
String reqTableID = reqIDL==null ? "" : reqIDL.toString();

PatientLabRoutingDao dao = SpringUtils.getBean(PatientLabRoutingDao.class);
String demographicID = "";
for(PatientLabRouting r : dao.findByLabNoAndLabType(ConversionUtils.fromIntString(segmentID), "HL7")) {
    demographicID = "" + r.getDemographicNo();
}

boolean isLinkedToDemographic=false;
if(demographicID != null && !demographicID.equals("")&& !demographicID.equals("0")){
    isLinkedToDemographic=true;
    LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_HL7_LAB, segmentID, request.getRemoteAddr(),demographicID);
}else{
    LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_HL7_LAB, segmentID, request.getRemoteAddr());
}

boolean ackFlag = false;
ArrayList ackList = AcknowledgementData.getAcknowledgements(segmentID);
String labStatus = "";
if (ackList != null){
    for (int i=0; i < ackList.size(); i++){
        ReportStatus reportStatus = (ReportStatus) ackList.get(i);
        if ( reportStatus.getProviderNo().equals(providerNo) ) {
            labStatus = reportStatus.getStatus();
            if(labStatus.equals("A") ){
            	ackFlag = true;
            	break;
            }
        }
    }
}

String multiLabId = Hl7textResultsData.getMatchingLabs(segmentID);

MessageHandler handler = Factory.getHandler(segmentID);
String hl7 = Factory.getHL7Body(segmentID);
Hl7TextInfoDao hl7TextInfoDao = (Hl7TextInfoDao) SpringUtils.getBean("hl7TextInfoDao");
int lab_no = Integer.parseInt(segmentID);
String label = ""; Hl7TextInfo hl7Lab = hl7TextInfoDao.findLabId(lab_no);
if (hl7Lab.getLabel()!=null) label = hl7Lab.getLabel();
DemographicDao demographicDao = SpringUtils.getBean(DemographicDao.class);
Demographic demographic = demographicDao.getDemographic(demographicID);
String sISOservice = handler.getServiceDate().substring(0,9);
// check for errors printing
if (request.getAttribute("printError") != null && (Boolean) request.getAttribute("printError")){
%>
<script>
    alert("The lab could not be printed due to an error. Please see the server logs for more detail.");
</script>
<%}
%>
    <%
    int version = 0;
    if (multiLabId != null) {
        String[] multiID = multiLabId.split(",");
        if (multiID.length > 1) {
            for (int k = 0; k < multiID.length; ++k) {
                if (multiID[k].equals(segmentID)) {
                    version = k;
                }
            }
        }
    } %>
<!-- jQuery is referenced in Index.jsp that inserts this fragment, don't reference it here -->


<script>

    function popupStart(vheight, vwidth, varpage, windowname) {
        var page = varpage;
        windowprops = "height=" + vheight + ",width=" + vwidth + ",location=no,scrollbars=yes,menubars=no,toolbars=no,resizable=yes";
        var popup = window.open(varpage, windowname, windowprops);
    }

    function pop4(vheight, vwidth, varpage, windowName) {
        windowName = typeof(windowName) != 'undefined' ? windowName : 'demoEdit';
        <% if (!openInTabs) { %>
            vheight = typeof(vheight) != 'undefined' ? vheight : '700px';
            vwidth = typeof(vwidth) != 'undefined' ? vwidth : '1024px';
            var page = "" + varpage;
            windowprops = "height=" + vheight + ",width=" + vwidth + ",location=no,scrollbars=yes,menubars=no,toolbars=no,resizable=yes,screenX=0,screenY=0,top=0,left=0,noreferrer";
            var popup = window.open(varpage, windowName, windowprops);
            if (popup != null) {
                if (popup.opener == null) {
                    popup.opener = self;
                }
                popup.focus();
            }
        <% } else { %>
            window.open(varpage, windowName);
        <% } %>
    }

    function getComment(action, segmentId) {
        //the comment gets put into a hidden INPUT named comment with the id of comment_865969 ie comment_ + labid for update
        //the commment is displayed in a SPAN V0commentText865517101

        var ret = true;
        var commentVal = "";
        version = jQuery("#version_" + segmentId).val();

        var label = "V" + version + "commentLabel" + segmentId + jQuery("#providerNo").val(); // providerNo = "101";
        var text = "commentText" + segmentId + jQuery("#providerNo").val();

        <% if (rememberComment) { %>
            // use as default the comment for the prior version if it exists
            if (version > 0 && jQuery('#V' + (version - 1) + text).text().length > 0) {
                commentVal = jQuery('#V' + (version - 1) + text).text().trim();
            }
        <%  } %>

        // however the best default is the existing comment for this version
        if (jQuery('#V' + version + text).text().trim().length > 0) {
            commentVal = jQuery('#V' + version + text).text().trim();
        }

        if (commentVal == null) {
            commentVal = "";
        }

        var commentID = "comment_" + segmentId;

        if (action == "msgLabRecall") {
            if (commentVal == "") {
                commentVal = "Recall";
                jQuery("#" + commentID).val(commentVal);
                addComment('acknowledgeForm_' + segmentId, segmentId);
            }
            handleLab('acknowledgeForm_' + segmentId, segmentId, action);
            return;
        } else {
            var commentVal = prompt('<bean:message key="oscarMDS.segmentDisplay.msgComment"/>', commentVal);
        }

        if (commentVal == null) {
            // note that you can overwrite a comment but not delete it
            ret = false;
        } else if (commentVal.length > 0) {
            jQuery("#" + commentID).val(commentVal);
            //jQuery('#'+label).text("comment: ");
            //jQuery(('#V'+version+text).text(commentVal);

        } else {
            jQuery("#" + commentID).val(commentVal);
        }

        if (ret)
            handleLab('acknowledgeForm_' + segmentId, segmentId, action);

        return false;
    }

    function printPDF(doclabid) {
        document.forms['acknowledgeForm_' + doclabid].action = "<%=request.getContextPath()%>/lab/CA/ALL/PrintPDF.do";
        document.forms['acknowledgeForm_' + doclabid].submit();
    }

    function linkreq(rptId, reqId) {
        var link = "<%=request.getContextPath()%>/lab/LinkReq.jsp?table=hl7TextMessage&rptid=" + rptId + "&reqid=" + reqId + "<%=demographicID != null ? " & demographicNo = " + demographicID : ""%>";
        window.open(link, "linkwin", "width=500, height=200");
    }

    sendToPHR = function(labId, demographicNo) {
        popup(300, 600, "<%=request.getContextPath()%>/phr/SendToPhrPreview.jsp?labId=" + labId + "&demographic_no=" + demographicNo, "sendtophr");
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
                        var demoid = json.demoId;
                        if (success && demoid && demoid.length > 0) {
                            switch (action) {
                                case 'ackLab':
                                    if (confirmAck()) {
                                        document.getElementById("status_" + labid).value = "A";
                                        updateStatus(formid);
                                    }
                                    break;
                                case 'msgLab':
                                    popup(700, 960, '<%=request.getContextPath()%>/oscarMessenger/SendDemoMessage.do?demographic_no=' + demoid, 'msg');
                                    break;
                                case 'msgLabRecall':
                                    popup(700, 980, '<%=request.getContextPath()%>/oscarMessenger/SendDemoMessage.do?demographic_no=' + demoid + "&recall", 'msgRecall');
                                    popup(450, 600, '<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId=' + labid + '&demographic_no=' + demoid + '<%=ticklerAssignee%>&priority=<%=recallTicklerPriority%>&recall', 'ticklerRecall');
                                    break;
                                case 'ticklerLab':
                                    window.popup(530, 600, '<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=HL7&docId=' + labid + '&demographic_no=' + demoid, 'tickler');
                                    break;
                                case 'addComment':
                                    addComment(formid, labid);
                                    break;
                                case 'unlinkDemo':
                                    unlinkDemographic(labid);
                                    break;
                                case 'msgLabMAM':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=MAM', 'prevention'); <%
                                    if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                        window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q131A', 'billing'); <%
                                    } %>
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabPAP':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=PAP', 'prevention'); <%
                                    if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                        window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q011A', 'billing'); <%
                                    } %>
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabFIT':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=FOBT', 'prevention');
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabFIT':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=FOBT', 'prevention');
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabCOLONOSCOPY':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=COLONOSCOPY', 'prevention'); <%
                                    if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                        window.popup(700, 1280, '<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=' + demoid + '&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q142A', 'billing'); <%
                                    } %>
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabBMD':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=BMD', 'prevention');
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                                    break;
                                case 'msgLabPSA':
                                    window.popup(700, 980, '<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no=' + demoid + '&prevention=PSA', 'prevention');
                                    window.popup(450, 1280, '<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview=' + demoid);
                            } //end switch
                        } else { //not success no demo
                            if (action == 'ackLab') {
                                if (confirmAckUnmatched()) {
                                    document.getElementById("status_" + labid).value = "A";
                                    updateStatus(formid);
                                } else {
                                    var pn = document.getElementById("demoName" + labid).value;
                                    if (pn) popupStart(360, 680, '<%=request.getContextPath()%>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=' + labid + '&name=' + pn, 'searchPatientWindow');
                                }
                            } else {
                                alert("Please relate lab to a demographic.");
                                //pop up relate demo window
                                var pn = document.getElementById("demoName" + labid).value;
                                if (pn) popupStart(360, 680, '<%=request.getContextPath()%>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=' + labid + '&name=' + pn, 'searchPatientWindow');
                            }
                        } // end no demo
                    } //end json check
                } // end success function
        }); //end ajax call
    }

    function addComment(formid, labid) {
        var url = '<%=request.getContextPath()%>' + "/oscarMDS/UpdateStatus.do?method=addComment";
        //var status = "status_" + labid;

        if (jQuery("#status_" + labid).val() == "") {
            jQuery("#status_" + labid).val("N");
        }

        version = jQuery("#version_" + labid).val();

        var label = "V" + version + "commentLabel" + labid + jQuery("#providerNo").val(); // providerNo = "101";
        var text = "V" + version + "commentText" + labid + jQuery("#providerNo").val();

        var commentID = "comment_" + labid;
        var newComment;
        var data = jQuery("#" + formid).serialize();

        jQuery.ajax({
            type: "POST",
            url: url,
            data: data,
            success: function(data) {
                newComment = jQuery('#' + commentID).val();
                // note that the following are SPANs and not inputs
                jQuery('#' + label).text("comment: ");
                jQuery('#' + text).text(newComment);
            }
        });

    }

    function confirmAck() { <%
        if (props.getProperty("confirmAck", "").equals("yes")) { %>
            return confirm('<bean:message key="oscarMDS.index.msgConfirmAcknowledge"/>'); <%
        } else { %>
            return true; <%
        } %>
    }
    confirmAckUnmatched = function() {
        return confirm('<bean:message key="oscarMDS.index.msgConfirmAcknowledgeUnmatched"/>');
    }
    updateStatus = function(formid) {
        var url = '<%=request.getContextPath()%>' + "/oscarMDS/UpdateStatus.do";
        var data = jQuery('#' + formid).serialize();
        jQuery.ajax({
            type: "POST",
            url: url,
            data: data,
            success: function(data) {
                var num = formid.split("_");
                if (num[1]) {
                    jQuery('#labdoc_'+num[1]).hide('fade'); // blind, clip, scale, puff, fade
                    refreshCategoryList();
                }
            }
        });

    }

    createTdisLabel = function(tdisformid, ackformid, labelspanid, labelid) {
        document.forms[tdisformid].label.value = document.forms[ackformid].label.value;
        var url = '<%=request.getContextPath()%>' + "/lab/CA/ALL/createLabelTDIS.do";
        var data = jQuery('#' + tdisformid).serialize();
        jQuery.ajax({
            type: "POST",
            url: url,
            data: data,
        });

        document.getElementById(labelspanid).innerHTML = "<i> Label: " + document.getElementById(labelid).value + "</i>";
        document.getElementById(labelid).value = "";

    };
</script>
<div id="hl7_<%=segmentID%>">
    <div id="labdoc_<%=segmentID%>">
        <!-- form forwarding of the lab -->
        <form name="reassignForm_<%=segmentID%>" >
            <input type="hidden" name="flaggedLabs" value="<%= segmentID %>" >
            <input type="hidden" name="selectedProviders" value="" >
            <input type="hidden" name="labType" value="HL7" >
            <input type="hidden" name="labType<%= segmentID %>HL7" value="imNotNull" >
            <input type="hidden" name="providerNo" id="providerNo" value="<%= providerNo %>" >
            <input type="hidden" name="ajax" value="yes" >
            <input type="hidden" id="version_<%=segmentID%>" value="<%=version%>" >
        </form>
        <form name="TDISLabelForm" id="TDISLabelForm<%=segmentID%>" method='POST' onsubmit="createTdisLabel('TDISLabelForm<%=segmentID%>');" action="javascript:void(0);">
			<input type="hidden" id="labNum" name="lab_no" value="<%=lab_no%>">
			<input type="hidden" id="label" name="label" value="<%=label%>">
		</form>
        <form name="acknowledgeForm" id="acknowledgeForm_<%=segmentID%>" onsubmit="javascript:void(0);" method="post" action="javascript:void(0);">

            <table style="width:100%; height:100%; border:0px; border-spacing: 0px;" >
                <tr>
                    <td style="vertical-align: top;">
                        <table style="width:100%; border:0px; border-spacing: 0px;">
                            <tr>
                                <td style="text-align: left; width:100%;" class="MainTableTopRowRightColumn">
                                    <input type="hidden" name="segmentID" value="<%= segmentID %>">
                                    <input type="hidden" name="multiID" value="<%= multiLabId %>" >
                                    <input type="hidden" name="providerNo" value="<%= providerNo %>">
                                    <input type="hidden" name="status" value="<%=labStatus%>" id="status_<%=segmentID%>">
                                    <input type="hidden" name="comment" value="" id="comment_<%=segmentID%>">
                                    <input type="hidden" name="labType" value="HL7">
                                    <input type="hidden" name="ajaxcall" value="yes">
                                    <input type="hidden" id="demoName<%=segmentID%>" value="<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>">


                                    <% if ( !ackFlag ) { %>
<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {
									%>
											  <div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key="global.macro"/>&nbsp;<span class="caret" ></span></button>
											  <div class="dropdowns-content">


											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runhl7Macro('<%=name%>','acknowledgeForm_<%=segmentID%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									<% } %>
                                    <input type="button" class="btn btn-primary" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>" onclick="<%=ackLabFunc%>">

                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" onclick="return getComment('addComment','<%=segmentID%>');">

                                    <% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(300, 400, '<%=request.getContextPath()%>/oscarMDS/SelectProviderAltView.jsp?doc_no=<%=segmentID%>&providerNo=<%=providerNo%>&searchProviderNo=<%=searchProviderNo%>', 'providerselect')">

                                     <input type="button" class="btn" value="<bean:message key="caseload.msgMsg"/>" onclick="handleLab('','<%=segmentID%>','msgLab');"/>

                                     <input type="button" class="btn" value="<bean:message key="global.tickler"/>"  onclick="handleLab('','<%=segmentID%>','ticklerLab');"/>
                            <% if(recall){%>
                                     <input type="button" class="btn" value="Recall" onclick="getComment('msgLabRecall','<%=segmentID%>');">
                            <%}%>
                            <div class="dropdowns" >
                                <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret" ></span></button>
                                <div class="dropdowns-content">
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabFIT'); return false;">FIT</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabBMD'); return false;">BMD</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabPSA'); return false;">PSA</a>
                            <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupStart(700, 1280, '<%= request.getContextPath() %>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow');return false;"><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupStart(700,1000,'<%= request.getContextPath() %>/demographic/demographiccontrol.jsp?demographic_no=<%=demographicID%>&displaymode=edit','MDR<%=demographicID%>');return false;"><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupStart(500,1024,'<%= request.getContextPath() %>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=<%=demographicID%>','Rx<%=demographicID%>');return false;"><bean:message key="global.prescriptions"/></a>
                                <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupStart(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing');return false;"><bean:message key="global.billingtag"/></a>
                                <% } %>
                            <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% } %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','unlinkDemo');"/><bean:message key="oscarMDS.segmentDisplay.btnUnlinkDemo"/></a>
                                    <a href="javascript:void(0);" onclick="linkreq('<%=segmentID%>','<%=reqID%>');" />Req# <%=reqTableID%></a>
                                </div>
                            </div>


                                   	<% if (bShortcutForm) { %>
									<input type="button" class="btn" value="<%=formNameShort%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName%>&demographic_no=<%=demographicID%>', '<%=formNameShort%>')" />
									<% } %>
									<% if (bShortcutForm2) { %>
									<input type="button" class="btn" value="<%=formName2Short%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName2%>&demographic_no=<%=demographicID%>', '<%=formName2Short%>')" />
									<% } %>

									<input type="button" class="btn" value="<bean:message key="global.btnPDF"/>" onClick="printPDF('<%=segmentID%>')">
                                    <input type="button" class="btn" id="createLabel" value="Label"  onClick="createTdisLabel('TDISLabelForm<%=segmentID%>','acknowledgeForm_<%=segmentID%>','labelspan_<%=segmentID%>','label_<%=segmentID%>')">


                 <input type="text" class="input-large" id="label_<%=segmentID%>" style="margin-bottom:2px;" name="label" value=""/>
                 <% String labelval="";
                 if (label!="" && label!=null) {
                 	labelval = label;
                 }else {
                	 labelval = "(not set)";

                 } %>
                 <span id="labelspan_<%=segmentID%>" class="Field2"><i>Label: <%=labelval%> </i></span>
                                    <span class="Field2"><i>Next Appointment: <oscar:nextAppt demographicNo="<%=demographicID%>"/></i></span>
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
                                                Version:&#160;&#160;
                                                <%
                                                for (int i=0; i < multiID.length; i++){
                                                    if (multiID[i].equals(segmentID)){
                                                        %>v<%= i+1 %>&#160;<%
                                                    }else{
                                                        if ( searchProviderNo != null ) { // null if we were called from e-chart
                                                        	%><a href="javascript:void(0);"   onclick="popup(850, 950, '<%=request.getContextPath()%>/lab/CA/ALL/labDisplay.jsp?segmentID=<%=multiID[i]%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&searchProviderNo=<%= searchProviderNo %>', 'labVersion');">v<%= i+1 %></a>&#160;<%
                                                        }else{
                                                            %><a href="javascript:void(0);"  onclick="popup(850, 950, '<%=request.getContextPath()%>/lab/CA/ALL/labDisplay.jsp?segmentID=<%=multiID[i]%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>', 'labVersion');"  >v<%= i+1 %></a>&#160;<%
                                                        }
                                                    }
                                                }
                                                if( multiID.length > 1 ) {
                                                    if ( searchProviderNo != null ) { // null if we were called from e-chart
                                                        %><a href="javascript:void(0);" onclick="popup(850, 950, '<%=request.getContextPath()%>/lab/CA/ALL/labDisplay.jsp?segmentID=<%=segmentID%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&searchProviderNo=<%= searchProviderNo %>&all=true', 'labVersion');">All</a>&#160;<%
                                                    }else{
                                                        %><a href="javascript:void(0);" onclick="popup(850, 950, '<%=request.getContextPath()%>/lab/CA/ALL/labDisplay.jsp?segmentID=<%=segmentID%>&multiID=<%=multiLabId%>&providerNo=<%= providerNo %>&all=true', 'labVersion');">All</a>&#160;<%
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
                                                <table style="vertical-align:top; border-width:0px; border-spacing:0px; width:100%;  <% if ( demographicID.equals("") || demographicID.equals("0")){ %> background-color:orange; <% } %>" id="DemoTable<%=segmentID%>" >
                                                    <td style="vertical-align:top; text-align:left">
                                                            <table style="vertical-align:top; width:100%; text-align:left">
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formPatientName"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData" style="white-space:nowrap;">
                                                                            <% if ( searchProviderNo == null ) { // we were called from e-chart
                                                                                %>
                                                                            <a href="javascript:window.close()"> <% } else { // we were called from lab module
    %></a>
                                                                            <a href="javascript:popupStart(360, 680, '<%=request.getContextPath()%>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow')">
                                                                                <% } %>
                                                                                <%=handler.getLastName()+", "+handler.getFirstName()%>
                                                                            </a>
                                                                        </div>
                                                                    </td>
                                                                    <td colspan="2"></td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formDateBirth"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData" style="white-space:nowrap;">
                                                                            <%=handler.getDOB()%>
                                                                        </div>
                                                                    </td>
                                                                    <td colspan="2"></td>
                                                                </tr>
                                                                 <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formAge"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div class="FieldData">
                                                                            <%=handler.getAge()%>
                                                                        &nbsp;
                                                                            <bean:message key="oscarMDS.segmentDisplay.formSex"/>:
                                                                        &nbsp;
                                                                            <%=handler.getSex()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td nowrap>
                                                                        <div class="FieldData">
                                                                            <strong>
                                                                                <bean:message key="oscarMDS.segmentDisplay.formHealthNumber"/>
                                                                            </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td nowrap>
                                                                        <div class="FieldData" nowrap="nowrap">
                                                                            <%=handler.getHealthNum()%>
                                                                        </div>
                                                                    </td>
                                                                    <td colspan="2"></td>
                                                                </tr>
                                                            </table>
                                                        </td>
                                                       <td style="width:33%; vertical-align:top;">
                                                            <table style="width:100%; vertical-align:top; border-width:0px; border-spacing:0px;">
                                                                <tr>
                                                                    <td style="white-space:nowrap; ">
                                                                        <div style="text-align: left" class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formHomePhone"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldData">
                                                                            <%=handler.getHomePhone()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formWorkPhone"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldData">
                                                                            <%=handler.getWorkPhone()%>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formEmail"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left; white-space:nowrap;" class="FieldData">
                                                						<% if(demographicID != null && !demographicID.equals("") && !demographicID.equals("0")){
                                                    						if (demographic.getConsentToUseEmailForCare() != null && demographic.getConsentToUseEmailForCare()){ %>
                                                                            <a href="mailto:<%=demographic.getEmail()%>?subject=Message from your Doctors Office" target="_blank" rel="noopener noreferrer" ><%=demographic.getEmail()%></a>
                                                                        <% } else { %>
                                                                            <span id="email<%= segmentID %>"><%=demographic.getEmail()%></span>
                                                                        <% } } %>
                                                                        </div>
                                                                    </td>
                                                                </tr>
                                                                <tr>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left" class="FieldData">
                                                                            <strong><bean:message key="oscarMDS.segmentDisplay.formPatientLocation"/>: </strong>
                                                                        </div>
                                                                    </td>
                                                                    <td style="white-space:nowrap;">
                                                                        <div style="text-align:left; white-space:nowrap;" class="FieldData">
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
                                                <div class="FieldData">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formDateService"/>:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldData" style="white-space:nowrap;">
                                                    <%= handler.getServiceDate() %>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div class="FieldData">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formReportStatus"/>:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldData" style="white-space:nowrap;">
                                                    <%= ( handler.getOrderStatus().equals("F") ? "Final" : handler.getOrderStatus().equals("C") ? "Corrected" : (handler.getMsgType().equals("PATHL7") && handler.getOrderStatus().equals("P")) ? "Preliminary": handler.getOrderStatus().equals("X") ? "DELETED": handler.getOrderStatus()) %>
										</div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="white-space:nowrap;">
                                                <div class="FieldData">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formClientRefer"/>:</strong>
                                                </div>
                                            </td>
                                            <td nowrap>
                                                <div class="FieldData" style="white-space:nowrap;">
                                                    <%= handler.getClientRef()%>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div class="FieldData">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formAccession"/>:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldData" style="white-space:nowrap;">
                                                    <%= handler.getAccessionNum()%>
                                                </div>
                                            </td>
                                        </tr>
                                        <% if (handler.getMsgType().equals("MEDVUE")) {  %>
                                        <tr>
                                        	<td>
                                                <div class="FieldData">
                                                    <strong>MEDVUE Encounter Id:</strong>
                                                </div>
                                            </td>
                                            <td>
                                                <div class="FieldData" style="white-space:nowrap;">
                                                   <%= handler.getEncounterId() %>
                                                </div>
                                            </td>
                                        </tr>
                                        <% } %>
                                    </table>
                                </td>
                            </tr>
                            <tr>
                                <td style="background-color:white; " colspan="2">
                                    <table style="width:100%; border-width:0px; border-color:#CCCCCC">
                                        <tr style="border-bottom: 1px solid;">
                                            <td style="background-color:white">
                                                <div class="FieldData">
                                                    <strong><bean:message key="oscarMDS.segmentDisplay.formRequestingClient"/>: </strong>
                                                    <%= handler.getDocName()%>
                                                </div>
                                            </td>

                                            <td style="background-color:white; text-align:right">
                                                <div class="FieldData">
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
	                    if(demographicID!=null && !demographicID.equals("")){
                            for(int mcount=0; mcount<multiID.length; mcount++){

							    TicklerManager ticklerManager = SpringUtils.getBean(TicklerManager.class);
							    List<Tickler> LabTicklers = ticklerManager.getTicklerByLabIdAnyProvider(loggedInInfo, Integer.valueOf(multiID[mcount]), Integer.valueOf(demographicID));
							    if(LabTicklers!=null && LabTicklers.size()>0){
                                    if(!isTickler){
%>
                            <div id="ticklerWrap" class="DoNotPrint">
							    <h4 style="color:#fff"><a href="javascript:void(0)" id="open-ticklers" onclick="showHideItem('ticklerDisplay<%=segmentID%>')">View Ticklers</a> Linked to this Lab</h4>
                                <div id="ticklerDisplay<%=segmentID%>" style="display:none">
<%

                                        isTickler = true;
                                    } // end isTickler wrap start for first tickler

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
							   } //end for loop for each tickler in LabTicklers
							   %>
							   		<!-- end ticklers for this v-->

							   <%
	                            } // if there are ticklers
                            } // end of mcount loop
	                    } // end if valid demographicID

    if(isTickler){
    %>
                                </div><!-- end ticklerDisplay-->
                            </div><!-- end ticklerWrap-->
    <%
    } // if isTickler you need to close the wrapper


                                    ReportStatus report;
                                    boolean startFlag = false;
                                    for (int j=multiID.length-1; j >=0; j--){
                                        ackList = AcknowledgementData.getAcknowledgements(multiID[j]);
                                        if (multiID[j].equals(segmentID))
                                            startFlag = true;
                                        if (startFlag)
                                            if (ackList.size() > 0){{%>
                                                <table style="width:100%; height:20px">
                                                    <tr>
                                                        <% if (multiID.length > 1){ %>
                                                            <td align="center" bgcolor="white" width="20%" valign="top">
                                                                <div class="FieldData">
                                                                    <b>Version:</b> v<%= j+1 %>
                                                                </div>
                                                            </td>
                                                            <td style="text-align: left; background-color:white; width:80%; vertical-align:top">
                                                        <% }else{ %>
                                                            <td style="text-align:center; background-color:white;">
                                                        <% } %>
                                                            <div class="FieldData">
                                                                <!--center-->
                                                                    <% for (int i=0; i < ackList.size(); i++) {
                                                                        report = (ReportStatus) ackList.get(i); %>
                                                                        <%= Encode.forHtml(report.getProviderName()) %> :

                                                                        <% String ackStatus = report.getStatus();
                                                                            if(ackStatus.equals("A")){
                                                                                ackStatus = "Acknowledged";
                                                                            }else if(ackStatus.equals("F")){
                                                                                ackStatus = "Filed but not Acknowledged";
                                                                            }else{
                                                                                ackStatus = "Not Acknowledged";
                                                                            }
                                                                        %>
                                                                        <span style="color:red"><%= ackStatus %></span>

                                                                            <%= report.getTimestamp() %>,
                                                                            <% String commentTitle = null;
                                                                               if(report.getComment() == null || report.getComment().equals("")) {
                                                                        	   	commentTitle = "no comment";
                                                                               }
                                                                               else {
                                                                        	   	commentTitle = "comment: ";
                                                                               }
                                                                            %>
                                                                            <span id="<%="V" + j + "commentLabel" + segmentID + report.getOscarProviderNo()%>"><%=commentTitle%></span><span id="<%="V" + j + "commentText" + segmentID + report.getOscarProviderNo()%>"> <%=report.getComment() == null ? "" : Encode.forHtmlContent(report.getComment())%></span>

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

                                            <%}
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

						ArrayList <String> headers = handler.getHeaders();
						int OBRCount = handler.getOBRCount();

                        if (handler.getMsgType().equals("MEDVUE")) { %>
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
                               <%--<td align="right" bgcolor="#FFCC00" width="100">&nbsp;</td>--%>
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
                           </tr>
	                        <tr class="TDISRes">
		                      	<td style="vertical-align:top; text-align:left" colspan="8" ><pre  style="margin:0px 0px 0px 100px;"><b>Radiologist: </b><b><%=handler.getRadiologistInfo()%></b></pre>
                                </td>
	                     	 </tr>
	                        <tr class="TDISRes">
		                       	<td style="vertical-align:top; text-align:left" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><b><%=handler.getOBXComment(1, 1, 1)%></b></pre>
		                       	</td>
	                      	 </tr>
                     	 </table>
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
    						}
		                       %>
                               <table style="page-break-inside:avoid; width:100%; border:0px">
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
                           	<%if(isUnstructuredDoc){%>
	                       <table style="width:100%; border:0px; " id="tblDiscs2">
	                           <tr class="Field2">
	                               <td style="width:20%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
	                               <td style="width:60%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
	                               <td style="width:20%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
	                           </tr><%
						} else {%>
                        <table style="width:100%; border:0px;" id="tblDiscs3">
                            <tr class="Field2">
                                <td style="width:25%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formTestName"/></td>
                                <td style="width:15%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formResult"/></td>
                                <td style="width:5%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formAbn"/></td>
                                <td style="width:15%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formReferenceRange"/></td>
                                <td style="width:10%; text-align:center; vertical-align:bottom" class="Cell"><bean:message key="oscarMDS.segmentDisplay.formUnits"/></td>
                                <td style="width:15%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formDateTimeCompleted"/></td>
                                <td style="width:6%; text-align:center; vertical-align:bottom"  class="Cell"><bean:message key="oscarMDS.segmentDisplay.formNew"/></td>
                            </tr>

                            <%}

                            for ( j=0; j < OBRCount; j++){

                                boolean obrFlag = false;
                                int obxCount = handler.getOBXCount(j);

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
                                     boolean b2 = !obxName.equals(""), b3=handler.getObservationHeader(j, k).equals(headers.get(i));
                                    if (handler.getMsgType().equals("EPSILON")) {
                                    	b2=true; b3=true;
                                    } else if(handler.getMsgType().equals("PFHT") || handler.getMsgType().equals("HHSEMR")) {
                                    	b2=true;
                                    }


                                    if ( !handler.getOBXResultStatus(j, k).equals("DNS") && b2 && b3){ // <<--  DNS only needed for MDS messages
                                        String obrName = handler.getOBRName(j);
                                        if(!obrFlag && !obrName.equals("") && !(obxName.contains(obrName) && obxCount < 2)){%>
                                           <%--  <tr bgcolor="<%=(linenum % 2 == 1 ? highlight : "")%>" >
                                                <td valign="top" align="left"><%=obrName%></td>
                                                <td colspan="6">&nbsp;</td>
                                            </tr> --%>
                                            <%obrFlag = true;
                                        }

                                        String lineClass = "NormalRes";
                                        String abnormal = handler.getOBXAbnormalFlag(j, k);
                                        if ( abnormal != null && abnormal.startsWith("L")){
                                            lineClass = "HiLoRes";
                                        } else if ( abnormal != null && ( abnormal.equals("A") || abnormal.startsWith("H") || handler.isOBXAbnormal( j, k) ) ){
                                            lineClass = "AbnormalRes";
                                        }%>
                                        <%if (handler.getMsgType().equals("EPSILON")) {
	                                    	   if (handler.getOBXIdentifier(j,k).equals(headers.get(i)) && !obxName.equals("")) { %>

	                                        	<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">
		                                            <td style="vertical-align:top; text-align:left;"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier='+encodeURIComponent('<%= handler.getOBXIdentifier(j, k)%>'))"><%=obxName %></a></td>
		                                            <td style="text-align:right"><%= handler.getOBXResult( j, k) %></td>

		                                            <td style="text-align:center">
		                                                    <%= handler.getOBXAbnormalFlag(j, k)%>
		                                            </td>
		                                            <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
		                                            <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
		                                            <td style="text-align:center"><%= handler.getOBXResultStatus( j, k) %></td>
	                                       		</tr>
	                                       <% } else if (handler.getOBXIdentifier(j,k).equals(headers.get(i)) && obxName.equals("")) { %>
	                                       			<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
	                                                    <td style="text-align:left; vertical-align:top" colspan="8"><pre style="margin:0px 0px 0px 100px;"><%=handler.getOBXResult( j, k)%></pre></td>
	                                                </tr>
	                                       	<% }
                                        } else if (handler.getMsgType().equals("PFHT") || handler.getMsgType().equals("HHSEMR")) {
	                                    	   if (!obxName.equals("")) { %>
		                                    		<tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="<%=lineClass%>">
			                                            <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier='+encodeURIComponent('<%= handler.getOBXIdentifier(j, k)%>'))"><%=obxName %></a></td>
			                                            <td style="text-align:right"><%= handler.getOBXResult( j, k) %></td>

			                                            <td style="text-align:center">
			                                                    <%= handler.getOBXAbnormalFlag(j, k)%>
			                                            </td>
			                                            <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
		                                                <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>
		                                                <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
		                                                <td style="text-align:center"><%= handler.getOBXResultStatus( j, k) %></td>
		                                       		 </tr>

	                                    	 	<%} else { %>
	                                    		 <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
	      	                                        <td style="text-align:left; vertical-align:top" colspan="8">
                                                        <pre style="margin:0px 0px 0px 100px;"><%=handler.getOBXResult( j, k)%></pre>
                                                    </td>
	      	                                	 </tr>
	                                    	 	<%}
		                                    	if (!handler.getNteForOBX(j,k).equals("") && handler.getNteForOBX(j,k)!=null) { %>
			                                       <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="NormalRes">
			                                       		<td valign="top" align="left"colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getNteForOBX(j,k)%></pre></td>
			                                       </tr>
			                                    <% }
				                                for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
				                                     <tr bgcolor="<%=(linenum % 2 == 1 ? highlight : "")%>" class="NormalRes">
				                                        <td style="text-align:left; vertical-align:top" colspan="8">
                                                           <pre style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre>
                                                        </td>
				                                     </tr>
				                                <%}


                                      } else  if (!handler.getOBXResultStatus(j, k).equals("TDIS") && !handler.getMsgType().equals("EPSILON")) {
                                          	%><tr bgcolor="<%=(linenum % 2 == 1 ? highlight : "")%>" class="<%=lineClass%>"><%
                                       		if(isUnstructuredDoc){
	                                   			if(handler.getOBXIdentifier(j, k).equalsIgnoreCase(handler.getOBXIdentifier(j, k-1)) && (obxCount>1)){%>
	                                   				<td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier='+encodeURIComponent('<%= handler.getOBXIdentifier(j, k)%>'))"></a><%
	                                   				}
	                                   			else{%> <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= handler.getOBXIdentifier(j, k) %>')"><%=obxName %></a><%}%>
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
											    	<td style="text-align:left"><%= rtfText + disclaimer %></td><%} %><%
												else{%>
	                                           		<td style="text-align:left"><%= handler.getOBXResult( j, k) %></td><%} %>
	                                           	<%if(handler.getTimeStamp(j, k).equals(handler.getTimeStamp(j, k-1)) && (obxCount>1)){
	                                        			%><td style="text-align:center"></td><%}
	                                        		else{%> <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td><%}
                                   			}//end of isUnstructuredDoc

                                   			else{//if it isn't a PATHL7 doc
                                   				//if there are duplicate FT/TX obxNames, only display the first (only if handler is PATHL7)
	                                   			if(handler.getMsgType().equals("PATHL7")&& !isAllowedDuplicate && (obxCount>1) && handler.getOBXIdentifier(j, k).equalsIgnoreCase(handler.getOBXIdentifier(j, k-1)) && (handler.getOBXValueType(j, k).equals("TX") || handler.getOBXValueType(j, k).equals("FT"))){%>
	                                   				<td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier=<%= handler.getOBXIdentifier(j, k) %>')"></a><%
	                                   				}
	                               				else{%>
	                                            <td style="text-align:left; vertical-align:top"><%= obrFlag ? "&nbsp; &nbsp; &nbsp;" : "&nbsp;" %><a href="javascript:popupStart('660','900','<%=request.getContextPath()%>/lab/CA/ON/labValues.jsp?testName=<%=obxName%>&demo=<%=demographicID%>&labType=HL7&identifier='+encodeURIComponent('<%= handler.getOBXIdentifier(j, k)%>'))"><%=obxName %></a></td><%}%>
	                                            <%
	                                          	//for pathl7, if it is an SG/CDC result greater than 100 characters, left justify it
	                                            if((handler.getOBXResult(j, k) != null && handler.getOBXResult(j, k).length() > 100) && isSGorCDC){%>
	                                            	<td style="text-align:left;"><%= handler.getOBXResult( j, k) %></td><%
	                                            }else{%>
	                                            											<%
												if((handler.getMsgType().equals("ExcellerisON") || handler.getMsgType().equals("PATHL7")) && handler.getOBXValueType(j,k).equals("ED")) {
													String legacy = "";
													if(handler.getMsgType().equals("PATHL7") && ((PATHL7Handler)handler).isLegacy(j,k) ) {
														legacy ="&legacy=true";
													}

												%>
													 <td style="text-align:right"><a href="<%=request.getContextPath() %>/lab/DownloadEmbeddedDocumentFromLab.do?labNo=<%=segmentID%>&segment=<%=j%>&group=<%=k%><%=legacy%>">PDF Report</a></td>
													 <%
												} else {
											%>
	                                            <td style="text-align:right"><%= handler.getOBXResult( j, k) %></td><%}%>
	                                            <% } %>
	                                            <td style="text-align:center">
	                                                    <%= handler.getOBXAbnormalFlag(j, k)%>
	                                            </td>
	                                            <td style="text-align:left"><%=handler.getOBXReferenceRange( j, k)%></td>
	                                            <td style="text-align:left"><%=handler.getOBXUnits( j, k) %></td>
	                                            <td style="text-align:center"><%= handler.getTimeStamp(j, k) %></td>
	                                            <td style="text-align:center"><%= handler.getOBXResultStatus( j, k) %></td><%
	                                   			}//end of PATHL7 else %>
                                        </tr>

                                        <%for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
                                            <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>"  class="NormalRes">
                                                <td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
                                            </tr>
                                        <%}
	                                    } else { %>
		                                	<%for (l=0; l < handler.getOBXCommentCount(j, k); l++){%>
		                                     <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" class="TDISRes">
		                                        <td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBXComment(j, k, l)%></pre></td>
		                                     </tr>
		                                	<%}
	                                   }
                                   }
                                }
                            //}

                            //for ( j=0; j< OBRCount; j++){
                             if (!handler.getMsgType().equals("PFHT")) {
                                if (headers.get(i).equals(handler.getObservationHeader(j, 0))) {%>
                                <%for (k=0; k < handler.getOBRCommentCount(j); k++){
                                    // the obrName should only be set if it has not been
                                    // set already which will only have occured if the
                                    // obx name is "" or if it is the same as the obr name
                                    if(!obrFlag && handler.getOBXName(j, 0).equals("")){%>
                                        <tr bgcolor="<%=(linenum % 2 == 1 ? highlight : "")%>" >
                                            <td valign="top" align="left"><%=handler.getOBRName(j)%></td>
                                            <td colspan="6">&nbsp;</td>
                                        </tr>
                                        <%obrFlag = true;
                                    }%>
                                <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>"  class="NormalRes">
                                    <td style="text-align:left; vertical-align:top" colspan="8"><pre  style="margin:0px 0px 0px 100px;"><%=handler.getOBRComment(j, k)%></pre></td>
                                </tr>
                                <% if  (!handler.getMsgType().equals("HHSEMR")) {
                                	if(handler.getOBXName(j,k).equals("")){
                                       String result = handler.getOBXResult(j, k);%>
                                        <tr style="<%=(linenum % 2 == 1 ? "background-color:"+highlight : "")%>" >
                                                <td style="text-align:left; vertical-align:top"  colspan="7"><%=result%></td>
                                        </tr>
                                            <%
                                    }
                                }


                                }
                            }
                             } // end for if (PFHT)
                            }
                          } // end for handler.getMsgType().equals("MEDVUE")
                            %>
                        </table>
                        <% // end for headers
                        }  // for i=0... (headers)
  					 %>
                    <%
                    if ( props.isPropertyActive("SHOW_BOTTOM_LAB_BUTTONS") ) {
                    %>
                        <table style="width:100%; border:0px; background-color:silver" class="MainTableBottomRowRightColumn" >
                            <tr>
                                <td style="text-align: left; width:100%">
                                    <% if ( !ackFlag ) { %>
<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {
									%>
											  <div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key="global.macro"/>&nbsp;<span class="caret" ></span></button>
											  <div class="dropdowns-content">


											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runhl7Macro('<%=name%>','acknowledgeForm_<%=segmentID%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									<% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>" onclick="<%=ackLabFunc%>">

                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" onclick="return getComment('addComment','<%=segmentID%>');">

                                    <% } %>
                                    <input type="button" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(300, 400, '<%=request.getContextPath()%>/oscarMDS/SelectProviderAltView.jsp?doc_no=<%=segmentID%>&providerNo=<%=providerNo%>&searchProviderNo=<%=searchProviderNo%>', 'providerselect')">

                                     <input type="button" class="btn" value="<bean:message key="caseload.msgMsg"/>" onclick="handleLab('','<%=segmentID%>','msgLab');"/>

                                     <input type="button" class="btn" value="<bean:message key="global.tickler"/>"  onclick="handleLab('','<%=segmentID%>','ticklerLab');"/>
                            <% if(recall){%>
                                     <input type="button" class="btn" value="Recall" onclick="getComment('msgLabRecall','<%=segmentID%>');">
                            <%}%>
                            <div class="dropdowns" >
                                <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret" ></span></button>
                                <div class="dropdowns-content">
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabFIT'); return false;">FIT</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabBMD'); return false;">BMD</a>
                                    <a href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','msgLabPSA'); return false;">PSA</a>
                            <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupStart(700, 1280, '<%= request.getContextPath() %>/oscarMDS/SearchPatient.do?labType=HL7&segmentID=<%= segmentID %>&name=<%=java.net.URLEncoder.encode(handler.getLastName()+", "+handler.getFirstName())%>', 'searchPatientWindow');return false;"><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupStart(700,1000,'<%= request.getContextPath() %>/demographic/demographiccontrol.jsp?demographic_no=<%=demographicID%>&displaymode=edit','MDR<%=demographicID%>');return false;"><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupStart(500,1024,'<%= request.getContextPath() %>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=<%=demographicID%>','Rx<%=demographicID%>');return false;"><bean:message key="global.prescriptions"/></a>
                                <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupStart(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing');return false;"><bean:message key="global.billingtag"/></a>
                                <% } %>
                            <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;"></a>
                            <% } %>
                                    <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="handleLab('','<%=segmentID%>','unlinkDemo');"/><bean:message key="oscarMDS.segmentDisplay.btnUnlinkDemo"/></a>
                                    <a href="javascript:void(0);" onclick="linkreq('<%=segmentID%>','<%=reqID%>');" />Req# <%=reqTableID%></a>
                                </div>
                            </div>


                                   	<% if (bShortcutForm) { %>
									<input type="button" class="btn" value="<%=formNameShort%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName%>&demographic_no=<%=demographicID%>', '<%=formNameShort%>')" />
									<% } %>
									<% if (bShortcutForm2) { %>
									<input type="button" class="btn" value="<%=formName2Short%>" onClick="popupStart(700, 1024, '../../../form/forwardshortcutname.jsp?formname=<%=formName2%>&demographic_no=<%=demographicID%>', '<%=formName2Short%>')" />
									<% } %>

									<input type="button" class="btn" value="<bean:message key="global.btnPDF"/>" onClick="printPDF('<%=segmentID%>')">
                                </td>
                            </tr>
                        </table>
                <%
                }
                %>
                    </td>
                </tr>
                <tr><td colspan="1"><a style="color:white;" href="javascript:void(0);" onclick="showHideItem('rawhl7_<%=segmentID%>');" >show/hide</a>
                    <pre id="rawhl7_<%=segmentID%>" style="display:none;"><%=hl7%></pre></td></tr>
                <tr><td colspan="1" ><hr style="border: 1px solid red"></td></tr>
            </table>
        </form>

    </div>
</div>