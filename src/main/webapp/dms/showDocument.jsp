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

<%@page import="org.oscarehr.util.MiscUtils"%>
<%@page import="org.apache.commons.lang.StringUtils"%>
<%@page import="org.oscarehr.util.LoggedInInfo"%>
<%@page import="java.util.ResourceBundle" %>

<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
    String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");
    boolean authed=true;
%>
<security:oscarSec roleName="<%=roleName$%>" objectName="_edoc" rights="r" reverse="<%=true%>">
	<%authed=false; %>
	<%response.sendRedirect("../securityError.jsp?type=_edoc");%>
</security:oscarSec>
<%
	if(!authed) {
		return;
	}
%>

<%@ page import="java.text.SimpleDateFormat"%>
<%@ page import="java.util.*" %>
<%@ page import="net.sf.json.JSONException"%>
<%@ page import="net.sf.json.JSONSerializer"%>
<%@ page import="net.sf.json.JSONObject"%>
<%@ page import="net.sf.json.JSONArray"%>
<%@ page import="org.springframework.web.context.support.WebApplicationContextUtils"%>
<%@ page import="org.springframework.web.context.WebApplicationContext"%>
<%@ page import="org.apache.commons.lang.StringEscapeUtils"%>

<%@ page import="oscar.SxmlMisc" %>
<%@ page import="oscar.log.*"%>
<%@ page import="oscar.dms.*" %>
<%@ page import="oscar.util.ConversionUtils" %>

<%@ page import="oscar.OscarProperties" %>
<%@ page import="oscar.oscarLab.ca.all.*"%>
<%@ page import="oscar.oscarMDS.data.*"%>
<%@ page import="oscar.oscarLab.ca.all.util.*"%>
<%@ page import="oscar.oscarDemographic.data.DemographicData" %>

<%@ page import="org.oscarehr.myoscar.utils.MyOscarLoggedInInfo"%>
<%@ page import="org.oscarehr.phr.util.MyOscarUtils"%>
<%@ page import="org.oscarehr.util.WebUtils"%>
<%@ page import="org.oscarehr.PMmodule.dao.ProviderDao"%>
<%@ page import="org.oscarehr.common.dao.UserPropertyDAO" %>
<%@ page import="org.oscarehr.common.model.UserProperty" %>
<%@ page import="org.oscarehr.util.SpringUtils" %>
<%@ page import="org.oscarehr.common.model.Tickler" %>
<%@ page import="org.oscarehr.managers.TicklerManager" %>
<%@ page import="org.oscarehr.managers.CanadianVaccineCatalogueManager2"%>
<%@ page import="org.oscarehr.common.dao.OscarAppointmentDao" %>
<%@ page import="org.oscarehr.common.model.Provider" %>
<%@ page import="org.oscarehr.common.dao.*"%>
<%@ page import="org.oscarehr.common.model.*"%>

<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c"%>
<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean"%>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html"%>
<%@ taglib uri="/WEB-INF/rewrite-tag.tld" prefix="rewrite"%>
<%@ taglib uri="/WEB-INF/oscar-tag.tld" prefix="oscar"%>
<jsp:useBean id="displayServiceUtil" scope="request" class="oscar.oscarEncounter.oscarConsultationRequest.config.pageUtil.EctConDisplayServiceUtil" />

<%
    LoggedInInfo loggedInInfo=LoggedInInfo.getLoggedInInfoFromSession(request);
    ResourceBundle oscarRec = ResourceBundle.getBundle("oscarResources", request.getLocale());
    displayServiceUtil.estSpecialist();
    String providerNoFromChart = null;
    String demoNo = request.getParameter("demographicNo");
    DemographicData demoData = null;
    Demographic demographic = null;
    String familyDoctor = null;
    String rdohip = "";
    if (demoNo != null) {
        demoData = new oscar.oscarDemographic.data.DemographicData();
        demographic = demoData.getDemographic(loggedInInfo, demoNo);
        providerNoFromChart = demographic.getProviderNo();
        familyDoctor = demographic.getFamilyDoctor();
        if (familyDoctor != null && familyDoctor.trim().length() > 0) {
            rdohip = SxmlMisc.getXmlContent(familyDoctor, "rdohip");
            rdohip = rdohip == null ? "" : rdohip.trim();
        }
    }

    oscar.OscarProperties props = oscar.OscarProperties.getInstance();
	String curUser_no = (String) session.getAttribute("user");
	UserPropertyDAO userPropertyDao = SpringUtils.getBean(UserPropertyDAO.class);
	UserProperty tabViewProp = userPropertyDao.getProp(curUser_no, UserProperty.OPEN_IN_TABS);
    boolean openInTabs = false;
    if ( tabViewProp == null ) {
        openInTabs = oscar.OscarProperties.getInstance().getBooleanProperty("open_in_tabs", "true");
    } else {
        openInTabs = oscar.OscarProperties.getInstance().getBooleanProperty("open_in_tabs", "true") || Boolean.parseBoolean(tabViewProp.getValue());
    }


            UserPropertyDAO userPropertyDAO = (UserPropertyDAO)SpringUtils.getBean("UserPropertyDAO");
            String providerNo = request.getParameter("providerNo");
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

            WebApplicationContext ctx = WebApplicationContextUtils.getRequiredWebApplicationContext(getServletContext());
            ProviderInboxRoutingDao providerInboxRoutingDao = (ProviderInboxRoutingDao) ctx.getBean("providerInboxRoutingDAO");

            OscarAppointmentDao appointmentDao = SpringUtils.getBean(OscarAppointmentDao.class);
            ProviderDao providerDao = (ProviderDao)SpringUtils.getBean("providerDao");


            UserProperty uProp = userPropertyDAO.getProp(providerNo, UserProperty.LAB_ACK_COMMENT);
            boolean skipComment = false;

            if( uProp != null && uProp.getValue().equalsIgnoreCase("yes")) {
            	skipComment = true;
            }

            uProp = userPropertyDAO.getProp(providerNo, UserProperty.DISPLAY_DOCUMENT_AS);
            String displayDocumentAs=UserProperty.IMAGE;
            if( uProp != null && uProp.getValue().equals(UserProperty.PDF)) {
            	displayDocumentAs = UserProperty.PDF;
            }

            String demoName=request.getParameter("demoName");
            String documentNo = request.getParameter("segmentID");


            String searchProviderNo = request.getParameter("searchProviderNo");
            String status = request.getParameter("status");
            String inQueue=request.getParameter("inQueue");

            boolean inQueueB=false;
            if(inQueue!=null) {
                inQueueB=true;
            }

            String defaultQueue = IncomingDocUtil.getAndSetIncomingDocQueue(providerNo, null);
            QueueDao queueDao = (QueueDao) ctx.getBean("queueDao");
            List<Hashtable> queues = queueDao.getQueues();
            int queueId=1;
            if (defaultQueue != null) {
                defaultQueue = defaultQueue.trim();
                queueId = Integer.parseInt(defaultQueue);
            }

            String creator = (String) session.getAttribute("user");
            ArrayList doctypes = EDocUtil.getActiveDocTypes("demographic");
            EDoc curdoc = EDocUtil.getDoc(documentNo);

            String demographicID = curdoc.getModuleId();
            if ((demographicID != null) && !demographicID.isEmpty() && !demographicID.equals("-1")){
                DemographicDao demographicDao = (DemographicDao)SpringUtils.getBean("demographicDao");
                //Demographic demographic = demographicDao.getDemographic(demographicID);
				//demoName = demographic.getLastName()+","+demographic.getFirstName();
				LogAction.addLog((String) session.getAttribute("user"), LogConst.READ, LogConst.CON_DOCUMENT, documentNo, request.getRemoteAddr(),demographicID);
            }

            String docId = curdoc.getDocId();

            String ackFunc;
            if( skipComment ) {
            	ackFunc = "updateStatus('acknowledgeForm_" + docId + "'," + inQueueB + ");";
            }
            else {
            	ackFunc = "getDocComment('" + docId + "','" + providerNo + "'," + inQueueB + ");";
            }


            int slash = 0;
            String contentType = "";
            if ((slash = curdoc.getContentType().indexOf('/')) != -1) {
                contentType = curdoc.getContentType().substring(slash + 1);
            }
            String dStatus = "";
            if ((curdoc.getStatus() + "").compareTo("A") == 0) {
                dStatus = "active";
            } else if ((curdoc.getStatus() + "").compareTo("H") == 0) {
                dStatus = "html";
            }
            int numOfPage=curdoc.getNumberOfPages();
            String numOfPageStr="";
            if(numOfPage==0)
                numOfPageStr="unknown";
            else
                numOfPageStr=(new Integer(numOfPage)).toString();
            String cp=request.getContextPath() ;
            String url = cp+"/dms/ManageDocument.do?method=viewDocPage&doc_no=" + docId+"&curPage=1";
            String url2 = cp+"/dms/ManageDocument.do?method=display&doc_no=" + docId;
            String currentDate = new SimpleDateFormat("yyyy-MM-dd").format(new Date());
%>
<% if (request.getParameter("inWindow") != null && request.getParameter("inWindow").equalsIgnoreCase("true")) {  %>
<!DOCTYPE html>
<html>
<head>
    <title><bean:message key='global.Document'/></title>
<!-- i18n calendar -->
    <script src="<%=request.getContextPath()%>/share/calendar/calendar.js"></script>
    <script src="<%=request.getContextPath()%>/share/calendar/lang/<bean:message key='global.javascript.calendar'/>"></script>
    <script src="<%=request.getContextPath()%>/share/calendar/calendar-setup.js"></script>
    <link href="<%=request.getContextPath()%>/share/calendar/calendar.css" title="win2k-cold-1" rel="stylesheet" type="text/css" media="all" >

<!-- jquery -->
    <script src="<%=request.getContextPath()%>/library/jquery/jquery-3.6.4.min.js"></script>
    <script src="<%=request.getContextPath()%>/library/jquery/jquery-ui-1.12.1.min.js"></script>

<!-- oscar -->
    <script src="<%=request.getContextPath()%>/share/javascript/Oscar.js" ></script>
    <script src="<%=request.getContextPath()%>/share/javascript/casemgmt/faxControl.js"> </script>
    <script src="<%=request.getContextPath()%>/js/demographicProviderAutocomplete.js"></script>
    <script src="<%=request.getContextPath()%>/js/documentDescriptionTypeahead.js"></script>
    <script src="<%=request.getContextPath()%>/share/javascript/oscarMDSIndex.js"></script>
    <script src="<%=request.getContextPath()%>/dms/showDocument.js?ver=1"></script>

<!-- css -->
    <link href="<%=request.getContextPath()%>/css/bootstrap.css" rel="stylesheet" > <!-- Bootstrap 2.3.1 -->
    <link href="<%=request.getContextPath()%>/share/yui/css/fonts-min.css" rel="stylesheet">
    <link href="<%=request.getContextPath()%>/library/jquery/jquery-ui.structure-1.12.1.min.css" rel="stylesheet">
    <link href="<%=request.getContextPath()%>/library/jquery/jquery-ui.theme-1.12.1.min.css" rel="stylesheet">

    <style>
        .multiPage {
        		background-color: RED;
        		color: WHITE;
        		font-weight:bold;
				padding: 0px 5px;
				font-size: medium;
        	}

        .singlePage {

        	}

        #ticklerWrap {
                position:relative;
                top:0px;
                background-color:#FF6600;
                width:100%;
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


    <script>

    function next() {

        if(!window.opener || (typeof window.opener.openNext != 'function')){
            document.getElementById('next_<%=docId%>').style.display="none";
            console.log("not called from inbox so disabling Next");

        } else if (!window.opener.document.getElementById('ack_next_chk').checked) {
            document.getElementById('next_<%=docId%>').style.display="none";
            console.log("check box currently unchecked so disabling Next");
        }

    }

        jQuery.noConflict();

        function renderCalendar(id,inputFieldId){
            Calendar.setup({ inputField : inputFieldId, ifFormat : "%Y-%m-%d", showsTime :false, button : id });

   	   }

        window.forwardDocument = function(docId) {
        	var frm = "#reassignForm_" + docId;
    		var query = jQuery(frm).serialize();

    		jQuery.ajax({
    			type: "POST",
    			url:  "<%= request.getContextPath()%>/oscarMDS/ReportReassign.do",
    			data: query,
    			success: function (data) {
    				window.location.reload();
    			},
    			error: function(jqXHR, err, exception) {
    				alert("Error " + jqXHR.status + " " + err);
    			}
    		});
    	}
        function handleDocSave(docid,action){
			var url=contextpath + "/dms/inboxManage.do";
			var data='method=isDocumentLinkedToDemographic&docId='+docid;
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
			                if(demoid!=null && demoid.length>0) {
                        switch(String(action)) {
                            case "msgLab":
                                popupStart(900,1280,contextpath + '/oscarMessenger/SendDemoMessage.do?demographic_no='+demoid,'msg', '<%=docId%>');
                                break;
                            case "addTickler":
                                popupStart(450,600,contextpath + '/tickler/ForwardDemographicTickler.do?docType=DOC&docId='+docid+'&demographic_no='+demoid,'tickler');
                                break;
                            case "msgLabRecall":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarMessenger/SendDemoMessage.do?demographic_no='+demoid+"&recall",'msgRecall');
                                window.popup(450,600,'<%=request.getContextPath()%>/tickler/ForwardDemographicTickler.do?docType=DOC&docId=<%=docId%>&demographic_no='+demoid+'<%=ticklerAssignee%>&priority=<%=recallTicklerPriority%>&recall','ticklerRecall');
                                break;
                            case "msgLabMAM":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=MAM','prevention');
                            <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                window.popup(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no='+demoid+'&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q131A','billing');
                            <% } %>
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgLabPAP":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=PAP','prevention');
                            <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                window.popup(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no='+demoid+'&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q011A','billing');
                            <% } %>
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgLabFIT":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=FOBT','prevention');
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgLabCOLONOSCOPY":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=COLONOSCOPY','prevention');
                            <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                window.popup(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no='+demoid+'&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q142A','billing');
                            <% } %>
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgLabBMD":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=BMD','prevention');
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgLabPSA":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?demographic_no='+demoid+'&prevention=PSA','prevention');
                                window.popup(450,1280,'<%=request.getContextPath()%>/tickler/ticklerDemoMain.jsp?demoview='+demoid);
                                break;
                            case "msgInf":
                                window.popup(700,980,'<%=request.getContextPath()%>/oscarPrevention/AddPreventionData.jsp?search=true&demographic_no='+demoid+'&snomedId=46233009&brandSnomedId=46233009','prevention');
                            <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                window.popup(700,1280,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no='+demoid+'&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&serviceCode0=Q130A','billing');
                            <% } %>
                                break;
                            default:
                                console.log('default');
                                break;
                        }
                    }

                    } else {
                        alert("<bean:message key="oscarMDS.index.msgNotAttached"/>");
                    }
                    }
                }});
        }


        function rotate90(id) {
        	jQuery("#rotate90btn_" + id).attr('disabled', 'disabled');
            var url = contextpath + "/dms/SplitDocument.do";
            var data = "method=rotate90&document=" + id;
	        jQuery.ajax({
		        type: "POST",
		        url:  url,
		        data: data,
		        success: function (data) {
		            jQuery("#rotate90btn_" + id).removeAttr('disabled');
                    if(document.getElementById('displayDocumentAs_<%=docId%>').value=="PDF") {
                        showPDF(id,contextpath);
                    } else {
                        jQuery("#docImg_" + id).attr('src', contextpath + "/dms/ManageDocument.do?method=viewDocPage&doc_no=" + id + "&curPage=1&rand=" + (new Date().getTime()));
                    }
            	},
		        error: function(jqXHR, err, exception) {
			        console.log(jqXHR.status);
		        }
	        });

        }


        function split(id,demoName) {
        	var loc = "<%= request.getContextPath()%>/oscarMDS/Split.jsp?document=" + id + "&queueID=<%=inQueue%>" + "&demoName=" + demoName;
        	popupStart(1400, 1400, loc, "Splitter");
        }

        var _in_window = <%=( "true".equals(request.getParameter("inWindow")) ? "true" : "false" )%>;
        var contextpath = "<%=request.getContextPath()%>";



        </script>


        		<script>
			//first check to see if lab is linked, if it is, we can send the demographicNo to the macro
			function runMacro(name,formid, closeOnSuccess) {
				var num=formid.split("_");
				var doclabid=num[1];
				if(doclabid){
					var demoId=document.getElementById('demofind'+doclabid).value;
					var saved=document.getElementById('saved'+doclabid).value;
					if(demoId=='-1'|| saved=='false'){
						alert('<bean:message key="oscarMDS.index.msgNotAttached"/>');
					}else{
						runMacroInternal(name,formid,closeOnSuccess,demoId);
					}
				}
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
</head>
<body onLoad="next();">
<div id='loader' style="display:none"><img src='<%=request.getContextPath()%>/images/DMSLoader.gif' alt="loading"> <bean:message key="caseload.msgLoading"/></div>
<% } else { %>
    <script>
        document.getElementById('next_<%=docId%>').style.display="none";
        console.log("In Preview Mode so disabling Next");
        var _in_window = false;
    </script>
<% } %>
        <div id="labdoc_<%=docId%>">
        	<%
        	 ArrayList ackList = AcknowledgementData.getAcknowledgements("DOC",docId);
        	 ReportStatus reportStatus = null;
        	 String docCommentTxt = "";
        	 String rptStatus = "";
        	 boolean ackedOrFiled = false;
        	 for( int idx = 0; idx < ackList.size(); ++idx ) {
        	     reportStatus = (ReportStatus) ackList.get(idx);

        	     if( reportStatus.getOscarProviderNo() != null && reportStatus.getOscarProviderNo().equals(providerNo) ) {
        		 	docCommentTxt = reportStatus.getComment();
        		 	if( docCommentTxt == null ) {
        		 	    docCommentTxt = "";
        		 	}

        		 	rptStatus = reportStatus.getStatus();

        		 	if( rptStatus != null ) {
        		 		ackedOrFiled = rptStatus.equalsIgnoreCase("A") ? true : rptStatus.equalsIgnoreCase("F") ? true : false;
        		 	}
        		 	break;
        	     }
        	 }
        	%>
        	<form name="acknowledgeForm_<%=docId%>" id="acknowledgeForm_<%=docId%>" onsubmit="<%=ackFunc%>" method="post" action="javascript:void(0);">

                                                        <input type="hidden" name="segmentID" value="<%= docId%>">
                                                        <input type="hidden" name="multiID" value="<%= docId%>" >
                                                        <input type="hidden" name="providerNo" value="<%= providerNo%>">
                                                        <input type="hidden" name="status" value="A" id="status_<%=docId%>">
                                                        <input type="hidden" name="labType" value="DOC">
                                                        <input type="hidden" name="ajaxcall" value="yes">
                                                        <input type="hidden" name="comment" id="comment_<%=docId%>" value="<%=docCommentTxt%>">
                                                    <% if (demographicID != null && !demographicID.equals("") && !demographicID.equalsIgnoreCase("null") && !ackedOrFiled ) {%>


                                                    									<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {

									%>
											<div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key='global.macro'/>&nbsp;<span class="caret"></span></button>
											  <div class="dropdowns-content">
											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runMacro('<%=name%>','acknowledgeForm_<%=docId%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									<% } %>

                                                        <input type="submit" id="ackBtn_<%=docId%>" class="btn  btn-primary" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>">

                                                        <input type="button" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" class="btn" onclick="addDocComment('<%=docId%>','<%=providerNo%>',true)" >

                                                        <input type="button" id="fwdBtn_<%=docId%>" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(355, 685, '../oscarMDS/SelectProvider.jsp?docId=<%=docId%>', 'providerselect');">
                                                        <%if (MyOscarUtils.isMyOscarEnabled((String) session.getAttribute("user"))){
															MyOscarLoggedInInfo myOscarLoggedInInfo=MyOscarLoggedInInfo.getLoggedInInfo(session);
															boolean enabledMyOscarButton=MyOscarUtils.isMyOscarSendButtonEnabled(myOscarLoggedInInfo, Integer.valueOf(demographicID));
														%>
														<input type="button" class="btn" <%=WebUtils.getDisabledString(enabledMyOscarButton)%> value="<bean:message key="global.btnSendToPHR"/>" onclick="popup(450, 600, '../phr/SendToPhrPreview.jsp?module=document&documentNo=<%=docId%>&demographic_no=<%=demographicID%>', 'sendtophr')">
                                                        <%}%>
                                                    <%}%>


                                                        <%
                                                        boolean isLinkedToDemographic = false;
                                                        String btnDisabled = "disabled";
                                                        if (demographicID != null && !demographicID.equals("") && !demographicID.equalsIgnoreCase("null") && !demographicID.equals("-1") ) {
                                                        	btnDisabled = "";
                                                            isLinkedToDemographic = true;
                                                        }

                                                        %>
                                                        <!-- <input type="button" id="closeBtn_<%=docId%>" class="btn" value=" <bean:message key="global.btnClose"/> " onClick="window.close()"> -->
                                                        <input type="button" id="msgBtn_<%=docId%>" class="btn" value="<bean:message key="caseload.msgMsg"/>" onClick="handleDocSave('<%=docId%>','msgLab');return false;" <%=btnDisabled %> >

                                                <%
                                                if(org.oscarehr.common.IsPropertiesOn.isTicklerPlusEnable()) {
                                                %>
                                                        <input type="button" id="ticklerBtn_<%=docId%>" class="btn" value="<bean:message key="ticklerplus.header.title"/>" onclick="popupPatientTicklerPlus(710, 1024,'<%=request.getContextPath()%>/Tickler.do?', 'Tickler','<%=docId%>')" <%=btnDisabled %>>
                                                <% } else { %>
                                                        <input type="button" id="ticklerBtn_<%=docId%>" class="btn" value="<bean:message key="global.tickler"/>" onclick="handleDocSave('<%=docId%>','addTickler');return false;" <%=btnDisabled %> >
                                                <% } %>
                                                <% if(recall){%>
                                                        <input type="button" id="recallBtn_<%=docId%>" class="btn" value="<bean:message key='oscarMDS.index.Recall'/>" onclick="handleDocSave('<%=docId%>','msgLabRecall'); return false;" <%=btnDisabled %>>
                                                <% } %>

                                                <div class="dropdowns" id="dropdown_<%=docId%>">
                                                    <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret"></span></button>
                                                    <div class="dropdowns-content">
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabFIT'); return false;">FIT</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabBMD'); return false;">BMD</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabPSA'); return false;">PSA</a>
                                                <% if(!StringUtils.isEmpty(CanadianVaccineCatalogueManager2.getCVCURL())) { %>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgInf'); return false;">[Inf] Influenza</a>
                                                <% } %>
                                                <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;margin: 1px;"></a>
                                                <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupPatient(710, 1024,'<%=request.getContextPath()%>/oscarEncounter/IncomingEncounter.do?reason=' + getDocumentType() + '&curDate=<%=currentDate%>>&appointmentNo=&appointmentDate=&startTime=&status=&demographicNo=', 'encounter', '<%=docId%>', <%=openInTabs%>); return false;" <%=btnDisabled %>><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                                <% } %>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupPatient(800,1280,'<%=request.getContextPath()%>/demographic/demographiccontrol.jsp?displaymode=edit&dboperation=search_detail&demographic_no=','master','<%=docId%>',<%=openInTabs%>); return false;" <%=btnDisabled %>><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupPatientRx(1024,500,'<%=request.getContextPath()%>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=','Rx<%=demographicID%>', '<%=docId%>', true); return false;" <%=btnDisabled %>><bean:message key="global.prescriptions"/></a>

                                           <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupPatient(710,1024,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing','<%=docId%>',<%=openInTabs%>);return false;"><bean:message key="global.billingtag"/></a>
                                            <% } %>
                                                <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;margin: 1px;"></a>
                                                        <a href="javascript:void(0);" onClick="popup(700,960,'<%=url2%>','file download')"><bean:message key="global.btnPDF"/></a>
                                            <%if( !ackedOrFiled ) { %>
                                                        <a href="javascript:void(0);" onClick="fileDoc('<%=docId%>');"><bean:message key="oscarMDS.index.btnFile"/></a>

                                            <% } %>
                                                    </div>
                                                </div>

                                                        <input type="button" id="rxBtn_<%=docId%>" class="btn" value="<bean:message key="global.rx"/>" onclick="popupPatientRx(1024,500,'<%=request.getContextPath()%>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=','Rx<%=demographicID%>', '<%=docId%>', true); return false;" <%=btnDisabled %>>
                                                        <input type="button" id="refileDoc_<%=docId%>" class="btn" value="<bean:message key="oscarEncounter.noteBrowser.msgRefile"/>" onclick="
popup2(710,1024,0,0,'<%=request.getContextPath()%>/dms/incomingDocs.jsp?pdfDir=Refile', 'Refile<%=docId%>');refileDoc('<%=docId%>');return(false);">
                                                        <select  id="queueList_<%=docId%>" name="queueList" style="width:100px;">
                                                            <%
                                                            for (Hashtable ht : queues) {
                                                                int id = (Integer) ht.get("id");
                                                                String qName = (String) ht.get("queue");
                                                            %>
                                                            <option value="<%=id%>" <%=((id == queueId) ? " selected" : "")%>><%= qName%> </option>
                                                            <%}%>
                                                        </select>
                            </form>
            <table class="docTable">
                <tr>


                    <td style="vertical-align:top;">
                        <div style="text-align: right;font-weight: bold">
                        <% if( numOfPage > 1 && displayDocumentAs.equals(UserProperty.IMAGE) ) {%>
                        	<a id="firstP_<%=docId%>" style="display: none;" href="javascript:void(0);" onclick="firstPage('<%=docId%>','<%=cp%>');"><bean:message key='global.First'/></a>
                            <a id="prevP_<%=docId%>" style="display: none;"  href="javascript:void(0);" onclick="prevPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Prev'/></a>
                            <a id="nextP_<%=docId%>" href="javascript:void(0);" onclick="nextPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Next'/></a>
                            <a id="lastP_<%=docId%>" href="javascript:void(0);" onclick="lastPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Last'/></a>
                            <%} %>
                        </div>
                        <% if (displayDocumentAs.equals(UserProperty.IMAGE)) { %>
                            <a href="<%=url2%>" target="_blank"><img alt="document" id="docImg_<%=docId%>"  src="<%=url%>" ></a>
                        <%} else {%>
                            <div id="docDispPDF_<%=docId%>"></div>
                        <%}%>
                    </td>

                    <td style="vertical-align:top; text-align:left">
                        <fieldset><legend><bean:message key="inboxmanager.document.PatientMsg"/><span id="assignedPId_<%=docId%>">
                                <%=demoName%></span> </legend>
                            <table style="border-width:0px;">
                                <tr>
                                    <td><bean:message key="inboxmanager.document.DocumentUploaded"/></td>
                                    <td><%=curdoc.getDateTimeStamp()%></td>
                                </tr>
                                <tr>
                                    <td><bean:message key="inboxmanager.document.ContentType"/></td>
                                    <td><%=contentType%></td>
                                </tr>
                                <tr>
                                    <td><bean:message key="inboxmanager.document.NumberOfPages"/></td>
                                    <td>
                                    	<input id="shownPage_<%=docId %>" type="hidden" value="1" >
                                        <%if (displayDocumentAs.equals(UserProperty.IMAGE)) { %>
                                            <span id="viewedPage_<%=docId%>" class="<%= numOfPage > 1 ? "multiPage" : "singlePage" %>">1</span>&nbsp; <bean:message key="global.of"/> &nbsp;<%}%>
                                        <span id="numPages_<%=docId %>" class="<%= numOfPage > 1 ? "multiPage" : "singlePage" %>"><%=numOfPageStr%></span>
                                    </td>
                                </tr>
                                <tr>
                                        <td><bean:message key="dms.documentReport.msgCreator"/>:</td>
                                        <td><%=curdoc.getCreatorName()%></td>
                                </tr>
                                <tr><td></td>
                                    <td>
                                        <% boolean updatableContent=true; %>
                                        <oscar:oscarPropertiesCheck property="ALLOW_UPDATE_DOCUMENT_CONTENT" value="false" defaultVal="false">
                                            <%
                                                if(!demographicID.equals("-1")) { updatableContent=false; }
                                            %>
                                        </oscar:oscarPropertiesCheck>
                                        <div style="<%=updatableContent==true?"":"visibility: hidden"%>">
                                            <input onclick="split('<%=docId%>','<%=StringEscapeUtils.escapeJavaScript(demoName) %>')" type="button" class="btn" value="<bean:message key="inboxmanager.document.split" />" >
                                            <input id="rotate180btn_<%=docId %>" onclick="rotate180('<%=docId %>')" type="button" class="btn" value="<bean:message key="inboxmanager.document.rotate180" />" >
                                            <input id="rotate90btn_<%=docId %>" onclick="rotate90('<%=docId %>')" type="button" class="btn" value="<bean:message key="inboxmanager.document.rotate90" />" >
                                            <% if (numOfPage > 1) { %><input id="removeFirstPagebtn_<%=docId %>" onclick="removeFirstPage('<%=docId %>')" type="button"  class="btn" value="<bean:message key="inboxmanager.document.removeFirstPage" />" ><% } %>
                                        </div>
                                    </td>
                                </tr>

                            </table>

                            <form id="forms_<%=docId%>" onsubmit="return updateDocument('forms_<%=docId%>');">
                                <input type="hidden" name="method" value="documentUpdateAjax" >
                                <input type="hidden" name="documentId" value="<%=docId%>" >
                                <input type="hidden" name="curPage_<%=docId%>" id="curPage_<%=docId%>" value="1">
                                <input type="hidden" name="totalPage_<%=docId%>" id="totalPage_<%=docId%>" value="<%=numOfPage%>">
                                <input type="hidden" name="displayDocumentAs_<%=docId%>" id="displayDocumentAs_<%=docId%>" value="<%=displayDocumentAs%>">
                                <table style="border-width:0px;">
                                    <tr>
                                        <td><bean:message key="dms.documentReport.msgDocType" />:</td>
                                        <td>
                                            <select name ="docType" id="docType_<%=docId%>">
                                                <option value=""><bean:message key="dms.addDocument.formSelect" /></option>
                                                <%for (int j = 0; j < doctypes.size(); j++) {
                String doctype = (String) doctypes.get(j);%>
                                                <option value="<%= doctype%>" <%=(curdoc.getType().equals(doctype)) ? " selected" : ""%>><%= doctype%></option>
                                                <%}%>
                                            </select>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><bean:message key="dms.documentReport.msgDocDesc"/>:</td>
                                        <td>
                                            <input id="docDesc_<%=docId%>" type="text" name="documentDescription" value="<%=curdoc.getDescription()%>" >
                                            <div id="docDescTypeahead_<%=docId%>" class="autocomplete"></div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><bean:message key="inboxmanager.document.ObservationDateMsg"/></td>
                                        <td class="input-append" id="cal" onmouseover="renderCalendar(this.id,'observationDate<%=docId%>' );">
                                            <input id="observationDate<%=docId%>" name="observationDate" style="width:90px;" type="text" value="<%=curdoc.getObservationDate()%>" pattern="^\d{4}(-|/)((0\d)|(1[012]))(-|/)(([012]\d)|3[01])$" autocomplete="off">
                                            <span class="add-on"><i class="icon-calendar"></i></span>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td><bean:message key="inboxmanager.document.DemographicMsg"/></td>
                                        <td style="width:400px;"><%
                                        if(!demographicID.equals("-1")){%>
                                            <input id="saved<%=docId%>" type="hidden" name="saved" value="true">
                                            <input type="hidden" value="<%=demographicID%>" name="demog" id="demofind<%=docId%>" >
                                            <input type="hidden" name="demofindName" value="<%=demoName%>" id="demofindName<%=docId%>">
                                            <% if (btnDisabled.equals("disabled")) {%>
                                                <%=demoName%>
                                            <% } else { %>
                                                <a href="javascript:void(0);" onClick="popupPatient(710, 1024,'<%=request.getContextPath()%>/oscarEncounter/IncomingEncounter.do?reason=<bean:message key="oscarMDS.segmentDisplay.labResults"/>&curDate=<%=currentDate%>>&appointmentNo=&appointmentDate=&startTime=&status=&demographicNo=', 'encounter', '<%=docId%>', <%=openInTabs%>); return false;" ><%=demoName%></a>
                                            <% } %>
                                        <%}else{%>
                                            <input id="saved<%=docId%>" type="hidden" name="saved" value="false">
                                            <input type="hidden" name="demog" value="<%=demographicID%>" id="demofind<%=docId%>">
                                            <input type="hidden" name="demofindName" value="<%=demoName%>" id="demofindName<%=docId%>">

                                            <input type="checkbox" id="activeOnly<%=docId%>" name="activeOnly" checked="checked" value="true" onclick="setupDemoAutoCompletion(<%=docId%>)">Active Only<br>
                                            <input type="text" id="autocompletedemo<%=docId%>" onchange="checkSave('<%=docId%>');" name="demographicKeyword" />
                                            <div id="autocomplete_choices<%=docId%>" class="autocomplete"></div>
											<input type="button" id="createNewDemo" value="<bean:message key="inboxmanager.document.CreateNewDemographic" />"  class="btn" onclick="popup(700,960,'<%=request.getContextPath()%>/demographic/demographicaddarecordhtm.jsp','demographic')" >
                                            <%}%>
                                                   <input id="saved_<%=docId%>" type="hidden" name="saved" value="false">
                                                   <br><input id="mrp_<%=docId%>" style="display: none;" type="checkbox" onclick="sendMRP(this)"  name="demoLink" >
                                                   <a id="mrp_fail_<%=docId%>" style="color:red;font-style: italic; display: none;" ><bean:message key="inboxmanager.document.SendToMRPFailedMsg"/></a>
                                        </td>
                                    </tr>

                                    <tr>
                                        <td style="vertical-align:top"><bean:message key="inboxmanager.document.FlagProviderMsg"/> </td>
                                        <td>
                                            <input type="hidden" name="provi" id="provfind<%=docId%>" >
                                            <input type="text" id="autocompleteprov<%=docId%>" name="demographicKeyword">
                                            <div id="autocomplete_choicesprov<%=docId%>" class="autocomplete"></div>


                                            <div id="providerList<%=docId%>"></div>
                                        </td>
                                    </tr>
				    <tr>
                                        <td>
                                             <bean:message key="inboxmanager.document.FlagAbnormalMsg" />
                                        </td>
                                        <td>
                                             <input id="abnormal<%=docId%>" type="checkbox" name="abnormalFlag" <%= curdoc.isAbnormal() ? "checked='checked'" : "" %> >
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="1" style="width: 30%; text-align:left"><a id="saveSucessMsg_<%=docId%>" style="display:none;color:blue;"><bean:message key="inboxmanager.document.SuccessfullySavedMsg"/></a></td>
                                        <td colspan="1" style="width: 30%; text-align:left">
<%if(demographicID.equals("-1")){%>
    <input type="submit" class="btn" name="save" disabled id="save<%=docId%>" value="<bean:message key="global.btnSave"/>" title="<bean:message key="dms.incomingDocs.selectDemographicFirst"/>">
<!--<input type="button" class="btn" name="save" id="saveNext<%=docId%>" onclick="saveNext(<%=docId%>)" disabled value='<bean:message key="inboxmanager.document.SaveAndNext"/>' >-->
<%}
            else{%>
<input type="submit" class="btn" name="save" id="save<%=docId%>" value="<bean:message key="global.btnSave"/>" >
<!--<input type="button" class="btn" name="save" onclick="saveNext(<%=docId%>)" id="saveNext<%=docId%>" value='<bean:message key="inboxmanager.document.SaveAndNext"/>' > -->
<%}%>

                                    </tr>

                                    <tr>
                                        <td colspan="2">
                                            <bean:message key="inboxmanager.document.LinkedProvidersMsg"/>
                                            <%
            Properties p = (Properties) session.getAttribute("providerBean");
            List<ProviderInboxItem> routeList = providerInboxRoutingDao.getProvidersWithRoutingForDocument("DOC", Integer.parseInt(docId));
            int countValidProvider = 0;
                                            %>
                                            <ul>
                                                <%for (ProviderInboxItem pItem : routeList) {
                                                    String s=p.getProperty(pItem.getProviderNo(), pItem.getProviderNo());

                                                    if(!s.equals("0")&&!s.equals("null")&& !pItem.getStatus().equals("X")){  %>
                                                        <li><%=s%><a href="javascript:void(0);" onclick="removeLink('DOC', '<%=docId %>', '<%=pItem.getProviderNo() %>', this);return false;"><bean:message key="inboxmanager.document.RemoveLinkedProviderMsg" /></a></li>
                                                <%countValidProvider++;}
                                                }%>
                                            </ul>
                                        </td>
                                    </tr>
                                </table>

                            </form>
                        </fieldset>

<% if(demographicID!=null && !demographicID.equals("")){

							    TicklerManager ticklerManager = SpringUtils.getBean(TicklerManager.class);
							    List<Tickler> LabTicklers = ticklerManager.getTicklerByLabId(loggedInInfo, Integer.valueOf(documentNo), Integer.valueOf(demographicID),"DOC");

							    if(LabTicklers!=null && LabTicklers.size()>0){
							    %>
							    <div id="ticklerWrap" class="DoNotPrint">
							    <h4 style="color:#fff; text-align:center;"><a href="javascript:void(0)" id="open-ticklers" onclick="showHideItem('ticklerDisplay')">View Ticklers</a> Linked to this Lab</h4>

							           <div id="ticklerDisplay" style="display:none">
							   <%
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
							   <div style="margin:auto; background-color:#fff; padding:5px; width:500px;" class="<%=ticklerClass%>">
							   	<table width="100%">
							   	<tr>
							   	<td><b><bean:message key="tickler.ticklerEdit.priority"/>:</b><br><%=flag%> <%=tickler.getPriority()%></td>
							   	<td><b><bean:message key="tickler.ticklerEdit.serviceDate"/>:</b><br><%=tickler.getServiceDate()%></td>
							   	<td><b><bean:message key="tickler.ticklerEdit.assignedTo"/>:</b><br><%=tickler.getAssignee() != null ? tickler.getAssignee().getLastName() + ", " + tickler.getAssignee().getFirstName() : "N/A"%></td>
							   	<td width="90px"><b><bean:message key="tickler.ticklerEdit.status"/>:</b><br><%=ticklerStatus.equals("C") ? "Completed" : "Active" %></td>
							   	</tr>
							   	<tr>
							   	<td colspan="4"><%=tickler.getMessage()%></td>
							   	</tr>
							   	</table>
							   </div>
							   <br>
							   <%
							   }
							   %>
							   		</div><!-- end ticklerDisplay -->
							   </div>
							   <%}//no ticklers to display

}%>
                            <%

                                            if (ackList.size() > 0){%>
                                            <fieldset>
                                                <table style="width:100%; border-width:2px;">
                                                    <tr>
                                                            <td style="text-align:center; background-color:white">
                                                            <div class="FieldData">
                                                                <!--center-->
                                                                    <% for (int i=0; i < ackList.size(); i++) {
                                                                        ReportStatus report = (ReportStatus) ackList.get(i); %>
                                                                        <%= report.getProviderName() %> :

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
                                                                            <span id="timestamp_<%=docId + "_" + report.getOscarProviderNo()%>"><%= report.getTimestamp() == null ? "&nbsp;" : report.getTimestamp() + "&nbsp;"%></span>
                                                                            <%=com%>: <span id="comment_<%=docId + "_" + report.getOscarProviderNo()%>"><%=report.getComment() == null || report.getComment().equals("") ?  nocom : report.getComment()%></span>

                                                                        <br>
                                                                    <% }
                                                                    if (ackList.size() == 0){
                                                                        %><span style="color:red"><bean:message key="oscarEncounter.oscarConsultationRequest.ViewConsultationRequests.formTeamNotApplicable"/></span><%
                                                                    }
                                                                    %>
                                                                <!--/center-->
                                                            </div>
                                                        </td>
                                                    </tr>
                                                </table>
                                            </fieldset>
                                            <%}

%>

                        <fieldset>
                          <%--  <input id="test1Regex_<%=docId%>" type="text"/><input id="test2Regex_<%=docId%>" type="text"/>
                            <a href="javascript:void(0);" onclick="testShowDoc();">click</a>--%>
                            <legend><span class="FieldData"><i><bean:message key="inboxmanager.document.NextAppointmentMsg"/> <oscar:nextAppt demographicNo="<%=demographicID%>"/></i></span></legend>
                            <%
                                int iPageSize = 5;
                                Provider prov;
                                boolean HighlightUserAppt = false;
                                if (!demographicID.equals("-1")) {

                                    List<Appointment> appointmentList = appointmentDao.getAppointmentHistory(Integer.parseInt(demographicID), 0, iPageSize);
                                    if (appointmentList != null && appointmentList.size() > 0) {
                            %>

                            <table style="text-align:center; vertical-align:top; background-color:#c0c0c0;">
                                <tr style="background-color:#ccccff">
                                    <th colspan="4"><bean:message key="appointment.addappointment.msgOverview" /></th>
                                </tr>
                                <tr style="background-color:#ccccff">
                                    <th><bean:message key="Appointment.formDate" /></th>
                                    <th><bean:message key="Appointment.formStartTime" /></th>
                                    <th><bean:message key="appointment.addappointment.msgProvider" /></th>
                                    <th><bean:message key="appointment.addappointment.msgComments" /></th>
                                </tr>
                                <%
                                    for (Appointment a : appointmentList) {
                                        prov = providerDao.getProvider(a.getProviderNo());
                                        HighlightUserAppt = false;
                                        if (creator.equals(a.getProviderNo())) {
                                            HighlightUserAppt = true;
                                        }
                                %>
                                <tr style="background-color:<%=HighlightUserAppt == false ? "#FFFFFF" : "#CCFFCC"%>">
                                    <td ><%=ConversionUtils.toDateString(a.getAppointmentDate())%></td>
                                    <td ><%=ConversionUtils.toTimeString(a.getStartTime())%></td>
                                    <td ><%=prov == null ? "N/A" : prov.getFormattedName()%></td>
                                    <td ><% if (a.getStatus() == null) {%>"" <% } else if (a.getStatus().equals("N")) {%><bean:message key="oscar.appt.ApptStatusData.msgNoShow" /><% } else if (a.getStatus().equals("C")) {%><bean:message key="oscar.appt.ApptStatusData.msgCanceled" /> <%}%>
                                    </td>
                                </tr>
                                <%}%>
                            </table>
<input type="button" id="mainApptHistory_<%=docId%>" class="btn btn-link" value=" <bean:message key="oscarMDS.segmentDisplay.btnApptHist"/>" onClick="popupPatient(710,1024,'<%=request.getContextPath()%>/demographic/demographiccontrol.jsp?orderby=appttime&displaymode=appt_history&dboperation=appt_history&limit1=0&limit2=25&demographic_no=','ApptHist','<%=docId%>')" <%=btnDisabled %>>
                            <%}
                                    }%>
                            <form name="reassignForm_<%=docId%>" id="reassignForm_<%=docId%>">
                                <input type="hidden" name="flaggedLabs" value="<%= docId%>" >
                                <input type="hidden" name="selectedProviders" value="" >
                                <input type="hidden" name="labType" value="DOC" >
                                <input type="hidden" name="labType<%= docId%>DOC" value="imNotNull" >
                                <input type="hidden" name="providerNo" value="<%= providerNo%>" >
                                <input type="hidden" name="favorites" value="" >
                                <input type="hidden" name="ajax" value="yes" >
                            </form>
                         </fieldset>
<% if (request.getParameter("inWindow") != null && request.getParameter("inWindow").equalsIgnoreCase("true")) {  %>
                        <% if (!oscar.util.StringUtils.isNullOrEmpty(demographicID) && !oscar.util.StringUtils.isNullOrEmpty(curdoc.getDescription()) && countValidProvider!=0){ %>
                        <fieldset>
                            <legend><bean:message key="dms.incomingDocs.fax"/></legend>
                            <script>
                                jQuery.noConflict();
                                function faxDocument(docId){

                                    var faxRecipients = "";
                                    if(document.getElementById("faxRecipients").children.length <= 0){
                                        alert("Please select at least one Fax Recipient");
                                        return false;

                                    }else{
                                        for(var i=0; i<document.getElementById("faxRecipients").children.length; i++){
                                            faxRecipients += document.getElementsByName('faxRecipients')[i].value + ",";
                                        }
                                        document.getElementsByName('faxRecipients').length
                                    }

                                    jQuery.ajax({
                                        type: "POST",
                                        url: "<%=request.getContextPath() %>/dms/ManageDocument.do",
                                        data: "method=fax&docId=" + docId + "&faxRecipients=" + faxRecipients + "&demoNo=<%=demographicID%>&docType=DOC",
                                        success: function(data) {
                                            if (data != null)
                                                location.reload();
                                        }
                                    });
                                }
                            </script>
                            <form name="faxForm_<%=docId%>" id="faxForm_<%=docId%>" onsubmit="" method="post" action="javascript:void(0);">
                                <table style="border-width:0px">
                                    <tbody>
                                    <tr>
                                        <td>
                                            <bean:message key="Appointment.formDoctor"/>:
                                        </td>
                                        <td>
                                            <select id="otherFaxSelect" style="margin-left: 5px;max-width: 300px;min-width:150px;">
                                                <%
                                                    String rdName = "";
                                                    String rdFaxNo = "";
                                                    for (int i=0;i < displayServiceUtil.specIdVec.size(); i++) {
                                                        String  specId     =  displayServiceUtil.specIdVec.elementAt(i);
                                                        String  fName      =  displayServiceUtil.fNameVec.elementAt(i);
                                                        String  lName      =  displayServiceUtil.lNameVec.elementAt(i);
                                                        String  proLetters =  displayServiceUtil.proLettersVec.elementAt(i);
                                                        String  address    =  displayServiceUtil.addressVec.elementAt(i);
                                                        String  phone      =  displayServiceUtil.phoneVec.elementAt(i);
                                                        String  fax        =  displayServiceUtil.faxVec.elementAt(i);
                                                        String  referralNo = "";
                                                        if (rdohip != null && !"".equals(rdohip) && rdohip.equals(referralNo)) {
                                                            rdName = String.format("%s, %s", lName, fName);
                                                            rdFaxNo = fax;
                                                        }
                                                        if (!"".equals(fax)) {
                                                %>

                                                <option value="<%= fax %>"> <%= String.format("%s, %s", lName, fName) %> </option>
                                                <%
                                                        }
                                                    }
                                                %>

                                            </select>
                                        </td>
                                        <td>
                                            <input type="submit" class="btn" value="<bean:message key="global.btnAdd"/>" onclick="addOtherFaxProvider(); return false;">
                                        </td>
                                    </tr>

                                    <tr>
                                        <td><bean:message key="provider.pref.general.fax"/>:</td>
                                        <td><input type="text" id="otherFaxInput" name="otherFaxInput" style="margin-left: 5px;max-width: 300px;min-width:150px;" value=""></td>
                                        <td>
                                            <input type="submit" class="btn" value="<bean:message key="global.btnAdd"/>" onclick="addOtherFax(); return false;">
                                        </td>
                                    </tr>
                                    </tbody>
                                </table>
                                <div id="faxOps">
                                    <div>

                                        <ul id="faxRecipients">
                                            <%
                                                if (!"".equals(rdName) && !"".equals(rdFaxNo)) {
                                            %>

                                            <input type="hidden" name="faxRecipients" value="<%= rdFaxNo %>" />

                                            <%
                                                }
                                            %>
                                        </ul>
                                    </div>
                                    <div style="margin-top: 5px; text-align: center">
                                        <input type="submit" id="fax_button"  class="btn" onclick="faxDocument('<%=docId%>');" value="<bean:message key="dms.incomingDocs.fax"/>">
                                    </div>
                                </div>
 <%
                            if(session.getAttribute("faxSuccessful")!=null){
                                if((Boolean)session.getAttribute("faxSuccessful")==true){ %><br>
                    <div class="alert alert-success alert-block fade in"><button type="button" class="close" data-dismiss="alert">&times;</button>
      <bean:message key="dms.incomingDocs.fax"/> <bean:message key="oscarMessenger.DisplayMessages.msgStatusSent"/>
    </div>
            <% }
            session.removeAttribute("faxSuccessful");
            }  %>
                            </form>
                        </fieldset>
                        <% } %>
                         <% } %>
                    </td>
                </tr>
                <tr>
                	<td style="vertical-align:top;">
                        <div style="text-align: right;font-weight: bold">
                            <% if( numOfPage > 1 && displayDocumentAs.equals(UserProperty.IMAGE)) {%>
                        	<a id="firstP2_<%=docId%>" style="display: none;" href="javascript:void(0);" onclick="firstPage('<%=docId%>','<%=cp%>');"><bean:message key='global.First'/></a>
                            <a id="prevP2_<%=docId%>" style="display: none;"  href="javascript:void(0);" onclick="prevPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Prev'/></a>
                            <a id="nextP2_<%=docId%>" href="javascript:void(0);" onclick="nextPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Next'/></a>
                            <a id="lastP2_<%=docId%>" href="javascript:void(0);" onclick="lastPage('<%=docId%>','<%=cp%>');"><bean:message key='global.Last'/></a>
                            <%} %>
                        </div>
                    </td>
                	<td>&nbsp;</td>
                </tr>

                <tr><td colspan="2">
<% if ( props.isPropertyActive("SHOW_BOTTOM_LAB_BUTTONS") || (request.getParameter("inWindow") != null && request.getParameter("inWindow").equalsIgnoreCase("true"))) {%>
   <% if (demographicID != null && !demographicID.equals("") && !demographicID.equalsIgnoreCase("null") && !ackedOrFiled ) {%>


									<%
										UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
										UserProperty up = upDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(),UserProperty.LAB_MACRO_JSON);
										if(up != null && !StringUtils.isEmpty(up.getValue())) {

									%>
											<div class="dropdowns">
											  <button class="dropbtns btn"><bean:message key='global.macro'/>&nbsp;<span class="caret" ></span></button>
											  <div class="dropdowns-content">
											  <%
											    try {
												  	JSONArray macros = (JSONArray) JSONSerializer.toJSON(up.getValue());
												  	if(macros != null) {
													  	for(int x=0;x<macros.size();x++) {
													  		JSONObject macro = macros.getJSONObject(x);
													  		String name = macro.getString("name");
													  		boolean closeOnSuccess = macro.has("closeOnSuccess") && macro.getBoolean("closeOnSuccess");

													  		%><a href="javascript:void(0);" onClick="runMacro('<%=name%>','acknowledgeForm_<%=docId%>',<%=closeOnSuccess%>)"><%=name %></a><%
													  	}
												  	}
											    }catch(JSONException e ) {
											    	MiscUtils.getLogger().warn("Invalid JSON for lab macros",e);
											    }
											  %>

											  </div>
											</div>
									<% } %>

                                                        <input type="submit" id="ackBtn2_<%=docId%>" class="btn" value="<bean:message key="oscarMDS.segmentDisplay.btnAcknowledge"/>">

                                                        <input type="button" value="<bean:message key="oscarMDS.segmentDisplay.btnComment"/>" class="btn" onclick="addDocComment('<%=docId%>','<%=providerNo%>',true)">

                                                        <input type="button" id="fwdBtn2_<%=docId%>" class="btn" value="<bean:message key="oscarMDS.index.btnForward"/>" onClick="popupStart(355, 685, '../oscarMDS/SelectProvider.jsp?docId=<%=docId%>', 'providerselect');">

                                                        <%if (MyOscarUtils.isMyOscarEnabled((String) session.getAttribute("user"))){
															MyOscarLoggedInInfo myOscarLoggedInInfo=MyOscarLoggedInInfo.getLoggedInInfo(session);
															boolean enabledMyOscarButton=MyOscarUtils.isMyOscarSendButtonEnabled(myOscarLoggedInInfo, Integer.valueOf(demographicID));
														%>
														<input type="button" class="btn" <%=WebUtils.getDisabledString(enabledMyOscarButton)%> value="<bean:message key="global.btnSendToPHR"/>" onclick="popup(450, 600, '../phr/SendToPhrPreview.jsp?module=document&documentNo=<%=docId%>&demographic_no=<%=demographicID%>', 'sendtophr')">
                                                        <%}%>
                                                    <%}%>

                                                        <!--<input type="button" id="closeBtn2_<%=docId%>" class="btn" value=" <bean:message key="global.btnClose"/> " onClick="window.close()"> -->
                                                        <input type="button" id="msgBtn2_<%=docId%>" class="btn" value="<bean:message key="caseload.msgMsg"/>" onClick="handleDocSave('<%=docId%>','msgLab');return false;" <%=btnDisabled %> >

                                                <%
                                                if(org.oscarehr.common.IsPropertiesOn.isTicklerPlusEnable()) {
                                                %>
                                                        <input type="button" id="ticklerBtn2_<%=docId%>" class="btn" value="<bean:message key="ticklerplus.header.title"/>" onclick="popupPatientTicklerPlus(710, 1024,'<%=request.getContextPath()%>/Tickler.do?', 'Tickler','<%=docId%>')" <%=btnDisabled %>>
                                                <% } else { %>
                                                        <input type="button" id="ticklerBtn2_<%=docId%>" class="btn" value="<bean:message key="global.tickler"/>" onclick="handleDocSave('<%=docId%>','addTickler');return false;" <%=btnDisabled %> >
                                                <% } %>
                                                <% if(recall){%>
                                                        <input type="button" id="recallBtn2_<%=docId%>" class="btn" value="<bean:message key='oscarMDS.index.Recall'/>" onclick="handleDocSave('<%=docId%>','msgLabRecall'); return false;" <%=btnDisabled %>>
                                                <% } %>

                                                <div class="dropdowns" id="dropdown2_<%=docId%>">
                                                    <button class="dropbtns btn"  ><bean:message key="global.other"/>&nbsp;<span class="caret"></span></button>
                                                    <div class="dropdowns-content">
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabMAM'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formMammogram"/></a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabPAP'); return false;"><bean:message key="oscarEncounter.formFemaleAnnual.formPapSmear"/></a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabFIT'); return false;">FIT</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabCOLONOSCOPY'); return false;">Colonoscopy</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabBMD'); return false;">BMD</a>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgLabPSA'); return false;">PSA</a>
                                                <% if(!StringUtils.isEmpty(CanadianVaccineCatalogueManager2.getCVCURL())) { %>
                                                        <a href="javascript:void(0);" onclick="handleDocSave('<%=docId%>','msgInf'); return false;">[Inf] Influenza</a>
                                                <% } %>
                                                <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;margin: 1px;"></a>
                                                <% if ( searchProviderNo != null ) { // null if we were called from e-chart%>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupPatient(710, 1024,'<%=request.getContextPath()%>/oscarEncounter/IncomingEncounter.do?reason=' + getDocumentType() + '&curDate=<%=currentDate%>>&appointmentNo=&appointmentDate=&startTime=&status=&demographicNo=', 'encounter', '<%=docId%>', <%=openInTabs%>); return false;" <%=btnDisabled %>><bean:message key="oscarMDS.segmentDisplay.btnEChart"/></a>
                                                <% } %>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onClick="popupPatient(800,1280,'<%=request.getContextPath()%>/demographic/demographiccontrol.jsp?displaymode=edit&dboperation=search_detail&demographic_no=','master','<%=docId%>',<%=openInTabs%>); return false;" <%=btnDisabled %>><bean:message key="oscarMDS.segmentDisplay.btnMaster"/></a>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupPatientRx(1024,500,'<%=request.getContextPath()%>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=','Rx<%=demographicID%>', '<%=docId%>', true); return false;" <%=btnDisabled %>><bean:message key="global.prescriptions"/></a>
                                            <% if (props.getProperty("billregion", "").trim().toUpperCase().equals("ON")) { %>
                                                        <a <%=isLinkedToDemographic ? "" : "class='disabled'" %> href="javascript:void(0);" onclick="popupPatient(710,1024,'<%=request.getContextPath()%>/billing/CA/ON/billingOB.jsp?billRegion=ON&billForm=MFP&hotclick=&appointment_no=0&demographic_name=&status=a&demographic_no=<%=demographicID%>&providerview=<%=curUser_no%>&user_no=<%=curUser_no%>&apptProvider_no=<%=curUser_no%>&appointment_date=&start_time=00:00:00&bNewForm=1&','billing','<%=docId%>',<%=openInTabs%>);return false;"><bean:message key="global.billingtag"/></a>
                                            <% } %>
                                                <a href="javascript:void(0);" class="divider" style="padding: 1px;"><hr style="border: 1px solid #d5d3d3;margin: 1px;"></a>
                                                        <a href="javascript:void(0);" onClick="popup(700,960,'<%=url2%>','file download')"><bean:message key="global.btnPDF"/></a>
                                            <%if( !ackedOrFiled ) { %>
                                                        <a href="javascript:void(0);" onClick="fileDoc('<%=docId%>');"><bean:message key="oscarMDS.index.btnFile"/></a>

                                            <% } %>
                                                    </div>
                                                </div>
                                                        <input type="button" id="rxBtn2_<%=docId%>" class="btn" value="<bean:message key="global.rx"/>" onclick="popupPatientRx(1024,500,'<%=request.getContextPath()%>/oscarRx/choosePatient.do?providerNo=<%= providerNo%>&demographicNo=','Rx<%=demographicID%>', '<%=docId%>', true); return false;" <%=btnDisabled %>>

                                                        <input type="button" id="refileDoc2_<%=docId%>" class="btn" value="<bean:message key="oscarEncounter.noteBrowser.msgRefile"/>" onclick="popup2(710,1024,0,0,'<%=request.getContextPath()%>/dms/incomingDocs.jsp?pdfDir=Refile', 'Refile<%=docId%>');refileDoc('<%=docId%>'); return(false);">

<% } %>
                                                        <input type="button" class="btn" id="next_<%=docId%>" value="<bean:message key='global.Next'/>" onclick="jQuery(':submit').prop('disabled',true); jQuery(':button').prop('disabled',true); jQuery('#loader').show(); close = window.opener.openNext(<%=docId%>); ">


                   </td>
                   <td>&nbsp;</td>
                </tr>
                <tr><td colspan="2" ></td></tr>
            </table>
<% if (request.getParameter("inWindow") == null ) {  %>
<hr style="width:100%; border: 1px solid red">
<% } %>
        </div>
<!--

//-->
<script>

        if(document.getElementById('displayDocumentAs_<%=docId%>').value=="<%=UserProperty.PDF%>") {
            showPDF('<%=docId%>',contextpath);
        }

        var tmp;

        function setupDemoAutoCompletion(docId) {
        	if(jQuery("#autocompletedemo" + docId) ){

        		var url;
                if( jQuery("#activeOnly" + docId).is(":checked") ) {
                	url = "<%=request.getContextPath()%>/demographic/SearchDemographic.do?jqueryJSON=true&activeOnly=" + jQuery("#activeOnly" + docId).val();
                }
                else {
                	url = "<%=request.getContextPath()%>/demographic/SearchDemographic.do?jqueryJSON=true";
                }

	            jQuery( "#autocompletedemo" + docId ).autocomplete({
	              source: url,
	              minLength: 2,

	              focus: function( event, ui ) {
	            	  jQuery( "#autocompletedemo" + docId ).val( ui.item.label );
	                  return false;
	              },
	              select: function(event, ui) {
	            	  jQuery( "#autocompletedemo" + docId ).val(ui.item.label);
	            	  jQuery( "#demofind" + docId).val(ui.item.value);
	            	  jQuery( "#demofindName" + docId ).val(ui.item.formattedName);
	            	  selectedDemos.push(ui.item.label);
	            	  console.log(ui.item.providerNo);
	            	  if( ui.item.providerNo != undefined && ui.item.providerNo != null &&ui.item.providerNo != "" && ui.item.providerNo != "null" ) {
	            		  addDocToList(ui.item.providerNo, ui.item.provider + " (MRP)", docId);
	            	  }

	            	  //enable Save button whenever a selection is made
	                  document.getElementById("save" + docId).removeAttribute('disabled');
                      //enable pid dependent buttons once saved in oscarMDSIndex.js
	                  return false;
	              }
	            });
        	}
          }

	jQuery(document).ready(function() {
        setupDemoAutoCompletion(<%=docId%>);
        setupDocDescriptionTypeahead(<%=docId%>);
	});
        function setupProviderAutoCompletion() {
        	var url = "<%=request.getContextPath()%>/provider/SearchProvider.do?method=labSearch";

        	jQuery( "#autocompleteprov<%=docId%>" ).autocomplete({
	              source: url,
	              minLength: 2,

	              focus: function( event, ui ) {
	            	  jQuery( "#autocompleteprov<%=docId%>" ).val( ui.item.label );
	                  return false;
	              },
	              select: function(event, ui) {
	            	  jQuery( "#autocompleteprov<%=docId%>" ).val("");
	            	  jQuery( "#provfind<%=docId%>").val(ui.item.value);
	            	  addDocToList(ui.item.value, ui.item.label, "<%=docId%>");

	            	  return false;
	              }
	            });
      	}

        jQuery(setupProviderAutoCompletion());


</script>
<% if (request.getParameter("inWindow") != null && request.getParameter("inWindow").equalsIgnoreCase("true")) {  %>
</body>
</html>
<%}%>