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
<!DOCTYPE html>
<%@page import="oscar.OscarProperties"%>
<%@page import="oscar.oscarDemographic.data.*"%>
<%@page import="oscar.oscarPrevention.*"%>

<%@page import="org.oscarehr.managers.CanadianVaccineCatalogueManager2"%>
<%@page import="org.oscarehr.managers.SecurityInfoManager"%>
<%@page import="org.oscarehr.common.model.UserProperty"%>
<%@page import="org.oscarehr.common.dao.UserPropertyDAO"%>
<%@page import="org.oscarehr.common.model.CVCMapping"%>
<%@page import="org.oscarehr.common.dao.CVCMappingDao"%>
<%@page import="org.oscarehr.common.model.DHIRSubmissionLog"%>
<%@page import="org.oscarehr.managers.DHIRSubmissionManager"%>
<%@page import="org.oscarehr.common.model.Consent"%>
<%@page import="org.oscarehr.common.dao.ConsentDao"%>
<%@page import="org.oscarehr.util.LoggedInInfo"%>
<%@page import="org.oscarehr.util.WebUtilsOld"%>
<%@page import="org.oscarehr.myoscar.utils.MyOscarLoggedInInfo"%>
<%@page import="org.oscarehr.phr.util.MyOscarUtils"%>
<%@page	import="org.oscarehr.common.dao.DemographicDao"%>
<%@page	import="org.oscarehr.common.model.Demographic"%>
<%@page import="org.oscarehr.util.SpringUtils"%>
<%@page import="org.oscarehr.util.LocaleUtils"%>
<%@page import="org.oscarehr.util.WebUtils"%>
<%@page import="org.oscarehr.util.MiscUtils"%>
<%@page import="org.oscarehr.managers.PreventionManager"%>

<%@page import="org.apache.commons.lang.StringUtils"%>
<%@page import="org.apache.commons.lang.StringEscapeUtils"%>
<%@page import="org.apache.logging.log4j.Logger"%>
<%@page import="org.owasp.encoder.Encode"%>
<%@page import="java.util.*"%>
<%@page import="java.text.SimpleDateFormat"%>

<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean"%>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html"%>
<%@ taglib uri="/WEB-INF/oscar-tag.tld" prefix="oscar"%>
<%@ taglib uri="/WEB-INF/rewrite-tag.tld" prefix="rewrite"%>
<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
	long startTime = System.nanoTime();
    long endTime = System.nanoTime();
Logger logger = MiscUtils.getLogger();
logger.info("starting loading preventions");

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
<%


	String demographic_no = request.getParameter("demographic_no");
	LoggedInInfo loggedInInfo=LoggedInInfo.getLoggedInInfoFromSession(request);

	LogAction.addLog(loggedInInfo, LogConst.READ, "Preventions", demographic_no, demographic_no, (String)null);

	DHIRSubmissionManager submissionManager = SpringUtils.getBean(DHIRSubmissionManager.class);
	UserPropertyDAO userPropertyDao = SpringUtils.getBean(UserPropertyDAO.class);
	SecurityInfoManager securityInfoManager = SpringUtils.getBean(SecurityInfoManager.class);


  //int demographic_no = Integer.parseInt(request.getParameter("demographic_no"));

  DemographicData demoData = new DemographicData();
  String nameAge = demoData.getNameAgeString(loggedInInfo, demographic_no);
  org.oscarehr.common.model.Demographic demo = demoData.getDemographic(loggedInInfo, demographic_no);
  String hin = demo.getHin()+demo.getVer();
  String mrp = demo.getProviderNo();
  PreventionManager preventionManager = SpringUtils.getBean(PreventionManager.class);

  PreventionDisplayConfig pdc = PreventionDisplayConfig.getInstance();
  ArrayList<HashMap<String,String>> prevList = pdc.getPreventions();

  ArrayList<Map<String,Object>> configSets = pdc.getConfigurationSets();

  Prevention p = PreventionData.getPrevention(loggedInInfo, Integer.valueOf(demographic_no));
logger.info("prevention object created");
  Integer demographicId=Integer.parseInt(demographic_no);
	String billRegion = OscarProperties.getInstance().getProperty("billregion", "ON").trim().toUpperCase();
    boolean bComment = OscarProperties.getInstance().getBooleanProperty("prevention_show_comments","yes");
    boolean bShowAll = OscarProperties.getInstance().getBooleanProperty("showAllPreventions","yes");
    boolean bIntegrator = loggedInInfo.getCurrentFacility().isIntegratorEnabled();

  if (bIntegrator){PreventionData.addRemotePreventions(loggedInInfo, p, demographicId);}
  Date demographicDateOfBirth=PreventionData.getDemographicDateOfBirth(loggedInInfo, Integer.valueOf(demographic_no));
  String demographicDob = oscar.util.UtilDateUtilities.DateToString(demographicDateOfBirth);

  //PreventionDS pf = SpringUtils.getBean(PreventionDS.class);

  CVCMappingDao cvcMappingDao = SpringUtils.getBean(CVCMappingDao.class);

  SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyy-MM-dd");
  String todayString = simpleDateFormat.format(Calendar.getInstance().getTime());

  boolean printError = request.getAttribute("printError") != null;

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

	UserProperty ssoWarningUp = userPropertyDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(), UserProperty.PREVENTION_SSO_WARNING);
	boolean hideSSOWarning = ssoWarningUp != null && "true".equals(ssoWarningUp.getValue());

	UserProperty ispaWarningUp = userPropertyDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(), UserProperty.PREVENTION_ISPA_WARNING);
	boolean hideISPAWarning = ispaWarningUp != null && "true".equals(ispaWarningUp.getValue());

	UserProperty nonIspaWarningUp = userPropertyDao.getProp(LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo(), UserProperty.PREVENTION_NON_ISPA_WARNING);
	boolean hideNonISPAWarning = nonIspaWarningUp != null && "true".equals(nonIspaWarningUp.getValue());

	boolean canUpdateCVC = securityInfoManager.hasPrivilege(LoggedInInfo.getLoggedInInfoFromSession(request), "_prevention.updateCVC", "r", null);

%>

<%!
	public String getFromFacilityMsg(Map<String,Object> ht)
	{
		if (ht.get("id")==null)	return("<br /><span style=\"color:#990000\">(At facility : "+ht.get("remoteFacilityName")+")<span>");
		else return("");
	}
%>

<%@page import="org.oscarehr.util.SessionConstants"%>
<%@ page import="oscar.log.LogAction"%>
<%@ page import="oscar.log.LogConst"%>
<html:html locale="true">

<head>
<script type="text/javascript"
	src="<%= request.getContextPath() %>/js/global.js"></script>
<title><bean:message
		key="oscarprevention.index.oscarpreventiontitre" /></title>
<!--I18n-->
<script src="<%=request.getContextPath()%>/share/javascript/Oscar.js"></script>

<script src="<%=request.getContextPath() %>/library/jquery/jquery-3.6.4.min.js"></script>


<link href="<%=request.getContextPath()%>/css/bootstrap.css" rel="stylesheet" > <!-- Bootstrap 2.3.1 -->

<script type="text/javascript" src="<%=request.getContextPath()%>/share/yui/js/yahoo-dom-event.js"></script>
<script type="text/javascript" src="<%=request.getContextPath()%>/share/yui/js/connection-min.js"></script>
<script type="text/javascript" src="<%=request.getContextPath()%>/share/yui/js/animation-min.js"></script>
<script type="text/javascript" src="<%=request.getContextPath()%>/share/yui/js/datasource-min.js"></script>
<script type="text/javascript" src="<%=request.getContextPath()%>/share/yui/js/autocomplete-min.js"></script>

<link rel="stylesheet" href="<%=request.getContextPath()%>/share/yui/css/fonts-min.css" />
<link rel="stylesheet" href="<%=request.getContextPath()%>/share/yui/css/autocomplete.css" />

<link rel="stylesheet" media="all" href="<%=request.getContextPath()%>/share/css/demographicProviderAutocomplete.css" />

<script src="<%=request.getContextPath()%>/share/javascript/popupmenu.js" type="text/javascript"></script>
<script src="<%=request.getContextPath()%>/share/javascript/menutility.js" type="text/javascript"></script>

<script>

$(document).ready(function(){
    $("#recommendations").load("<%=request.getContextPath()%>/oscarPrevention/preventionRecommendations.jsp?demographic_no=<%=demographic_no%>");

    $.ajax('<%=request.getContextPath()%>/oscarPrevention/preventions.jsp?demographic_no=<%=demographic_no%>').done(function (response) {
        $('#preventions').html($.parseHTML( response ));
    });

});

function showMenu(menuNumber, eventObj) {
    var menuId = 'menu' + menuNumber;
    return showPopup(menuId, eventObj);
}
</script>
<style>
div.ImmSet {
	background-color: #ffffff;
	clear: left;
	margin-top: 10px;
}

div.ImmSet h2 {

}

div.ImmSet h2 span {
	font-size: smaller;
}

div.ImmSet ul {

}

div.ImmSet li {

}

div.ImmSet li a {
	text-decoration: none;
	color: blue;
}

div.ImmSet li a:hover {
	text-decoration: none;
	color: red;
}

div.ImmSet li a:visited {
	text-decoration: none;
	color: blue;
}

div.onPrint {
	display: none;
}

span.footnote {
	background-color: #ccccee;
	border: 1px solid #000;
	width: 4px;
}
.MainTableLeftColumn{
    min-width: 200px;
}
.MainTableRightColumn{
    padding-left:20px;
}
</style>

<script>

function display(elements) {

    for( var idx = 0; idx < elements.length; ++idx )
        elements[idx].style.display = 'block';
}

function EnablePrint(button) {
    if( button.value == "Enable Print" ) {
        button.value = "Print";
        var checkboxes = document.getElementsByName("printHP");
        display(checkboxes);
        var spaces = document.getElementsByName("printSp");
        display(spaces);
        if(button.form.sendToPhrButton != null) {
        	button.form.sendToPhrButton.style.display = 'block';
        }
        showImmunizationOnlyPrintButton();
    }
    else {
        if( onPrint() )
            document.printFrm.submit();
    }
}

function printImmOnly() {
	 document.printFrm.immunizationOnly.value = "true";
	 document.printFrm.submit();
}

function showImmunizationOnlyPrintButton() {
		console.log("test");
		$("#print_buttons").append("<input type=\"button\" class=\"noPrint btn\" name=\"printImmButton\" onclick=\"printImmOnly()\" value=\"Print Immunizations Only\">");
}

function onPrint() {
    var checked = document.getElementsByName("printHP");
    var thereIsData = false;

    for( var idx = 0; idx < checked.length; ++idx ) {
        if( checked[idx].checked ) {
            thereIsData = true;
            break;
        }
    }

    if( !thereIsData ) {
        alert("You should check at least one prevention by selecting a checkbox next to a prevention");
        return false;
    }

    return true;
}

function sendToPhr(button) {
    var oldAction = button.form.action;
    button.form.action = "<%=request.getContextPath()%>/phr/SendToPhrPreview.jsp"
    button.form.submit();
    button.form.action = oldAction;
}

function addByLot() {
	var lotNbr = $("#lotNumberToAdd").val();

	popup(820,800,'AddPreventionData.jsp?demographic_no=<%=demographic_no%>&lotNumber=' + lotNbr,'addPreventionData' + <%=new java.util.Random().nextInt(10000) + 1%> );

}

function viewDHIRSummary() {
	popup(600,900,'ViewDHIRData.jsp?demographic_no=<%=demographic_no%>','ViewDHIRData' + <%=new java.util.Random().nextInt(10000) + 1%> );

}
</script>




<script type="text/javascript">
<!--
//if (document.all || document.layers)  window.resizeTo(790,580);
function newWindow(file,window) {
  msgWindow=open(file,window,'scrollbars=yes,width=760,height=520,screenX=0,screenY=0,top=0,left=10');
  if (msgWindow.opener == null) msgWindow.opener = self;
}
//-->
</script>




<style type="text/css">
body {
	font-size: 100%
}

//
div.news {
	width: 100px;
	background: #FFF;
	margin-bottom: 20px;
	margin-left: 20px;
}

div.leftBox {
	width: 200px;
	margin-top: 2px;
	margin-left: 3px;
	margin-right: 3px;
	float: left;
}

div.leftBox h3 {
	background-color: #ccccff;
	font-size: 10pt;
	font-variant: small-caps;
	margin-top: 0px;
	padding-top: 0px;
	margin-bottom: 0px;
	padding-bottom: 0px;
	line-height: 20px;
}

div.leftBox ul { /*border-top: 1px solid #F11;*/
	/*border-bottom: 1px solid #F11;*/
	font-size: 1.0em;
	list-style: none;
	list-style-type: none;
	list-style-position: outside;
	padding-left: 1px;
	margin-left: 1px;
	margin-top: 0px;
	padding-top: 1px;
	margin-bottom: 0px;
	padding-bottom: 0px;
	font-size: 0.8em;
}

div.leftBox li {
	padding-right: 15px;
	white-space: nowrap;
	line-height:16px;
}

div.headPrevention {
	position: relative;
	float: left;
	width: 10em;
	height: 1.9em;
}

div.headPrevention p {
	background: #EEF;
	font-family: verdana, tahoma, sans-serif;
	margin: 0;
	padding: 4px 5px;
	line-height: 1.3;
	text-align: justify height: 2em;
	font-family: sans-serif;
	border-left: 0px;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
}

div.headPrevention a {
	text-decoration: none;
}

div.headPrevention a:active {
	color: blue;
}

div.headPrevention a:hover {
	color: blue;
}

div.headPrevention a:link {
	color: blue;
}

div.headPrevention a:visited {
	color: blue;
}

div.preventionProcedure {
	width: 10em;
	float: left;
	margin-left: 3px;
	margin-bottom: 3px;
}

div.preventionProcedure p {
	font-size: 0.8em;
	font-family: verdana, tahoma, sans-serif;
	background: #F0F0E7;
	margin: 0;
	padding: 1px 2px;
	/*line-height: 1.3;*/ /*text-align: justify*/
}

div.preventionSection {
	width: 100%;
	postion: relative;
	margin-top: 5px;
	float: left;
	clear: left;
}

div.preventionSet {
	border: thin solid grey;
	clear: left;
}

div.recommendations {
	font-family: verdana, tahoma, sans-serif;
	font-size: 14px;
}

div.recommendations ul {
	padding-left: 15px;
	margin-left: 1px;
	margin-top: 0px;
	padding-top: 1px;
	margin-bottom: 0px;
	padding-bottom: 0px;
}

table.legend {
	border: 0;
	padding-top: 10px;
	width: 420px;
}

table.legend td {
	font-size: 8;
	text-align: left;
}

table.colour_codes {
	width: 8px;
	height: 10px;
	border: 1px solid #999999;
}

div.leftBox li {
	width: 200px;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
}
.yui-ac-bd li {
    overflow: hidden;
    text-overflow: ellipsis;
}

div.recommendations li {
	width: 600px;
}
</style>

<!--[if IE]>
<style type="text/css">

table.legend{
border:0;
margin-top:10px;
width:370px;
}

table.legend td{
font-size:10;
text-align:left;
}

</style>
<![endif]-->

<script>
function disableSSOWarning() {
	if(confirm("Are you sure you would like to permanently disable this warning?\nYou may re-enable it from your preferences")) {
        jQuery.ajax({
            type: "POST",
            url:  '<%=request.getContextPath()%>/ws/rs/persona/updatePreference',
            dataType:'json',
            contentType:'application/json',
            data: JSON.stringify({key:'prevention_sso_warning',value:'true'}),
            success: function (data) {
               $("#ssoWarning").hide();
            }
		});
	}
}
function disableISPAWarning() {
	if(confirm("Are you sure you would like to permanently disable this warning?\nYou may re-enable it from your preferences")) {
        jQuery.ajax({
            type: "POST",
            url:  '<%=request.getContextPath()%>/ws/rs/persona/updatePreference',
            dataType:'json',
            contentType:'application/json',
            data: JSON.stringify({key:'prevention_ispa_warning',value:'true'}),
            success: function (data) {
               $("#ispaWarning").hide();
            }
		});
	}
}

function disableNonISPAWarning() {
	if(confirm("Are you sure you would like to permanently disable this warning?\nYou may re-enable it from your preferences")) {
		jQuery.ajax({
            type: "POST",
            url:  '<%=request.getContextPath()%>/ws/rs/persona/updatePreference',
            dataType:'json',
            contentType:'application/json',
            data: JSON.stringify({key:'prevention_non_ispa_warning',value:'true'}),
            success: function (data) {
               $("#nonIspaWarning").hide();
            }
		});
	}
}

<%
	if(canUpdateCVC) {
%>
function updateCVC() {
	$.ajax({
         type: "POST",
         url: "<%=request.getContextPath()%>/cvc.do",
         data: { method : "updateCVC"},
        success: function(data,textStatus) {
        	 alert('CVC has been updated');
         }
	});
}
<% } %>
</script>
</head>

<body class="BodyStyle">
	<!--  -->
	<%=WebUtilsOld.popErrorAndInfoMessagesAsHtml(session)%>
	<%
List<String> OTHERS = Arrays.asList(new String[]{"DTaP-Hib","TdP-IPV-Hib","HBTmf"});
%>
	<table class="MainTable" id="scrollNumber1">
		<tr class="MainTableTopRow">
			<td class="MainTableTopRowLeftColumn"><h3>&nbsp;<bean:message
					key="oscarprevention.index.oscarpreventiontitre" /></h3></td>
			<td class="MainTableTopRowRightColumn">
				<table class="TopStatusBar">
					<tr>
						<td><%=Encode.forHtml(nameAge)%></td>
						<td>&nbsp;</td>
						<td style="text-align: right">
							<% if (billRegion.equals("ON")) { %> <a title="Open Billing Page"
							onclick="popupFocusPage(700, 1000, '../billing.do?billRegion=ON&amp;billForm=MFP&amp;hotclick=&amp;appointment_no=0&amp;demographic_name=<%=Encode.forUriComponent(demo.getLastName())%>%2C<%=Encode.forUriComponent(demo.getFirstName())%>&amp;demographic_no=<%=demographic_no%>&amp;providerview=1&amp;user_no=<%=(String) session.getValue("user")%>&amp;apptProvider_no=none&amp;appointment_date=<%=todayString%>&amp;start_time=0:00:00&amp;bNewForm=1&amp;status=t','_self');return false;"
							href="javascript: function myFunction() {return false; }"> B
						</a>&nbsp;| <% } %>

								<%
logger.info("rendering page top bar");
					if(canUpdateCVC) {
					%> <a onClick="updateCVC()" href="javascript:void()">Update Immunizations</a>
								| <% } %> <oscar:help keywords="prevention" key="app.top1" /> | <a
								href="javascript:popupStart(300,400,'About.jsp')"><bean:message
										key="global.about" /></a> | <a
								href="javascript:popupStart(300,400,'License.jsp')"><bean:message
										key="global.license" /></a>
						</td>
					</tr>
				</table>
			</td>
		</tr>
		<tr>
			<td class="MainTableLeftColumn" valign="top">


				<div class="leftBox">
					<!-- <h3>&nbsp;Preventions</h3> -->
					<div style="background-color: #EEEEFF;">
						<h3>Screenings</h3>
						<ul>
							<%

            // endTime = System.nanoTime();
            //  .println("Starting Screening List after " + (endTime - startTime)/1000 + " milliseconds");
             for (int i = 0 ; i < prevList.size(); i++){
				HashMap<String,String> h = prevList.get(i);
                String prevName = h.get("name");
                String displayName = h.get("displayName") != null ? h.get("displayName") : prevName;
                String snomedId = h.get("snomedConceptCode") != null ? h.get("snomedConceptCode") : null;
                String hcType = h.get("healthCanadaType");
            	if(hcType == null) {
		            if(!preventionManager.hideItem(prevName) && !OTHERS.contains(prevName)){
		            	List<CVCMapping> mappings = cvcMappingDao.findMultipleByOscarName(prevName);
			            if(mappings != null && mappings.size()>1) {%>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(600,1100,'AddPreventionDataDisambiguate.jsp?<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=displayName%>
							</a></li>
							<%  } else {
			            %>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(820,800,'AddPreventionData.jsp?4=4&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=displayName%>
							</a></li>
							<%
			            }
		            }
            	}
			}
	        %>

						</ul>
						<h3>Immunizations</h3>
						<ul>
							<%
            // endTime = System.nanoTime();
            // .println("Starting Immunizations after " + (endTime - startTime)/1000 + " milliseconds");
            for (int i = 0 ; i < prevList.size(); i++){
				HashMap<String,String> h = prevList.get(i);
                String prevName = h.get("name");
                String displayName = h.get("displayName") != null ? h.get("displayName") : prevName;
                String snomedId = h.get("snomedConceptCode") != null ? h.get("snomedConceptCode") : null;
                String hcType = h.get("healthCanadaType");
                String ispaStr = h.get("ispa");
                boolean ispa = ispaStr != null && "true".equals(ispaStr);
                String ispa1 = "";
                if(ispa) {
                	ispa1 = "*";
                }

            	if(hcType != null) {
		            if(!preventionManager.hideItem(prevName) && !OTHERS.contains(prevName)){
		            	List<CVCMapping> mappings = cvcMappingDao.findMultipleByOscarName(prevName);
			            if(mappings != null && mappings.size()>1) {%>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(600,1100,'AddPreventionDataDisambiguate.jsp?<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=ispa1 %><%=displayName%>
							</a></li>
							<%  } else {
			            %>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(820,800,'AddPreventionData.jsp?4=4&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=ispa1 %><%=displayName%>
							</a></li>
							<%
			            }
		            }
            	}
			}
	        %>
						</ul>
						<!--<h3>Other</h3>-->
						<ul>
							<%
logger.info("finished the index");
if(bShowAll){
            // endTime = System.nanoTime();
            // .println("Starting Other after " + (endTime - startTime)/1000 + " milliseconds");
			for (int i = 0 ; i < prevList.size(); i++){
				HashMap<String,String> h = prevList.get(i);
                String prevName = h.get("name");
                String displayName = h.get("displayName") != null ? h.get("displayName") : prevName;
                String snomedId = h.get("snomedConceptCode") != null ? h.get("snomedConceptCode") : null;
                String hcType = h.get("healthCanadaType");

	            if(!preventionManager.hideItem(prevName)){

	            	if(OTHERS.contains(prevName)) {

		            	List<CVCMapping> mappings = cvcMappingDao.findMultipleByOscarName(prevName);
			            if(mappings != null && mappings.size()>1) {%>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(600,1100,'AddPreventionDataDisambiguate.jsp?<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=displayName%>
							</a></li>
							<%  } else {
			            %>
							<li style="margin-top: 2px;"><a
								href="javascript: function myFunction() {return false; }"
								onclick="javascript:popup(820,800,'AddPreventionData.jsp?4=4&<%=snomedId != null ? "snomedId=" + snomedId + "&" : ""%>prevention=<%= java.net.URLEncoder.encode(prevName) %>&amp;demographic_no=<%=demographic_no%>&amp;prevResultDesc=<%= java.net.URLEncoder.encode(h.get("resultDesc")) %>','addPreventionData<%=Math.abs(prevName.hashCode()) %>')"
								title="<%=h.get("desc")%>"> <%=displayName%>
							</a></li>
							<%
			            }
		            }
	            }
			}
}
	        %>
						</ul>
					</div>
				</div>
<% if(bShowAll){  %>    <!-- old AND broken functionality -->
                <oscar:oscarPropertiesCheck property="IMMUNIZATION_IN_PREVENTION"
					value="yes">
					<a href="javascript: function myFunction() {return false; }"
						onclick="javascript:popup(700,960,'<rewrite:reWrite jspPage="../oscarEncounter/immunization/initSchedule.do"/>?demographic_no=<%=demographic_no%>','oldImms')">Old
						<bean:message key="global.immunizations" />
					</a>
					<br>
				</oscar:oscarPropertiesCheck>
<% }  %>
			</td>


				<td valign="top" class="MainTableRightColumn"><a href="#"
					onclick="popup(600,800,'https://www.canada.ca/en/public-health/services/publications/healthy-living/canadian-immunization-guide-part-1-key-immunization-information/page-13-recommended-immunization-schedules.html')">Immunization
						Schedules - Public Health Agency of Canada</a> <%
				if (MyOscarUtils.isMyOscarEnabled((String) session.getAttribute("user")))
				{
					MyOscarLoggedInInfo myOscarLoggedInInfo=MyOscarLoggedInInfo.getLoggedInInfo(session);
           		  	boolean enabledMyOscarButton=MyOscarUtils.isMyOscarSendButtonEnabled(myOscarLoggedInInfo, Integer.valueOf(demographic_no));
					if (enabledMyOscarButton)
					{
						String sendDataPath = request.getContextPath() + "/phr/send_medicaldata_to_myoscar.jsp?"
								+ "demographicId=" + demographic_no + "&"
								+ "medicalDataType=Immunizations" + "&"
								+ "parentPage=" + request.getRequestURI() + "?demographic_no=" + demographic_no;
		%> | | <a href="<%=sendDataPath%>"><%=LocaleUtils.getMessage(request, "SendToPHR")%></a>
					<%
					}
					else
					{
		%> | | <span style="color: grey; text-decoration: underline"><%=LocaleUtils.getMessage(request, "SendToPHR")%></span>
					<%
					}
				}
		%>
					<br><span style="font-size: larger;">Prevention Recommendations</span>
					<div id="recommendations" class="recommendations alert-info">
                        <br>
                        &nbsp;<img src='<%=request.getContextPath()%>/images/DMSLoader.gif'>&nbsp;<bean:message key="caseload.msgLoading" />
                        <br>
						<%
                    logger.info("rendering loading of recomendations");
                    if(printError) {
                   %>
						<p style="color: red; font-size: larger">An error occurred
							while trying to print</p>
						<%
                    }
                   %>


					</div> <br /> <%if(!StringUtils.isEmpty(CanadianVaccineCatalogueManager2.getCVCURL())) { %>
					<table>
						<tr>
							<td style="font-size: 12pt">Add by Brand/Generic/Lot#</td>
							<td><input type="text" id="lotNumberToAdd2"
								name="lotNumberToAdd2" size="40" />
							<div id="lotNumberToAdd2_choices" class="autocomplete"></div></td>
						</tr>
					</table> <% } %> <br /> <%if(dhirEnabled) {%> <input type="button" class="btn"
					value="View DHIR Data" onClick="viewDHIRSummary()" /> <% } %> <%
	 String[] ColourCodesArray=new String[7];
	 ColourCodesArray[1]="#F0F0E7"; //very light grey - completed or normal
	 ColourCodesArray[2]="#FFDDDD"; //light pink - Refused
	 ColourCodesArray[3]="#FFCC24"; //orange - Ineligible
	 ColourCodesArray[4]="#FF00FF"; //dark pink - pending
	 ColourCodesArray[5]="#ee5f5b"; //dark salmon to match part of bootstraps danger - abnormal
	 ColourCodesArray[6]="#BDFCC9"; //green - other

	 //labels for colour codes
	 String[] lblCodesArray=new String[7];
	 lblCodesArray[1]="Completed or Normal";
	 lblCodesArray[2]="Refused";
	 lblCodesArray[3]="Ineligible";
	 lblCodesArray[4]="Pending";
	 lblCodesArray[5]="Abnormal";
	 lblCodesArray[6]="Other";

	 //Title ie: Legend or Profile Legend
	 String legend_title="Legend: ";

	 //creat empty builder string
	 String legend_builder=" ";


	 	for (int iLegend = 1; iLegend < 7; iLegend++){

			legend_builder +="<td> <table class='colour_codes' style=\"white-space:nowrap; background-color:"+ColourCodesArray[iLegend]+"\"><tr><td> </td></tr></table> </td> <td align='center' style=\"white-space:nowrap;\">"+lblCodesArray[iLegend]+"</td>";

		}

	 	legend_builder +="<td> <table class='colour_codes' style=\"white-space:nowrap;border:none\" bgcolor='white'><tr><td>*</td></tr></table> </td> <td align='center' style=\"white-space:nowrap;\">ISPA</td>";


	 	String legend = "<table class='legend' cellspacing='0'><tr><td><b>"+legend_title+"</b></td>"+legend_builder+"</tr></table>";

		out.print(legend);
%>



					<div>
						<input type="hidden" name="demographic_no"
							value="<%=demographic_no%>"> <input type="hidden"
							name="hin" value="<%=hin%>" /> <input type="hidden" name="mrp"
							value="<%=mrp%>" /> <input type="hidden" name="module"
							value="prevention">
                        <div id="preventions">
                            <br>
                            &nbsp;<img src='<%=request.getContextPath()%>/images/DMSLoader.gif'><bean:message key="caseload.msgLoading" />
                            <br>
                        </div>

									</div>
									<%=legend%></td>
		</tr>
		<tr>
			<td class="MainTableBottomRowLeftColumn"> <!-- <span
				id="print_buttons"> <input type="button" class="noPrint btn"
					name="printButton" onclick="EnablePrint(this)" value="Enable Print">
				</input>
			<br>
			<input type="button" class="btn" name="sendToPhrButton" value="Send To MyOscar (PDF)" style="display: none;" onclick="sendToPhr(this)">
--></td>

			<input type="hidden" id="demographicNo" name="demographicNo"
				value="<%=demographic_no%>" />

			<%

            endTime = System.nanoTime();
            logger.info("Thats the basic page after " + ((endTime - startTime)/1000)/1000 + " milliseconds");
 %>

		</tr>
	</table>

	<script type="text/javascript" src="../share/javascript/boxover.js"></script>

	<script type="text/javascript">

//basic..just makes the brand name ones bold
var resultFormatter2 = function(oResultData, sQuery, sResultMatch) {
	var output = '';

	if(!oResultData[1]) {
		output = '<b>' + oResultData[0] + '</b>';
	} else {
		output = oResultData[0];
	}
   	return output;
}

YAHOO.example.BasicRemote = function() {
    if($("lotNumberToAdd2") && $("lotNumberToAdd2_choices")){
          var url = "../cvc.do?method=query";
          var oDS = new YAHOO.util.XHRDataSource(url,{connMethodPost:true,connXhrMode:'ignoreStaleResponses'});
          oDS.responseType = YAHOO.util.XHRDataSource.TYPE_JSON;
          oDS.responseSchema = {
              resultsList : "results",
              fields : ["name","generic","genericSnomedId","snomedId","lotNumber"]
          };
          oDS.maxCacheEntries = 0;
          var oAC = new YAHOO.widget.AutoComplete("lotNumberToAdd2","lotNumberToAdd2_choices",oDS);
          oAC.queryMatchSubset = true;
          oAC.minQueryLength = 3;
          oAC.maxResultsDisplayed = 25;
          oAC.formatResult = resultFormatter2;
          oAC.queryMatchContains = true;
          oAC.itemSelectEvent.subscribe(function(type, args) {
        	  var myAC = args[0]; // reference back to the AC instance
        	  var elLI = args[1]; // reference to the selected LI element
        	  var oData = args[2]; // object literal of selected item's result data

        	  console.log('selected');

        	  console.log('args:' + oData[0] + ',' + oData[1] + ',' + oData[2] + ',' + oData[3] + ',' + oData[4]);

        	  //We need to load AddPreventionData with possible brand name, and possible lotnumber/exp.
        	  if(oData[4].length > 0) {
        		popup(820,800,'AddPreventionData.jsp?demographic_no=<%=demographic_no%>&lotNumber=' + oData[4],'addPreventionData' + <%=new java.util.Random().nextInt(10000) + 1%> );
        		document.getElementById('lotNumberToAdd2').value = '';
        	  } else {
        		 popup(820,800,'AddPreventionData.jsp?search=true&demographic_no=<%=demographic_no%>&snomedId=' + oData[2] + '&brandSnomedId=' + oData[3],'addPreventionData' + <%=new java.util.Random().nextInt(10000) + 1%> );
          		document.getElementById('lotNumberToAdd2').value = '';
        	  }


          });

           return {
               oDS: oDS,
               oAC: oAC
           };
       }
       }();

</script>
</body>
</html:html>