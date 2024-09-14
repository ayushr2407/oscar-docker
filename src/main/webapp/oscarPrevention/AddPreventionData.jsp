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
<%@page import="org.oscarehr.common.model.LookupListItem"%>
<%@page import="org.oscarehr.common.model.LookupList"%>
<%@page import="org.oscarehr.common.dao.LookupListDao"%>
<%@page import="org.oscarehr.common.model.Consent"%>
<%@page import="org.oscarehr.common.dao.ConsentDao"%>
<%@page import="org.oscarehr.common.model.CVCMapping"%>
<%@page import="org.oscarehr.common.dao.CVCImmunizationDao"%>
<%@page import="org.oscarehr.common.dao.CVCMappingDao"%>
<%@page import="org.oscarehr.common.model.CVCMedicationLotNumber"%>
<%@page import="org.oscarehr.common.model.PartialDate"%>
<%@page import="org.oscarehr.common.dao.PartialDateDao"%>
<%@page import="org.oscarehr.common.model.CVCImmunization"%>
<%@page import="org.oscarehr.common.dao.DemographicExtDao" %>
<%@page import="org.oscarehr.common.dao.PreventionsLotNrsDao" %>
<%@page import="org.oscarehr.common.model.PreventionsLotNrs" %>
<%@page import="org.oscarehr.common.model.Demographic" %>
<%@page import="org.oscarehr.managers.CanadianVaccineCatalogueManager"%>
<%@page import="org.oscarehr.managers.CanadianVaccineCatalogueManager2"%>
<%@page import="org.oscarehr.casemgmt.model.CaseManagementNoteLink" %>
<%@page import="org.oscarehr.casemgmt.service.CaseManagementManager" %>
<%@page import="org.oscarehr.util.SpringUtils"%>
<%@page import="org.oscarehr.util.LoggedInInfo"%>

<%@page import="oscar.oscarMDS.data.ProviderData"%>
<%@page import="oscar.oscarDemographic.data.DemographicData"%>
<%@page import="oscar.OscarProperties"%>
<%@page import="oscar.oscarPrevention.*"%>
<%@page import="oscar.oscarProvider.data.*"%>

<%@page import="oscar.util.*"%>
<%@page import="java.util.*"%>
<%@page import="java.text.ParseException"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="java.util.ArrayList"%>

<%@page import="org.owasp.encoder.Encode" %>

<%@page import="org.apache.commons.lang.StringEscapeUtils"%>
<%@page import="org.apache.commons.lang.StringUtils"%>

<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean" %>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html" %>
<%@ taglib uri="/WEB-INF/oscar-tag.tld" prefix="oscar" %>
<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
      String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");
	  boolean authed=true;
%>
<security:oscarSec roleName="<%=roleName$%>" objectName="_prevention" rights="r" reverse="<%=true%>">
	<%authed=false; %>
	<%response.sendRedirect("../securityError.jsp?type=_prevention");%>
</security:oscarSec>
<%
if(!authed) {
	return;
}
%>

<%
  DemographicExtDao demographicExtDao = SpringUtils.getBean(DemographicExtDao.class);
  CanadianVaccineCatalogueManager cvcManager = SpringUtils.getBean(CanadianVaccineCatalogueManager.class);
  CVCMappingDao cvcMappingDao = SpringUtils.getBean(CVCMappingDao.class);
  CVCImmunizationDao cvcImmunizationDao = SpringUtils.getBean(CVCImmunizationDao.class);
  PartialDateDao partialDateDao = SpringUtils.getBean(PartialDateDao.class);

   LoggedInInfo loggedInInfo = LoggedInInfo.getLoggedInInfoFromSession(request);

  if(session.getValue("user") == null) response.sendRedirect("../logout.jsp");
  String demographic_no = request.getParameter("demographic_no");
  String snomedId = request.getParameter("snomedId");
  String id = request.getParameter("id");
  Map<String,Object> existingPrevention = null;

  String providerName ="";
  String lot ="";
  String provider = (String) session.getValue("user");
  String dateFmt = "yyyy-MM-dd HH:mm";
  String prevDate = UtilDateUtilities.getToday(dateFmt);
  String completed = "0";
  String nextDate = "";
  String summary = "";
  String creatorProviderNo = "";
  String creatorName = "";
  String expiryDate = "";

  boolean never = false;
  Map<String,String> extraData = new HashMap<String,String>();
	boolean hasImportExtra = false;
	String annotation_display = CaseManagementNoteLink.DISP_PREV;


	boolean dhirEnabled=false;

  	if("true".equals(OscarProperties.getInstance().getProperty("dhir.enabled", "false"))) {
  		dhirEnabled=true;
  	}

     Date creationDate = null;
  if (id != null){

     existingPrevention = PreventionData.getPreventionById(id);

     prevDate = (String) existingPrevention.get("preventionDate");
     prevDate = partialDateDao.getDatePartial(prevDate, PartialDate.PREVENTION,  Integer.parseInt(id), PartialDate.PREVENTION_PREVENTIONDATE);

     providerName = (String) existingPrevention.get("providerName");
     provider = (String) existingPrevention.get("provider_no");
     creatorProviderNo = (String) existingPrevention.get("creator");

     if ( existingPrevention.get("refused") != null ){
        completed = (String)existingPrevention.get("refused");
     }
     if ( existingPrevention.get("never") != null && ((String)existingPrevention.get("never")).equals("1") ){
        never = true;
     }
     nextDate = (String) existingPrevention.get("next_date");
     if ( nextDate == null || nextDate.equalsIgnoreCase("null") || nextDate.equals("0000-00-00")){
        nextDate = "";
     }
     summary = (String) existingPrevention.get("summary");
     extraData = PreventionData.getPreventionKeyValues(id);
     lot = (String) extraData.get("lot");
     expiryDate = (String) extraData.get("expiryDate");
	CaseManagementManager cmm = (CaseManagementManager) SpringUtils.getBean("caseManagementManager");
	List<CaseManagementNoteLink> cml = cmm.getLinkByTableId(CaseManagementNoteLink.PREVENTIONS, Long.valueOf(id));
	hasImportExtra = (cml.size()>0);
	 snomedId = (String) existingPrevention.get("snomedId");

	 creationDate = parseDate((String) existingPrevention.get("creationDate"));

  }

  String prevention = request.getParameter("prevention");
  if (prevention == null && existingPrevention != null){
      prevention = (String) existingPrevention.get("preventionType");
  }



  PreventionsLotNrsDao PreventionsLotNrsDao = (PreventionsLotNrsDao)SpringUtils.getBean(PreventionsLotNrsDao.class);
  List<String> lotNrList = PreventionsLotNrsDao.findLotNrs(prevention, false);

  String prevResultDesc = request.getParameter("prevResultDesc");

  String errorsToShow = "";
  boolean foundByLotNumber = false;
  CVCImmunization brandName = null;
  CVCImmunization generic = null;

  String addByLotNbr = request.getParameter("lotNumber");
  if(StringUtils.isNotEmpty(addByLotNbr)) {
	  CVCMedicationLotNumber medLot =  cvcManager.findByLotNumber(loggedInInfo, addByLotNbr);
	  if(medLot != null) {
		  String snomedCodeForMedication = medLot.getMedication().getSnomedCode();
		  brandName = cvcManager.getBrandNameImmunizationBySnomedCode(loggedInInfo,snomedCodeForMedication);
		  generic = cvcManager.getBrandNameImmunizationBySnomedCode(loggedInInfo, brandName.getParentConceptId());
		  //Is there an OSCAR mapping for the prevention type
		  CVCMapping mapping1 = cvcMappingDao.findBySnomedId(generic.getSnomedConceptId());
		  if(mapping1 != null) {
			prevention = mapping1.getOscarName();
		  } else {
		  	prevention = generic.getPicklistName();
		  }
		  snomedId = generic.getSnomedConceptId();
		  foundByLotNumber = true;
	  } else {
		  errorsToShow="Could not find this lot number in the system.";
	  }
  }

  String addByLotNbr2 = request.getParameter("search");
  if(StringUtils.isNotEmpty(addByLotNbr2)) {
	  String brandSnomedId = request.getParameter("brandSnomedId");

	  generic = cvcManager.getBrandNameImmunizationBySnomedCode(loggedInInfo, snomedId);
	  if(generic != null) {
	  	brandName = cvcManager.getBrandNameImmunizationBySnomedCode(loggedInInfo, brandSnomedId);
	  	prevention = generic.getPicklistName();
	  	CVCMapping mapping1 = cvcMappingDao.findBySnomedId(generic.getSnomedConceptId());
		  if(mapping1 != null) {
			prevention = mapping1.getOscarName();
		  } else {
		  	prevention = generic.getPicklistName();
		  }
	  	foundByLotNumber = true;
	  } else {
		  errorsToShow="Could not find this prevention in the system.";
	  }
  }

  boolean isCvc = false;
	isCvc = snomedId != null;

  PreventionDisplayConfig pdc = PreventionDisplayConfig.getInstance();
  HashMap<String,String> prevHash = pdc.getPrevention(prevention);

  String layoutType = "default";
  if(prevHash != null) {
	  layoutType = prevHash.get("layout");
	  if ( layoutType == null){
	      layoutType = "default";
	  }
  }


  if (creatorProviderNo == "")
  {
	  creatorProviderNo = provider;
  }

  ArrayList providers = ProviderData.getProviderList();
        for (int i=0; i < providers.size(); i++) {
            if ((((ArrayList) providers.get(i)).get(0)).equals(creatorProviderNo))
	   {
	   		creatorName = Encode.forHtmlContent((String) ((ArrayList) providers.get(i)).get(2)+", "+(String) ((ArrayList) providers.get(i)).get(1));
	   }
  }

  //calc age at time of prevention
  Date dob = PreventionData.getDemographicDateOfBirth(LoggedInInfo.getLoggedInInfoFromSession(request), Integer.valueOf(demographic_no));
  Date dateOfPrev = parseDate(prevDate);
  String age = UtilDateUtilities.calcAgeAtDate(dob, dateOfPrev);
  DemographicData demoData = new DemographicData();
  String[] demoInfo = demoData.getNameAgeSexArray(LoggedInInfo.getLoggedInInfoFromSession(request), Integer.valueOf(demographic_no));
  String nameage = demoInfo[0] + ", " + demoInfo[1] + " " + demoInfo[2] + " " + age;

  Demographic demoObject = demoData.getDemographic(LoggedInInfo.getLoggedInInfoFromSession(request), demographic_no);

  HashMap<String,String> genders = new HashMap<String,String>();
  genders.put("M", "Male");
  genders.put("F", "Female");
  genders.put("U", "Unknown");
%>


<html:html locale="true">

<head>
<title>
<bean:message key="oscarprevention.index.oscarpreventiontitre" />
</title><!--I18n-->
<script src="<%=request.getContextPath() %>/library/jquery/jquery-3.6.4.min.js"></script>
<script src="../share/calendar/calendar.js" ></script>
<script src="../share/calendar/lang/<bean:message key="global.javascript.calendar"/>" ></script>
<script src="../share/calendar/calendar-setup.js" ></script>

<!-- <link rel="stylesheet" type="text/css" href="../share/css/OscarStandardLayout.css"> -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<!-- css -->

<link href="<%=request.getContextPath()%>/css/bootstrap.css" rel="stylesheet" > <!-- Bootstrap 2.3.1 -->

<link href="<%=request.getContextPath()%>/css/bootstrap-responsive.css" rel="stylesheet" >


<link rel="stylesheet" type="text/css" media="all" href="../share/calendar/calendar.css" title="win2k-cold-1" />




<script>

var isCvc = <%=isCvc%>;

function showHideItem(id){
    if(document.getElementById(id).style.display == 'none')
        document.getElementById(id).style.display = '';
    else
        document.getElementById(id).style.display = 'none';
}

function showItem(id){
        document.getElementById(id).style.display = '';
}

function hideItem(id){
        document.getElementById(id).style.display = 'none';
}

function showHideNextDate(id,nextDate,nexerWarn){
    if(document.getElementById(id).style.display == 'none'){
        showItem(id);
    }else{
        hideItem(id);
        document.getElementById(nextDate).value = "";
        document.getElementById(nexerWarn).checked = false ;

    }
}

function disableifchecked(ele,nextDate){
    if($('#'+ele).is(':checked')){
       $('#'+nextDate).attr("disabled", "disabled");
    }else{
       $('#'+nextDate).removeAttr("disabled");
    }
}

</script>

<style>
	table.outline{
	   margin-top:50px;
	   border-bottom: 1pt solid #888888;
	   border-left: 1pt solid #888888;
	   border-top: 1pt solid #888888;
	   border-right: 1pt solid #888888;
	}
	table.grid{
	   border-bottom: 1pt solid #888888;
	   border-left: 1pt solid #888888;
	   border-top: 1pt solid #888888;
	   border-right: 1pt solid #888888;
	}
	td.gridTitles{
		border-bottom: 2pt solid #888888;
		font-weight: bold;
		text-align: center;
	}
        td.gridTitlesWOBottom{
                font-weight: bold;
                text-align: center;
        }
	td.middleGrid{
	   border-left: 1pt solid #888888;
	   border-right: 1pt solid #888888;
           text-align: center;
	}


label{
float: left;
width: 120px;
font-weight: bold;
}

label.checkbox{
float: left;
width: 116px;
font-weight: bold;
}

label.fields{
float: left;
width: 80px;
font-weight: bold;
}

span.labelLook{
font-weight:bold;

}


.boxes{
width: 1em;
}


br{
clear: left;
}
</style>

<script>
  function hideExtraName(ele){
   //alert(ele);
    if (ele.options[ele.selectedIndex].value != -1){
       hideItem('providerName');
       hideItem('providerNameFormat');
       //alert('hidding');
    }else{
       showItem('providerName');
       showItem('providerNameFormat');
       document.getElementById('providerName').focus();
       //alert('showing');
    }
  }
</script>

<script>
  function updateLotNr(elem){
	if (elem != null && elem.options[elem.selectedIndex].value != -1)
	{
		hideItem('lot');
	}
   //show "other" in drop-down
   else if (elem.options[elem.selectedIndex].value == -1)
   {
	    document.getElementById('lot').value = "";
   		showItem('lot');
      	document.getElementById('lot').focus();
   }
  }
  </script>
  <script>
  function hideLotDrop(elem){
        if(elem == null){ return; }
	  var bFound = 0;
	  var LotNr = document.getElementById('lot').value;
	  var summary =  document.getElementById('summary');
	  //existing prevention record
	  if (typeof(summary) != 'undefined' && summary != null)
	  {
	     if (LotNr.length == 0)
	     {
	    	 if (elem.options[0].value != -1) //table exists
	    	 {
	    		 elem.options[elem.options.length-1].selected = true;
	    		 return;
	    	 }
	    	 else
	    	 {
	  	       hideItem('lotDrop');
	  		   showItem('lot');
	  	       return;
	  	    }
	     }
	  }
	  if (LotNr.length >0)
	  {
		  for (var i = 0; i < elem.length; i++) {
		        if (elem.options[i].value == LotNr){
		        	bFound = 1;
					break;
				}
		    }
	  }
	  if (elem.options[0].value == -1)
	  //no preventionslotnrs table
	  {
		   hideItem('lotDrop');
		   showItem('lot');
	  }
	 // not in drop-down
	 else if (!bFound && LotNr.length >0)
	 {
		 elem.options[elem.options.length-1].selected = true;
	 }
	  //exists in dd
	  else if (elem.options[elem.selectedIndex].value != -1)
	  {
	   		hideItem('lot');
	  }
	  }


var warnOnWindowClose=true;

function copyLot() {

	var cvcName = $("#cvcName option:selected").val();
	if(cvcName !== undefined && cvcName != -1 && $("#cvcLot").is(":visible")) {
		//$("#lot").val($("#cvcLot").val());
		$("#name").val($("#cvcName option:selected").text());
	}
}

function cancelCloseWarning(){
warnOnWindowClose=false;
}

window.onbeforeunload = displayCloseWarning;

function displayCloseWarning(){
	if(warnOnWindowClose){
		return 'Are you sure you want to close this window?';
	}
}

//{"lotNumber":"M042476","expiryDate":{"date":22,"day":5,"hours":0,"minutes":0,"month":2,"nanos":0,"seconds":0,"time":1553227200000,"timezoneOffset":240,"year":119}}

function escapeHtml(unsafe1) {
	var unsafe = String(unsafe1);
    return unsafe
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
 }

var lots;
var startup = false, startup2 = false;

function GetSortOrder(prop) {
    return function(a, b) {
        if (a[prop] > b[prop]) {
            return -1;
        } else if (a[prop] < b[prop]) {
            return 1;
        }
        return 0;
    }
}

function changeCVCName() {
	lots = null;
	$("#typicalDose").html("");
    $("#displayName").text("");
	 var snomedId = $("#cvcName").val();
	 if(snomedId == "-1") {
		 $("#lot").show();
		 $("#cvcLot").hide();
		 $("#lotLabel").hide();
		 //$("#lot").show();
		 $("#expiryDate").val('');
		 $("#unknownName").show();
	 } else if(snomedId == "0") {
		 $("#name").show();
	 } else {
		 $("#unknownName").hide();
		 $("#name").val($("#cvcName option:selected").text());
		 $.ajax({
             type: "POST",
             url: "<%=request.getContextPath()%>/cvc.do",
             data: { method : "getLotNumberAndExpiryDates", snomedConceptId: snomedId},
             dataType: 'json',
             success: function(data,textStatus) {
            	 if(data != null && data.lots != null && data.lots instanceof Array && data.lots.length > 0) {
            		 //$("#lot").hide();
            		 $("#cvcLot").show();
            		 $("#lotLabel").show();
            		 $("#cvcLot").find("option").remove().end();

            		 $("#cvcLot").append('<option value=""></option>');

         			 data.lots.sort(GetSortOrder("lotNumber")); //Pass the attribute to be sorted
            		 for(var x=0;x<data.lots.length;x++) {
            			 var item = data.lots[x];
            			 //console.log(JSON.stringify(item));
            			 var d = new Date(data.lots[x].expiryDate.time);
            			// console.log(d);
            			var month = ((d.getMonth()+1) > 9) ? (d.getMonth()+1) : ("0" + (d.getMonth()+1));
            			var day = ((d.getDate()) > 9) ? (d.getDate()) : ("0" + (d.getDate()));
            			var output = d.getFullYear() + "-" + month + "-" + day;


            			if(startup2 && escapeHtml(item.lotNumber) == '<%=addByLotNbr %>') {
            				$("#cvcLot").append('<option selected="selected" value="'+item.lotNumber+'" data-expiryDate="'+output+'">'+item.lotNumber+'</option>');
            				startup2=false;
                            updateCvcLot();
            			} else if(startup && escapeHtml(item.lotNumber) == '<%=(existingPrevention != null)?existingPrevention.get("lot"):"" %>') {
            				$("#cvcLot").append('<option selected="selected" value="'+escapeHtml(item.lotNumber)+'" data-expiryDate="'+output+'">'+escapeHtml(item.lotNumber)+'</option>');
                            $("#lot").val(escapeHtml(item.lotNumber));
            				startup=false;
            			} else {
            				$("#cvcLot").append('<option value="'+escapeHtml(item.lotNumber)+'" data-expiryDate="'+output+'">'+escapeHtml(item.lotNumber)+'</option>');
            			}
            			//updateCvcLot();
            		 }
            	 } else {
            		 $("#cvcLot").hide();
            		 $("#cvcLot").find("option").remove().end();

            		// $("#lot").val('');
            		 $("#lot").show();
            	 }

            	 if(data != null && data.typicalDose != null) {
            		 var displayName = data.typicalDose.displayName;
            		 var dose = data.typicalDose.dose;
            		 var doseUnit = data.typicalDose.UoM;
                     var doseRoute = data.typicalDose.route;
                     var routeText = "";
            		 $("#cvcName").prop('title',displayName);
            		 $("#displayName").text(displayName);
            		 if(doseRoute != null ) {
            		 	$("#route").val(doseRoute).change();
                        var routeArray = $("#route option:selected").text().split(":");
                        routeText = routeArray[0];
            		 }
            		 if(dose != null && doseUnit != null) {
            		 	$("#typicalDose").html("&nbsp;" + dose + " " + doseUnit + " " + routeText);
            		 }
            		 $("#dose").val(dose);

            		 if(doseUnit == 'ml') {
            			 doseUnit = "mL";
            		 }
            		 $("#doseUnit").val(doseUnit);

            	 }
             }
          });



		 $.ajax({
             type: "POST",
             url: "<%=request.getContextPath()%>/cvc.do",
             data: { method : "getDIN", snomedConceptId: snomedId},
             dataType: 'json',
             success: function(data,textStatus) {
            	 if(data != null) {
            		 if(data.din != null) {
            			 $("#din").val(data.din);

            		 }
            		 if(data.manufacture != null) {
            			 $("#manufacture").val(data.manufacture);
            		 }
            		 //if(data.status != null) {
            		//	 $("#shelfStatus").html(data.status);
            		 //}
            	 }
             }
          });
	 }
}

function updateCvcLot() {
	var lotNumber = $("#cvcLot").find(":selected");
	$("#expiryDate").val(lotNumber.attr('data-expiryDate'));
    $("#lot").val($("#cvcLot").val());
}


<%
	if(foundByLotNumber) {
%>
	$(document).ready(function(){
		startup2=true;
		changeCVCName();
	});

<%
	}
%>


<% if(existingPrevention != null && snomedId != null && existingPrevention.get("brandSnomedId") != null) { %>
$(document).ready(function(){
	startup = true;
	$("#cvcName").val('<%=existingPrevention.get("brandSnomedId")%>');
	changeCVCName();
});
<% } %>


function changeSite(el) {
	var val = el.options[el.selectedIndex].value;
	if(val == 'Other') {
		$("#locationDiv").show();
	} else {
		$("#locationDiv").hide();
		$("#location2").val('');
	}
}
</script>
</head>

<body class="BodyStyle" onload="disableifchecked('neverWarn','nextDate');">

<div class ="span12">
    <table  class="MainTable" id="scrollNumber1">
        <tr class="MainTableTopRow">
            <td class="MainTableTopRowLeftColumn" style="width:150px;" >
               <h3>&nbsp;<bean:message key="oscarprevention.index.oscarpreventiontitre" /></h3>
            </td>
            <td class="MainTableTopRowRightColumn">
                <table class="TopStatusBar">
                    <tr>
                        <td >
                            <%=StringEscapeUtils.escapeHtml(nameage)%>
                        </td>
                        <td  >&nbsp;

                        </td>
                        <td style="text-align:right">
                                <oscar:help keywords="prevention" key="app.top1"/> | <a href="javascript:popupStart(300,400,'About.jsp')" ><bean:message key="global.about" /></a> | <a href="javascript:popupStart(300,400,'License.jsp')" ><bean:message key="global.license" /></a>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
<div class="container-fluid well" >
    <div class ="span8">
<!--
               <%
                 org.oscarehr.common.model.DemographicExt ineligx = demographicExtDao.getDemographicExt(Integer.parseInt(demographic_no),prevention+"Inelig");
				 String inelig = "";
				 if(ineligx != null) {
					 inelig = ineligx.getValue();
				 }

                 if (inelig.equals("yes")){ %>
                    Patient Ineligible<br>
                    <a href="setPatientIneligible.jsp?prev=<%=prevention%>&demo=<%=demographic_no%>&elig=yes">Set Patient Eligible</a>
                 <%}else{%>
                    <a href="setPatientIneligible.jsp?prev=<%=prevention%>&demo=<%=demographic_no%>">Set Patient Ineligible</a>
                 <%}%>
-->

<%
			if(dhirEnabled && session.getAttribute("oneIdEmail") == null) {
		%>
		<div style="width:100%;background-color:pink;text-align:center;font-weight:bold;font-size:13pt">
			Warning: You are not logged into OneId and will not be able to submit data to DHIR
		</div>
		<% } %>

<%
	if(request.getAttribute("errors") != null) {
		List<String> errorList = (List<String>)request.getAttribute("errors");
		%><ul style="color:red"><%
		for(String error:errorList) {
			%>
			<li><%=error %></li>
			<%
		}
		%></ul><%
	}

%>

            <% if(prevHash == null) { %>
            	<h3 style="color:red">Prevention not found!</h3>
            <%} else { %>
               <html:form action="/oscarPrevention/AddPrevention" onsubmit="copyLot();return cancelCloseWarning()">
               <input type="hidden" name="prevention" value="<%=prevention%>"/>
               <input type="hidden" name="demographic_no" value="<%=demographic_no%>"/>
               <%if(snomedId != null) {%>
               	<input type="hidden" name="snomedId" value="<%=snomedId %>" />
               <%} %>
               <% if ( id != null ) { %>
               <input type="hidden" name="id" value="<%=id%>"/>
               <input type="hidden" name="layoutType" value="<%=layoutType%>"/>

	       <div class="prevention span8">
		   <fieldset>
		       <legend>Summary</legend>
		       <textarea name="summary" class="span8" readonly style="height:240px;" ><%=summary%></textarea>
<%if (hasImportExtra) { %>
				<a href="javascript:void(0);" title="Extra data from Import" onclick="window.open('../annotation/importExtra.jsp?display=<%=annotation_display %>&amp;table_id=<%=id %>&amp;demo=<%=demographic_no %>','anwin','width=400,height=250');">
				 <img src="../images/notes.gif" align="right" alt="Extra data from Import" height="16" width="13" border="0"> </a>
<%} %>
		   </fieldset>
	       </div>
               <% } %>
               <%if (layoutType.equals("injection")) {%>
               <div class="prevention span8">
                   <fieldset>
                      <legend>Prevention : <%=prevention%></legend>
                         <div>
                            <input name="given" type="radio" value="given"  id="given"    <%=checked(completed,"0")%> onClick="$('#providerDrop').val('<%=LoggedInInfo.getLoggedInInfoFromSession(request).getLoggedInProviderNo() %>');hideExtraName(document.getElementById('providerDrop'))">Completed</input><br/>
                            <input name="given" type="radio" value="given_ext" id="givenExt" <%=checked(completed,"3")%> onClick="$('#providerDrop').val('-1');hideExtraName(document.getElementById('providerDrop'))">Completed externally</input><br/>
                            <input name="given" type="radio" value="refused"    <%=checked(completed,"1")%>>Refused</input><br/>
                            <input name="given" type="radio" value="ineligible" <%=checked(completed,"2")%>>Ineligible</input>
                         </div>
                         <div>&nbsp;</div>
                         <div style="margin-left:30px;">
                            <label for="prevDate" class="fields" >Date:</label>    <span class="input-append"><input type="text" name="prevDate" id="prevDate" value="<%=prevDate%>" style="width:167px;"> <a id="date"><img title="Calendar" class="add-on" src="../images/cal.gif" alt="Calendar" ></a></span><br>
                            <label for="provider" class="fields">Provider:</label> <input type="text" name="providerName" id="providerName" value="<%=providerName%>"/>
                                  <select onchange="javascript:hideExtraName(this);" id="providerDrop" name="provider">
                                      <% for (int i=0; i < providers.size(); i++) { %>
                                           <option value="<%= (String) ((ArrayList) providers.get(i)).get(0) %>"
		<%= ( ((String) ((ArrayList) providers.get(i)).get(0)).equals(provider) ? " selected" : "" ) %>>
    <%=Encode.forHtmlContent((String) ((ArrayList) providers.get(i)).get(2)+", "+(String) ((ArrayList) providers.get(i)).get(1)) %></option>
                                            </option>
                                      <% } %>
                                      <option value="-1" <%= ( "-1".equals(provider) ? " selected" : "" ) %> >Other</option>
                                  </select>
                                  <span id="providerNameFormat"><small>External Provider Name Format: FirstName, LastName </small>

                                  <br/>
                             <label for="creator" class="fields" >Creator:</label> <input type="text" name="creator" value="<%=creatorName%>" readonly/> <br/>
                         </div>
                   </fieldset>

                   <fieldset >
                      <legend >Details</legend>
                            <span id="displayName" style="font-weight:lighter; font-size:12px;"></span><br>
                    </fieldset>

                   <fieldset>
                      <legend >Result</legend>

             			 <%if(snomedId != null) {
             				List<CVCImmunization> tnList = cvcManager.getImmunizationsByParent(snomedId);
             				if(tnList != null && tnList.size() > 0) {
             					%>

             					<label for="cvcName">Trade Name:</label>
   	             			 <select id="cvcName" name="cvcName" onChange="changeCVCName()">
   	             			 	<option value="-1">Select Below</option>
   	             			 	<%
   	             			 		//get the tradenames associated with this generic
   	             			 		for(CVCImmunization tn:tnList) {
   	             			 			String selected = "";
   	             						if(existingPrevention != null) {
   		             			 			String brandSnomedId = (String) existingPrevention.get("brandSnomedId");
   		             			 			if(brandSnomedId != null && brandSnomedId.equals(tn.getSnomedConceptId())) {
   		             			 				selected = "selected=\"selected\"";
   		             			 			}
   	             						}
   	             						if(foundByLotNumber) {
   		             			 			String brandSnomedId = brandName.getSnomedConceptId();
   		             			 			if(brandSnomedId != null && brandSnomedId.equals(tn.getSnomedConceptId())) {
   		             			 				selected = "selected=\"selected\"";
   		             			 			}
   	             						}
   	             						if(tnList.size()==1) {
   	             						   	     selected = "selected=\"selected\"";
                                        }

   	             			 			%><option value="<%=tn.getSnomedConceptId()%>" <%=selected%>><%=tn.getPicklistName() %></option><%
   	             			 		}
   	             			 	%>

   	             			 </select>
                                <%
                                        if(tnList.size()==1) {
   	             						   	     %><script>changeCVCName();</script><%
                                        }
                                %>


   	             				 <span id="unknownName" style="display:block"><label for="name">Name</label> <input type="text" id="name" name="name" value="<%=str((extraData.get("name")),"")%>"/> <br/><br/></span>
             		<%
             				} else {
             					%>  <label for="name">Name:</label> <input type="text" id="name" name="name" value="<%=str((extraData.get("name")),"")%>"/> <br/> <%
             				}

             			 } else {
             			 	%>  <label for="name">Name:</label> <input type="text" id="name" name="name" value="<%=str((extraData.get("name")),prevention)%>"/> <br/>

             			<% } %>

                        <br>

             			 <label for="location">Location:</label>

             			 <select name="location" id="location" onChange="changeSite(this)">
             			 	 <option value=""></option>
                         	    <%
                         	    	String locationSelected = " selected=\"selected\" ";
                         	    	LookupListDao lookupListDao = SpringUtils.getBean(LookupListDao.class);
                         	    	LookupList ll = lookupListDao.findByName("AnatomicalSite");
                         	    	if(ll != null) {
                         	    		for(LookupListItem lli : ll.getItems()) {
                         	    			%>
                         	    				<option value="<%=lli.getValue() %>" <%=lli.getValue().equals(str((extraData.get("location")),"")) ? locationSelected : "" %>><%=lli.getLabel() %></option>
                         	    			<%
                         	    		}
                         	    	} else {
                         	    %>
                         		<option value="Superior Deltoid Lt" <%="Superior Deltoid Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Superior Deltoid Lt</option>
                         		<option value="Inferior Deltoid Lt" <%="Inferior Deltoid Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Inferior Deltoid Lt</option>
                         		<option value="Anterolateral Thigh Lt" <%="Anterolateral Thigh Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Anterolateral Thigh Lt</option>
                         		<option value="Gluteal Lt" <%="Gluteal Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Gluteal Lt</option>
                         		<option value="Superior Deltoid Rt" <%="Superior Deltoid Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Superior Deltoid Rt</option>
                         		<option value="Inferior Deltoid Rt" <%="Inferior Deltoid Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Inferior Deltoid Rt</option>
                         		<option value="Anterolateral Thigh Rt" <%="Anterolateral Thigh Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Anterolateral Thigh Rt</option>
                         		<option value="Gluteal Rt" <%="Gluteal Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Gluteal Rt</option>
                         		<option value="Arm Lt" <%="Arm Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Arm Lt</option>
                         		<option value="Arm Rt" <%="Arm Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Arm Rt</option>
                         		<option value="Unknown" <%="Unknown".equals(str((extraData.get("location")),"")) || extraData.get("location") == null ? locationSelected : "" %>>Unknown</option>
                         		<option value="Mouth" <%="Mouth".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Mouth</option>
                         		<option value="Deltoid Lt" <%="Deltoid Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Deltoid Lt</option>
                         		<option value="Deltoid Rt" <%="Deltoid Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Deltoid Rt</option>
                         		<option value="Naris Lt" <%="Naris Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Naris Lt</option>
                         		<option value="Naris Rt" <%="Naris Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Naris Rt</option>
                         		<option value="Forearm Lt" <%="Forearm Lt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Forearm Lt</option>
                         		<option value="Forearm Rt" <%="Forearm Rt".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Forearm Rt</option>
                         		<option value="Other" <%="Other".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Other</option>
                         		<option value="Nares (Lt and Rt)" <%="Nares (Lt and Rt)".equals(str((extraData.get("location")),"")) ? locationSelected : "" %>>Nares (Lt and Rt)</option>
                         		<% } %>
             			 </select>

             			 <%
             			 	String locationDisplay = "none";
             			 	if("Other".equals(str(extraData.get("location"),""))) {
             			 		locationDisplay="block";
             			 	}
             			 %>
             			 <br>
             			 	<div id="locationDiv" style="display:<%=locationDisplay%>">
             				<label for="location2">Specify Location:</label>

             			 <input type="text" name="location2" id="location2" value="<%=str((extraData.get("location2")),"")%>"/>
             			 </div>

             			 <br/>
                         <label for="route">Route:</label>

                         	<select name="route" id="route">
                         	    <option value=""></option>
                         	    <%
                         	    	String routeSelected = " selected=\"selected\" ";

                    	    	ll = lookupListDao.findByName("RouteOfAdmin");
                    	    	if(ll != null) {
                    	    		for(LookupListItem lli : ll.getItems()) {
                    	    			%>
                    	    				<option value="<%=lli.getValue() %>" <%=lli.getValue().equals(str((extraData.get("route")),"")) ? routeSelected : "" %>><%=lli.getLabel() %></option>
                    	    			<%
                    	    		}
                    	    	} else {
                         	    %>
                         		<option value="ID" <%="ID".equals(str((extraData.get("route")),"")) ? routeSelected : "" %>>Intradermal: ID</option>
                         		<option value="IM" <%="IM".equals(str((extraData.get("route")),"")) ? routeSelected : "" %>>Intramuscular: IM</option>
                         		<option value="IN" <%="IN".equals(str((extraData.get("route")),"")) ? routeSelected : "" %>>Intranasal: IN</option>
                         		<option value="PO" <%="PO".equals(str((extraData.get("route")),"")) ? routeSelected : "" %>>Oral: PO</option>
                         		<option value="SC" <%="SC".equals(str((extraData.get("route")),"")) ? routeSelected : "" %>>Subcutaneous: SC</option>
                         		<% } %>
                         	</select>
                         	<br/>

                         	<label for="route">DIN:</label>
                         	<input type="text" name="din" id="din" value="<%=str((extraData.get("din")),"")%>"/>
             			 	<br/>
                         	<%
                         		String dose = str((extraData.get("dose")),"");
                         		String d1 = "";
                         		String d2 = "";
                         		if(dose.split(" ").length == 2) {
                         			String d3 = dose.split(" ")[1];
                         			if(!d3.equals("mL") && !d3.equals("mg") && !d3.equals("g") && !d3.equals("capsule") && !d3.equals("vial") ) {
                         				d1 = dose;
                         			} else {
                         				d1 = dose.split(" ")[0];
                             			d2 = dose.split(" ")[1];
                         			}
                         		} else {
                         			d1 = dose;
                         		}

                         		if("".equals(dose)) {
                         			d2 = "mL";
                         		}
                         	%>
                         	<br/>
                         <label>Typical Dose: </label><span id="typicalDose"></span><br/><br/>
                         <label for="dose">Dose:</label> <input type="text" name="dose"  id="dose" value="<%=d1%>"/>
                         <br>
                          <label for="doseUnit">Dose Unit:</label>
                          <select name="doseUnit" id="doseUnit">
							<option value="" <%="".equals(d2)?"selected=\"selected\" ":"" %>></option>
							<option value="mL" <%="mL".equals(d2)?"selected=\"selected\" ":"" %>>mL</option>
							<option value="mg" <%="mg".equals(d2)?"selected=\"selected\" ":"" %>>mg</option>
							<option value="g" <%="g".equals(d2)?"selected=\"selected\" ":"" %>>g</option>
							<option value="capsule" <%="capsule".equals(d2)?"selected=\"selected\" ":"" %>>capsule</option>
							<option value="vial" <%="vial".equals(d2)?"selected=\"selected\" ":"" %>>vial</option>

                          </select>

                          <br/>
                        <%if(!isCvc) { %>
                         <label for="lot">Lot:</label>  <input type="text" name="lot" id="lot" value="<%=str(lot,"")%>" />
                        <select onchange="javascript:updateLotNr(this);" id="lotDrop" name="lotItem" >
                             <%for(String lotnr:lotNrList) {
							 %>
                               <option value="<%=lotnr%>" <%= ( lotnr.equals(lot) ? " selected" : "" ) %>><%=lotnr%> </option>
                             <%}%>
                             <option value="-1"  >Other</option>
                         </select><br/>
                         <%} else { %>
                         <div id="cvcLotDiv">
                         <label for="cvcLot" id="lotLabel" style="display:none;">Lot Select:</label>
                          <select onchange="updateCvcLot();" id="cvcLot" name="cvcLot" style="display:none;"></select>
                         </div>
                         <label for="lot">Lot:</label>
                          <input type="text" name="lot" id="lot" value="<%=str(lot,"")%>" style="display:block" />

                         <label for="expiryDate">Expiry Date:</label> <input type="text" name="expiryDate" id="expiryDate"  value="<%=str((extraData.get("expiryDate")),"")%>"/><br/>
                         <% } %>
                         <label for="manufacture">Manufacture:</label> <input type="text" name="manufacture" id="manufacture"  value="<%=str((extraData.get("manufacture")),"")%>"/><br/>
                         <% if(generic != null){ %>
                         <label for="shelfStatus">Status:</label> <span name="shelfStatus" id="shelfStatus"  ></span><%=(generic.getShelfStatus()==null?"n/a":generic.getShelfStatus()) %><br/> <%--str((extraData.get("status")),"")--%>
                         <% } %>

                   </fieldset>
                   <fieldset >
                      <legend >Comments</legend>
                      <textarea class="span8" name="comments" ><%=str((extraData.get("comments")),"")%></textarea>
                   </fieldset>
               </div>
               <script type="text/javascript">
                  hideExtraName(document.getElementById('providerDrop'));
               </script>
               <script type="text/javascript">
               hideLotDrop(document.getElementById('lotDrop'));
               </script>
               <%} else if(layoutType.equals("h1n1")) {%>
               <div class="prevention span8">
                   <fieldset>
                      <legend>Prevention : <%=prevention%></legend>
                         <div>
                            <input name="given" type="radio" value="given"      <%=checked(completed,"0")%>>Completed</input><br/>
                            <input name="given" type="radio" value="given_ext"  <%=checked(completed,"3")%>>Completed externally</input><br/>
                            <input name="given" type="radio" value="refused"    <%=checked(completed,"1")%>>Refused</input><br/>
                            <input name="given" type="radio" value="ineligible" <%=checked(completed,"2")%>>Ineligible</input>
                         </div>
                         <div>&nbsp;</div>
                         <div style="margin-left:30px;">
                            <label for="prevDate" class="fields" >Date:</label><span class="input-append"><input type="text" name="prevDate" id="prevDate" value="<%=prevDate%>" style="width:167px;"> <a id="date"><img title="Calendar" class="add-on" src="../images/cal.gif" alt="Calendar" ></a></span><br>
                            <label for="provider" class="fields">Provider:</label> <input type="text" name="providerName" id="providerName" value="<%=providerName%>"/>
                                  <select onchange="javascript:hideExtraName(this);" id="providerDrop" name="provider">
                                      <%for (int i=0; i < providers.size(); i++) { %>
                                           <option value="<%= (String) ((ArrayList) providers.get(i)).get(0) %>"
		<%= ( ((String) ((ArrayList) providers.get(i)).get(0)).equals(provider) ? " selected" : "" ) %>>
    <%=Encode.forHtmlContent((String) ((ArrayList) providers.get(i)).get(2)+", "+(String) ((ArrayList) providers.get(i)).get(1)) %></option>
                                            </option>
                                      <%}%>
                                      <option value="-1" <%= ( "-1".equals(provider) ? " selected" : "" ) %> >Other</option>
                                  </select>
                                  <br/>
                             <label for="creator" class="fields" >Creator:</label> <input type="text" name="creator" value="<%=creatorName%>" readonly/> <br/>
                         </div>
                   </fieldset>
                   <fieldset>
                      <legend >Result</legend>
                         <label for="location">Location:</label> <input type="text" name="location" value="<%=str((extraData.get("location")),"")%>"/> <br/>
                          <label for="location">Other Location:</label> <input type="text" name="location2" value="<%=str((extraData.get("location2")),"")%>"/> <br/>
                         <label for="route">Route:</label> <input type="text" name="route"   value="<%=str((extraData.get("route")),"")%>"/><br/>
                         <label for="dose">Dose:</label> <input type="text" name="dose"  value="<%=str((extraData.get("dose")),"")%>"/><br/>
			 <label for="dose1">Dose 1:</label> <input type="checkbox" name="dose1" value="true" <%=checked(str((extraData.get("dose1")),""),"true")%>/><br/>
                         <label for="dose2">Dose 2:</label> <input type="checkbox" name="dose2"  value="true" <%=checked(str((extraData.get("dose2")),""),"true")%>/><br/>
                         <label for="lot">Lot:</label> <input type="text" name="lot"  value="<%=str((extraData.get("lot")),"")%>"/><br/>
                         <label for="manufacture">Manufacture:</label> <input type="text" name="manufacture"   value="<%=str((extraData.get("manufacture")),"")%>"/><br/>
                   </fieldset>
                   <fieldset>
                       <legend>Info</legend>
                       <% String gender = genders.get(demoInfo[2]);
                          if( gender == null ) {
                              gender = genders.get("U");
                          }

                       %>
                         <label for="gender">Gender:</label> <input type="text" name="gender" readonly value="<%=gender%>"/> <br/>
                         <label for="age">Age:</label> <input type="text" name="age" readonly value="<%=age%>"/><br/>
                         <label for="chronic">Chronic Condition:</label>
                         <select name="chronic">
                             <option value="false">No</option>
                             <option value="true" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("true") ? "selected" : "" %> >Yes</option>
                             <option value="cardiac disorder" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("cardiac disorder") ? "selected" : "" %> >Cardiac Disorder</option>
                             <option value="diabetes" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("diabetes") ? "selected" : "" %> >Diabetes</option>
                             <option value="cancer" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("cancer") ? "selected" : "" %> >Cancer</option>
                             <option value="immunodeficiency" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("immunodeficiency") ? "selected" : "" %> >Immunodeficiency</option>
                             <option value="immunosuppression" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("immunosuppression") ? "selected" : "" %> >Immunosuppression</option>
                             <option value="renal disease" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("renal disease") ? "selected" : "" %> >Renal Disease</option>
                             <option value="anemia or hemoglobinopathy" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("anemia or hemoglobinopathy") ? "selected" : "" %> >Anemia or Hemoglobinopathy</option>
                             <option value="compromised management of respiratory secretions" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("compromised management of respiratory secretions") ? "selected" : "" %> >Compromised Management of Respiratory Secretions</option>
                             <option value="Children/Adolescent with Longterm Acetylsalicylic Acid" <%= str((extraData.get("chronic")),"").equalsIgnoreCase("Children/Adolescent with Longterm Acetylsalicylic Acid") ? "selected" : "" %> >Children/Adolescent with Longterm Acetylsalicylic Acid</option>
                         </select><br/>
                         <label for="pregnant">Pregnant:</label> <input type="checkbox" name="pregnant"  value="true" <%=checked(str((extraData.get("pregnant")),""),"true")%>/><br/>
                         <label for="remote">Remote Setting:</label> <input type="checkbox" name="remote"  value="true" <%=checked(str((extraData.get("remote")),""),"true")%>/><br/>
                         <label for="healthcareworker">Health Care Worker:</label>
                         <select name="healthcareworker">
                             <option value="false">No</option>
                             <option value="true" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("true") ? "selected" : "" %> >Yes</option>
                             <option value="acute care" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("acute care") ? "selected" : "" %> >Acute Care</option>
                             <option value="chronic care" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("chronic care") ? "selected" : "" %> >Chronic Care</option>
                             <option value="community care" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("community care") ? "selected" : "" %> >Ambulatory/Community Care</option>
                             <option value="emergency medical services" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("emergency medical services") ? "selected" : "" %> >Emergency Medical Services</option>
                             <option value="laboratory" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("laboratory") ? "selected" : "" %> >Laboratory</option>
                             <option value="public health" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("public health") ? "selected" : "" %> >Public Health</option>
                             <option value="pharmacy" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("pharmacy") ? "selected" : "" %> >Pharmacy</option>
                             <option value="vaccine manufacturer" <%= str((extraData.get("healthcareworker")),"").equalsIgnoreCase("vaccine manufacturer") ? "selected" : "" %> >Vaccine Mfr</option>
                         </select><br/>

                         <label for="householdcontact">Household Contact or Care Provider:</label> <input type="checkbox" name="householdcontact" value="true" <%=checked(str((extraData.get("householdcontact")),""),"true")%>/><br/>
                         <%
                            boolean bothfirstresponders = false;
                            if( str((extraData.get("firstresponder")),"").equalsIgnoreCase("true")) {
                                bothfirstresponders = true;
                           }

                         %>
                         <label for="firstresponderpolice">First Responder Police:</label> <input type="checkbox" name="firstresponderpolice" value="true" <%=bothfirstresponders == true ? "checked" : checked(str((extraData.get("firstresponderpolice")),""),"true")%>/><br/>
                         <label for="firstresponderfire">First Responder Fire:</label> <input type="checkbox" name="firstresponderfire" value="true" <%=bothfirstresponders == true ? "checked" : checked(str((extraData.get("firstresponderfire")),""),"true")%>/><br/>
                         <label for="swineworker">Swine Worker:</label> <input type="checkbox" name="swineworker" value="true" <%=checked(str((extraData.get("swineworker")),""),"true")%>/><br/>
                         <label for="poultryworker">Poultry Worker:</label> <input type="checkbox" name="poultryworker" value="true" <%=checked(str((extraData.get("poultryworker")),""),"true")%>/><br/>
                         <label for="firstnations">First Nations:</label> <input type="checkbox" name="firstnations" value="true" <%=checked(str((extraData.get("firstnations")),""),"true")%>/><br/>
                   </fieldset>
                   <fieldset >
                      <legend >Comments</legend>
                      <textarea name="comments" class="span8"><%=str((extraData.get("comments")),"")%></textarea>
                   </fieldset>
               </div>
               <script type="text/javascript">
                  hideExtraName(document.getElementById('providerDrop'));
               </script>
               <%}else if(layoutType.equals("PAPMAM")){/*next layout type*/%>
               <div class="prevention span8">
                   <fieldset>
                      <legend>Prevention : <%=prevention%></legend>
                         <div>
                            <input name="given" type="radio" value="given"     <%=checked(completed,"0")%>>Completed</input><br/>
                            <input name="given" type="radio" value="given_ext"  <%=checked(completed,"3")%>>Completed externally</input><br/>
                            <input name="given" type="radio" value="refused"    <%=checked(completed,"1")%>>Refused</input><br/>
                            <input name="given" type="radio" value="ineligible" <%=checked(completed,"2")%>>Ineligible</input>
                         </div>
                         <div>&nbsp;</div>
                         <div style="margin-left:30px;" class="span8">
                            <label for="prevDate" class="fields" >Date:</label><span class="input-append"><input type="text" name="prevDate" id="prevDate" value="<%=prevDate%>" style="width:167px;"> <a id="date"><img title="Calendar" class="add-on" src="../images/cal.gif" alt="Calendar" ></a></span><br>
                            <label for="provider" class="fields">Provider:</label> <input type="text" name="providerName" id="providerName"/>
                                  <select onchange="javascript:hideExtraName(this);" id="providerDrop" name="provider">
                                      <%for (int i=0; i < providers.size(); i++) { %>
                                           <option value="<%= (String) ((ArrayList) providers.get(i)).get(0) %>"
		<%= ( ((String) ((ArrayList) providers.get(i)).get(0)).equals(provider) ? " selected" : "" ) %>>
    <%=Encode.forHtmlContent((String) ((ArrayList) providers.get(i)).get(2)+", "+(String) ((ArrayList) providers.get(i)).get(1)) %></option>
                                            </option>
                                      <%}%>
                                      <option value="-1" >Other</option>
                                  </select>
                                  <br/>
                                  <label for="creator" class="fields" >Creator:</label> <input type="text" name="creator" value="<%=creatorName%>" readonly/> <br/>
                         </div>
                   </fieldset>
                   <fieldset >
                      <legend >Result</legend>
                      <% if (extraData.get("result") == null ){ extraData.put("result","pending");} %>
                      <%=str(prevResultDesc,"")%><br />
                      <input type="radio" name="result" value="pending" <%=checked( (extraData.get("result")) ,"pending")%> >Pending</input><br/>
                      <input type="radio" name="result" value="normal"  <%=checked((extraData.get("result")),"normal")%> >Normal</input><br/>
                      <input type="radio" name="result" value="abnormal" <%=checked((extraData.get("result")),"abnormal")%> >Abnormal</input><br/>
                      <input type="radio" name="result" value="other" <%=checked((extraData.get("result")),"other")%> >Other</input> &nbsp; &nbsp; Reason: <input type="text" name="reason" value="<%=str((extraData.get("reason")),"")%>"/>
                   </fieldset>
                   <fieldset >
                      <legend >Comments</legend>
                      <textarea name="comments" class="span8"><%=str((extraData.get("comments")),"")%></textarea>
                   </fieldset>
               </div>
               <script type="text/javascript">
                  hideExtraName(document.getElementById('providerDrop'));
               </script>
               <%} else if(layoutType.equals("history")) {%>
               		 <div class="prevention span8">
                   <fieldset>
                      <legend>Prevention : <%=prevention%></legend>
                         <div style="float:left;">
                            <input name="given" type="radio" value="yes"      <%=checked(completed,"0")%>>Yes</input><br/>
                            <input name="given" type="radio" value="never"    <%=checked(completed,"1")%>>Never</input><br/>
                            <input name="given" type="radio" value="previous" <%=checked(completed,"2")%>>Previous</input>
                         </div>
                         <div style="float:left;margin-left:30px;">
                            <label for="prevDate" class="fields" >Date:</label><span class="input-append"><input type="text" name="prevDate" id="prevDate" value="<%=prevDate%>" style="width:167px;"> <a id="date"><img title="Calendar" class="add-on" src="../images/cal.gif" alt="Calendar" ></a></span><br>
                            <label for="provider" class="fields">Provider:</label> <input type="hidden" name="providerName" id="providerName" value="<%=providerName%>"/>
                                  <select onchange="javascript:hideExtraName(this);" id="providerDrop" name="provider">
                                      <%for (int i=0; i < providers.size(); i++) { %>
                                           <option value="<%= (String) ((ArrayList) providers.get(i)).get(0) %>"
		<%= ( ((String) ((ArrayList) providers.get(i)).get(0)).equals(provider) ? " selected" : "" ) %>>
    <%=Encode.forHtmlContent((String) ((ArrayList) providers.get(i)).get(2)+", "+(String) ((ArrayList) providers.get(i)).get(1)) %></option>
                                            </option>
                                      <%}%>
                                      <option value="-1" <%= ( "-1".equals(provider) ? " selected" : "" ) %> >Other</option>
                                  </select>
                         </div>
                   </fieldset>
                   <fieldset >
                      <legend >Comments</legend>
                      <textarea name="comments" class="span8"><%=str((extraData.get("comments")),"")%></textarea>
                   </fieldset>
                   </div>
               <%} %>


               <div class="prevention span8">
                   <fieldset>
                      <legend><a onclick="showHideNextDate('nextDateDiv','nextDate','nexerWarn')" href="javascript: function myFunction() {return false; }"   >Set Next Date</a></legend>
                        <div id="nextDateDiv" style="display:none;">
                         <div>
                            <label for="nextDate" >Next Date:</label>
<span class="input-append"><input type="text" name="nextDate" id="nextDate" value="<%=nextDate%>" style="width:167px;"> <a id="nextDateCal"><img title="Calendar" class="add-on" src="../images/cal.gif" alt="Calendar" ></a></span>
                         </div>
                         <div>
                            <label for="neverWarn">Never Remind:</label><input type="checkbox" name="neverWarn" id="neverWarn" value="neverRemind" onchange="disableifchecked('neverWarn','nextDate');"  <%=completed(never)%>/><br><label for="neverReason">Never Reason:</label><input type="text" name="neverReason" value="<%=str((extraData.get("neverReason")),"")%>"/>
                         </div>
                        </div>
                   </fieldset>
               </div>
               <br/>
               <input type="submit" class="btn btn-primary" value="Save" name="action"><!-- cvcActiveCall ?  <%= CanadianVaccineCatalogueManager2.getCVCActive(creationDate)%>  <%= creationDate%> -->
               <%
   					ConsentDao consentDao = SpringUtils.getBean(ConsentDao.class);
   					Consent ispaConsent =  consentDao.findByDemographicAndConsentType(Integer.parseInt(demographic_no), "dhir_ispa_consent");
   					Consent nonIspaConsent =  consentDao.findByDemographicAndConsentType(Integer.parseInt(demographic_no), "dhir_non_ispa_consent");

   					boolean ispa = Boolean.valueOf((String)prevHash.get("ispa"));

   					boolean isSSOLoggedIn = session.getAttribute("oneIdEmail") != null;
   					boolean hasIspaConsent = ispaConsent != null && !ispaConsent.isOptout();
   					boolean hasNonIspaConsent = nonIspaConsent != null && !nonIspaConsent.isOptout();

   					//if(dhirEnabled &&  isSSOLoggedIn) {
   					//	if((ispa && hasIspaConsent) || (!ispa && hasNonIspaConsent)) {

   					if("ON".equalsIgnoreCase(demoObject.getHcType()) && CanadianVaccineCatalogueManager2.getCVCActive(creationDate)){
               %>
               <script type="text/javascript">
               	function validateSubmitSave() {
            	    		var givenVal = document.getElementById('given');
            	    		var givenExtVal = document.getElementById('givenExt');
            	    		// || givenExtVal.checked != true
            	    		console.log("givenVal",givenVal.checked);
            	    		if( !(givenVal.checked == true || givenExtVal.checked == true)){ //if(givenVal.checked != true){   if given is not true  need it to be if given is true or given Ext is true
            	    			alert("Only Completed Immunizations can be submitted to the DHIR");
            	    			return false;
            	    		}
            	    		/*var prevDateVal = document.getElementById('prevDate');
            	    		console.log("prevDate",prevDate,prevDate.value.length);
            	    		if(prevDate.value.length != 16){
            	    			alert("Partial Dates are not supported by the DHIR. This Immunization can not be submitted.")
            	    			return false;
            	    		}
            	    		*/
            	   		return true;
               	}
               </script>
            <% if(dhirEnabled){ %>
               <input type="submit" value="Save & Submit" name="action" onclick="return validateSubmitSave();" <%=(dhirEnabled) ? "title='Send to DHIR'" : "disabled title='DHIR not enabled' disabled" %> >
            <% } %>
                <% }

   					//}

   					%>
               <% if ( id != null ) { %>
               <input type="submit" class="btn" name="delete" value="Delete">
               <% } %>
               </html:form>
               <% } %>

    <%if(prevHash != null) { %>
<script type="text/javascript">
Calendar.setup( { inputField : "prevDate", ifFormat : "%Y-%m-%d %H:%M", showsTime :true, button : "date", singleClick : true, step : 1 } );
Calendar.setup( { inputField : "nextDate", ifFormat : "%Y-%m-%d", showsTime :false, button : "nextDateCal", singleClick : true, step : 1 } );
</script>
<% } %>
    </div> <!-- "span8" -->
</div> <!-- container-fluid well -->
</div> <!-- "span12" -->
</body>
</html:html>
<%!

String completed(boolean b){
    String ret ="";
    if(b){ret="checked";}
    return ret;
    }

String refused(boolean b){
    String ret ="";
    if(!b){ret="checked";}
    return ret;
    }

String str(String first,String second){
    String ret = "";
    if(first != null){
       ret = first;
    }else if ( second != null){
       ret = second;
    }
    return StringEscapeUtils.escapeHtml(ret);
  }

String checked(String first,String second){
    String ret = "";
    if(first != null && second != null){
       if(first.equals(second)){
           ret = "checked";
       }
    }
    return ret;
  }

  Date parseDate(String dt) {
	SimpleDateFormat fmt = null;

	if(dt.length() == 4) {
		fmt = new SimpleDateFormat("yyyy");
	} else if(dt.length() == 7) {
		fmt = new SimpleDateFormat("yyyy-MM");
	} else if(dt.length() == 10) {
		fmt = new SimpleDateFormat("yyyy-MM-dd");
	} else if(dt.length() == 16) {
		fmt = new SimpleDateFormat("yyyy-MM-dd HH:mm");
	}

	if(fmt != null) {
		try {
			return fmt.parse(dt);
		}catch(ParseException e) {
			return null;
		}
	}
	return null;
  }
%>