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
<%@ page import="java.sql.*"%>
<%@ page import="java.util.*"%>

<%@ page import="org.apache.commons.beanutils.BeanUtils"%>
<%@ page import="org.apache.commons.lang.StringUtils"%>

<%@ page import="org.springframework.web.context.support.WebApplicationContextUtils"%>

<%@ page import="org.oscarehr.common.model.LookupListItem"%>
<%@ page import="org.oscarehr.common.model.LookupList"%>
<%@ page import="org.oscarehr.managers.LookupListManager"%>
<%@ page import="org.oscarehr.common.Gender" %>
<%@ page import="org.oscarehr.common.dao.ClinicNbrDao"%>
<%@ page import="org.oscarehr.common.model.ProviderData"%>
<%@ page import="org.oscarehr.common.dao.ProviderDataDao"%>
<%@ page import="org.oscarehr.common.dao.SecurityDao" %>
<%@ page import="org.oscarehr.common.model.Security" %>
<%@ page import="org.oscarehr.common.dao.UserPropertyDAO"%>
<%@ page import="org.oscarehr.common.model.UserProperty"%>
<%@ page import="org.oscarehr.common.model.ClinicNbr"%>
<%@ page import="org.oscarehr.common.model.ProviderArchive"%>
<%@ page import="org.oscarehr.common.dao.ProviderArchiveDao"%>
<%@ page import="org.oscarehr.common.dao.SiteDao"%>
<%@ page import="org.oscarehr.common.model.Site"%>
<%@ page import="org.oscarehr.PMmodule.dao.ProviderDao"%>
<%@ page import="org.oscarehr.common.model.ProviderSite"%>
<%@ page import="org.oscarehr.common.model.ProviderSitePK"%>
<%@ page import="org.oscarehr.common.dao.ProviderSiteDao"%>
<%@ page import="org.oscarehr.common.model.Provider"%>
<%@ page import="org.oscarehr.util.LoggedInInfo" %>
<%@ page import="org.oscarehr.util.SpringUtils"%>

<%@ page import="oscar.*"%>
<%@ page import="oscar.oscarDB.*"%>
<%@ page import="oscar.OscarProperties"%>
<%@ page import="oscar.SxmlMisc"%>
<%@ page import="oscar.oscarProvider.data.ProviderBillCenter"%>
<%@ page import="oscar.login.*"%>
<%@ page import="oscar.log.LogAction" %>
<%@ page import="oscar.log.LogConst" %>
<%@ page import="oscar.util.ChangedField" %>
<%@ page import="oscar.util.*" %>

<%@ page import="org.owasp.encoder.Encode" %>

<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean"%>
<%@ taglib uri="/WEB-INF/struts-html.tld" prefix="html"%>
<%@ taglib uri="/WEB-INF/caisi-tag.tld" prefix="caisi"%>
<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%
      String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");
     boolean authed=true;
%>
<security:oscarSec roleName="<%=roleName$%>" objectName="_admin,_admin.userAdmin" rights="r" reverse="<%=true%>">
	<%authed=false; %>
	<%response.sendRedirect(request.getContextPath() + "/securityError.jsp?type=_admin&type=_admin.userAdmin");%>
</security:oscarSec>
<%
	if(!authed) {
		return;
	}
%>

<%
	java.util.Locale vLocale =(java.util.Locale)session.getAttribute(org.apache.struts.Globals.LOCALE_KEY);
	ProviderDataDao providerDao = SpringUtils.getBean(ProviderDataDao.class);
	ProviderDao providerDao2 = (ProviderDao)SpringUtils.getBean("providerDao");
	ProviderSiteDao providerSiteDao = SpringUtils.getBean(ProviderSiteDao.class);
%>

<html:html locale="true">
<head>
<link href="<%=request.getContextPath() %>/css/bootstrap.css" rel="stylesheet" type="text/css">
<link href="<%=request.getContextPath() %>/css/bootstrap-responsive.css" rel="stylesheet" type="text/css">

<script type="text/javascript" src="<%=request.getContextPath()%>/js/jquery-1.12.3.js"></script>
        <script src="<%=request.getContextPath() %>/library/jquery/jquery-migrate-1.4.1.js"></script>
<script src="<%=request.getContextPath() %>/js/jqBootstrapValidation-1.3.7.min.js"></script>
<script type="text/javascript" src="<%=request.getContextPath()%>/js/global.js"></script>

<title><bean:message key="admin.providerupdateprovider.title" /></title>
   <script>

     $(function () { $("input,textarea,select").jqBootstrapValidation(
                    {
                        preventSubmit: true,
                        submitError: function($form, event, errors) {
                            // Here I do nothing, but you could do something like display 
                            // the error messages to the user, log, etc.
                            event.preventDefault();
                        },

                        submitSuccess: function($form, event) {
	                    
                           // aSubmit();
                        },
                        filter: function() {
                            return $(this).is(":visible");
                        },

                    }
                );

                $("a[data-toggle=\"tab\"]").on( "click", function(e) {
                    e.preventDefault();
                    $(this).tab("show");
                });

            });          

</script>

<script LANGUAGE="JavaScript">


jQuery(document).ready( function() {
        jQuery("#provider_type").on("change",function() {
            
            if( jQuery("#provider_type").val() == "resident") {                
                jQuery(".supervisor").slideDown(600);
                jQuery("#supervisor").trigger( "focus" );
               
            }
            else {
                if( jQuery(".supervisor").is(":visible") ) {
                    jQuery(".supervisor").slideUp(600);
                    jQuery("#supervisor").val("");
                }
            }
        }
        )
        
    }
        
        
 ); 
function formatPhone(obj) {
    // formats to North American xxx-xxx-xxxx standard numbers that are exactly 10 digits long
    var x=obj.value;
    //strip the formatting to get the numbers
    var matches = x.match(/\d+/g);
    if (!matches || x.substring(0,1) == "+"){
        // don't do anything if non numberic and or international format
        return;
    }
    var num = '';
    for (var i=0; i< matches.length; i++) {
        console.log(matches[i]);
        num = num + matches[i];
    }
    if (num.length == 10){
        obj.value = num.substring(0,3)+"-"+num.substring(3,6) + "-"+ num.substring(6);
    } else {
        if (num.length == 11 && x.substring(0,1) == "1"){
            obj.value = num.substring(0,1)+"-"+num.substring(1,4) + "-"+ num.substring(4,7)+ "-"+ num.substring(7);
        } 
    }
}
</script>

</head>

<%
    String curProvider_no = (String) session.getAttribute("user");
    List<Integer> siteIDs = new ArrayList<Integer>();
    boolean isSiteAccessPrivacy=false;
%>

<security:oscarSec objectName="_site_access_privacy"
	roleName="<%=roleName$%>" rights="r" reverse="false">
<%
	isSiteAccessPrivacy = true;

	
	List<ProviderSite> psList = providerSiteDao.findByProviderNo(curProvider_no);
	for (ProviderSite pSite : psList) {
		siteIDs.add(pSite.getId().getSiteId());
	}

%>
</security:oscarSec>

<body onLoad="$('#contact_div').hide(); " topmargin="0" leftmargin="0" rightmargin="0">
<%
	String keyword = request.getParameter("keyword");


	ProviderData provider = providerDao.findByProviderNo(keyword);
	
	//SecurityDao securityDao = (SecurityDao) SpringUtils.getBean("securityDao");
	//List<Security>  results = securityDao.findByProviderNo(provider.getId());
	//Security security = null;
	//if (results.size() > 0) security = results.get(0);
	
	if(provider == null) {
	    out.println("failed");
	} 
	else {
    
    String provider_no2 = provider.getId();
%>



<div width="100%">
    <div id="header"><H4><bean:message
			key="admin.providerupdateprovider.description" />&nbsp;<%= Encode.forHtmlAttribute(provider_no2) %></H4>
    </div>
</div>


<%
String sName = request.getParameter("last_name");
    if ( sName != null && sName != "" ){

  ProviderBillCenter billCenter = new ProviderBillCenter();
  billCenter.updateBillCenter(request.getParameter("provider_no"),request.getParameter("billcenter"));



//multi-office provide id formalize check, can be turn off on properties multioffice.formalize.provider.id
  boolean isProviderFormalize = true;
  String  errMsgProviderFormalize = "admin.provideraddrecord.msgAdditionFailure";
  Integer min_value = 0;
  Integer max_value = 0;

  if (org.oscarehr.common.IsPropertiesOn.isProviderFormalizeEnable()) {

  	String StrProviderId = request.getParameter("provider_no");
  	OscarProperties props = OscarProperties.getInstance();

  	String[] provider_sites = {};

  	// get provider id ranger
  	if (request.getParameter("provider_type").equalsIgnoreCase("doctor")) {
  		//provider is doctor, get provider id range from Property
  		min_value = new Integer(props.getProperty("multioffice.formalize.doctor.minimum.provider.id", ""));
  		max_value = new Integer(props.getProperty("multioffice.formalize.doctor.maximum.provider.id", ""));
  	}
  	else {
  		//non-doctor role
  		provider_sites = request.getParameterValues("sites");
  		provider_sites = (provider_sites == null ? new String[] {} : provider_sites);

  		if (provider_sites.length > 1) {
  			//non-doctor can only have one site
  			isProviderFormalize = false;
  			errMsgProviderFormalize = "admin.provideraddrecord.msgFormalizeProviderIdMultiSiteFailure";
  		}
  		else {
  			if (provider_sites.length == 1) {
  				//get provider id range from site
  				String provider_site_id =  provider_sites[0];
  				SiteDao siteDao = (SiteDao)WebApplicationContextUtils.getWebApplicationContext(application).getBean("siteDao");
  				Site provider_site = siteDao.getById(new Integer(provider_site_id));
  				min_value = provider_site.getProviderIdFrom();
  				max_value = provider_site.getProviderIdTo();
  			}
  		}
  	}

  	if (isProviderFormalize) {
  		try {
  			    Integer providerId = Integer.parseInt(StrProviderId);

  			    if (request.getParameter("provider_type").equalsIgnoreCase("doctor") ||  provider_sites.length == 1) {
  				    if  (!(providerId >= min_value && providerId <=max_value)) {
  				    	// providerId is not in the range
  						isProviderFormalize = false;
  						errMsgProviderFormalize = "admin.provideraddrecord.msgFormalizeProviderIdFailure";
  				    }

  			    }

  		} catch(NumberFormatException e) {
  			//providerId is not a number
  			isProviderFormalize = false;
  			errMsgProviderFormalize = "admin.provideraddrecord.msgFormalizeProviderIdFailure";
  		}
  	}

  }

  if (!org.oscarehr.common.IsPropertiesOn.isProviderFormalizeEnable() || isProviderFormalize) {
    ProviderArchiveDao providerArchiveDao = (ProviderArchiveDao)SpringUtils.getBean("providerArchiveDao");
	Provider provider2 = providerDao2.getProvider(request.getParameter("provider_no"));
	ProviderArchive pa = new ProviderArchive();
	BeanUtils.copyProperties(pa, provider2);
	pa.setId(null);
	providerArchiveDao.persist(pa);



	  Provider p = providerDao2.getProvider(request.getParameter("provider_no"));
	  if(p != null) {
		  List<ChangedField> changedFields = new ArrayList<ChangedField>();
		  Provider beforeChange = new Provider(p);
		  p.setLastName(request.getParameter("last_name"));
		  p.setFirstName(request.getParameter("first_name"));
		  p.setProviderType(request.getParameter("provider_type"));
		  p.setSpecialty(request.getParameter("specialty"));
		  p.setTeam(request.getParameter("team"));
		  p.setSex(request.getParameter("sex"));
		  p.setDob(MyDateFormat.getSysDate(request.getParameter("dob")));
		  p.setAddress(request.getParameter("address"));
		  p.setPhone(request.getParameter("phone"));
		  p.setWorkPhone(request.getParameter("workphone"));
		  p.setEmail(request.getParameter("email"));
		  p.setOhipNo(request.getParameter("ohip_no"));
		  p.setRmaNo(request.getParameter("rma_no"));
		  p.setBillingNo(request.getParameter("billing_no"));
		  p.setHsoNo(request.getParameter("hso_no"));
		  p.setStatus(request.getParameter("status"));
		  p.setComments(SxmlMisc.createXmlDataString(request,"xml_p"));
		  p.setProviderActivity(request.getParameter("provider_activity"));
		  p.setPractitionerNo(request.getParameter("practitionerNo"));
		  p.setPractitionerNoType(request.getParameter("practitionerNoType"));
		  p.setLastUpdateUser((String)session.getAttribute("user"));
		  p.setLastUpdateDate(new java.util.Date());
                  String supervisor = request.getParameter("supervisor");
                  
                  if( supervisor == null || supervisor.equalsIgnoreCase("null") || supervisor.equals("")) {
                      p.setSupervisor(null);
                  }
                  else {
                    p.setSupervisor(supervisor);
                  }
		  
		  providerDao2.updateProvider(p);
		  
		  
		  UserPropertyDAO userPropertyDAO = (UserPropertyDAO)SpringUtils.getBean("UserPropertyDAO");
		 
		  String clinicalConnectId = request.getParameter("clinicalConnectId");
		  String clinicalConnectType = request.getParameter("clinicalConnectType");
          if( clinicalConnectId != null &&  !clinicalConnectId.equals("")){	  
		      userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.CLINICALCONNECT_ID, clinicalConnectId);
		      userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.CLINICALCONNECT_TYPE, clinicalConnectType);
            }

		  String officialFirstName = request.getParameter("officialFirstName");
		  String officialSecondName = request.getParameter("officialSecondName");
		  String officialLastName = request.getParameter("officialLastName");
		  String officialOlisIdtype = request.getParameter("officialOlisIdtype");
		  String oldOfficialFirstName = (userPropertyDAO.getStringValue(provider2.getProviderNo(), UserProperty.OFFICIAL_FIRST_NAME));
		  String oldOfficialSecondName = (userPropertyDAO.getStringValue(provider2.getProviderNo(), UserProperty.OFFICIAL_SECOND_NAME));
		  String oldOfficialLastName = (userPropertyDAO.getStringValue(provider2.getProviderNo(), UserProperty.OFFICIAL_LAST_NAME));
		  String oldOfficialOlisIdtype = (userPropertyDAO.getStringValue(provider2.getProviderNo(), UserProperty.OFFICIAL_OLIS_IDTYPE));
		  
		  oldOfficialFirstName = StringUtils.trimToEmpty(oldOfficialFirstName);
		  oldOfficialSecondName = StringUtils.trimToEmpty(oldOfficialSecondName);
		  oldOfficialLastName = StringUtils.trimToEmpty(oldOfficialLastName);
		  oldOfficialOlisIdtype = StringUtils.trimToEmpty(oldOfficialOlisIdtype);
          
		  userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.OFFICIAL_FIRST_NAME, officialFirstName);
		  userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.OFFICIAL_SECOND_NAME, officialSecondName);
		  userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.OFFICIAL_LAST_NAME, officialLastName);
		  userPropertyDAO.saveProp(provider2.getProviderNo(), UserProperty.OFFICIAL_OLIS_IDTYPE, officialOlisIdtype);
		  if (!oldOfficialFirstName.equals(officialFirstName)) {
		      changedFields.add(new ChangedField(UserProperty.OFFICIAL_FIRST_NAME, oldOfficialFirstName, officialFirstName));
		  }
		  if (!oldOfficialSecondName.equals(officialSecondName)) {
		      changedFields.add(new ChangedField(UserProperty.OFFICIAL_SECOND_NAME, oldOfficialSecondName, officialSecondName));
		  }
		  if (!oldOfficialLastName.equals(officialLastName)) {
		      changedFields.add(new ChangedField(UserProperty.OFFICIAL_LAST_NAME, oldOfficialLastName, officialLastName));
		  }
		  if (!oldOfficialOlisIdtype.equals(officialOlisIdtype)) {
			  changedFields.add(new ChangedField(UserProperty.OFFICIAL_OLIS_IDTYPE, oldOfficialOlisIdtype, officialOlisIdtype));
		  }
		
        if (org.oscarehr.common.IsPropertiesOn.isMultisitesEnable()) {
            String[] sites = request.getParameterValues("sites");

            String provider_no = request.getParameter("provider_no");
            List<ProviderSite> pss = providerSiteDao.findByProviderNo(provider_no);
            for(ProviderSite ps:pss) {
            	providerSiteDao.remove(ps.getId());
            }
            if (sites!=null) {
                for (int i=0; i<sites.length; i++) {
                	ProviderSite ps = new ProviderSite();
                	ps.setId(new ProviderSitePK(provider_no,Integer.parseInt(sites[i])));
                	providerSiteDao.persist(ps);
                }
            }
        }
		changedFields.addAll(ChangedField.getChangedFieldsAndValues(beforeChange, p));
        
        String keyword2 = "providerNo=" + p.getProviderNo();
        if (request.getParameter("keyword") != null) { keyword2 += "\n" + request.getParameter("keyword"); }
        
		LogAction.addChangeLog(LoggedInInfo.getLoggedInInfoFromSession(request), LogConst.UPDATE, "adminUpdateUser", keyword2, changedFields);
%>
<p>
<div class="alert alert-success">
    <h4><bean:message key="admin.providerupdate.msgUpdateSuccess" /><a href="providerupdateprovider.jsp?keyword=<%=request.getParameter("provider_no")%>"><%= request.getParameter("provider_no") %></a>
    </h4>
</div>
<script>
    setTimeout(() => {
        window.history.go(-2);
    },2000);    		  
</script>

<%
  } else {
%>
<div class="alert alert-error" >
<h4><bean:message key="admin.providerupdate.msgUpdateFailure" />
<%= request.getParameter("provider_no") %>.</h4>
</div>
<%
  }
}
else {
	if (!isProviderFormalize) {
		//output ProviderFormalize error message
	%>
<div class="alert alert-error" >
		<h4><bean:message key="<%=errMsgProviderFormalize%>" />  </h4>
		Provider # range from : <%=min_value %> To : <%=max_value %>
</div>
	<%
	}
}
}
%>


<form method="post" action="providerupdateprovider.jsp" name="updatearecord" novalidate>

<input type="hidden" name="keyword" value="<%=keyword%>">


<div class="container-fluid well form-horizontal span12" >  
            <input type="hidden" name="provider_no"  value="<%= provider_no2 %>">

 <div  id="requiredSection" class="span11">
		<fieldset>
			<legend><bean:message key="admin.provider.professional" /></legend>
		</fieldset> 

    <div class="control-group span5">
        <label class="control-label" for="last_name"><bean:message 
                key="admin.provider.formLastName" /><span style="color:red">*</span></label>
        <div class="controls">
		    <input type="text" name="last_name" 
		    value="<%= Encode.forHtmlAttribute(provider.getLastName()) %>"  
		    maxlength="30" required ="required" data-validation-required-message="<bean:message key="global.missing" /> <bean:message key="admin.provider.formLastName" />"> 
            <p class="help-block text-danger"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="first_name"><bean:message 
                key="admin.provider.formFirstName" /><span style="color:red">*</span></label>
        <div class="controls">
		    <input type="text" name="first_name" 
		    value="<%= Encode.forHtmlAttribute(provider.getFirstName()) %>"
		    maxlength="30" required ="required" data-validation-required-message="<bean:message key="global.missing" /> <bean:message key="admin.provider.formFirstName" />"> 
            <p class="help-block text-danger"></p>
        </div>
    </div>

<%
		if (org.oscarehr.common.IsPropertiesOn.isMultisitesEnable()) {
	%>
    <div class="control-group span5">
        <label class="control-label" for="sites"><bean:message 
                key="admin.provider.sitesAssigned" /><span style="color:red">*</span></label>
        <div class="controls">

<%
SiteDao siteDao = (SiteDao)WebApplicationContextUtils.getWebApplicationContext(application).getBean("siteDao");
List<Site> psites = siteDao.getActiveSitesByProviderNo(provider_no2);
List<Site> sites = siteDao.getAllActiveSites();
for (int i=0; i<sites.size(); i++) {
%>
	<input type="checkbox" name="sites" value="<%= sites.get(i).getSiteId() %>" <%= psites.contains(sites.get(i))?"checked='checked'":"" %> <%=((!isSiteAccessPrivacy) || siteIDs.contains(sites.get(i).getSiteId()) ? "" : " disabled ") %>>
	<%= Encode.forHtml(sites.get(i).getName()) %><br />
<%
}
%>
            <p class="help-block text-danger"></p>
        </div>
    </div>
<%
	}
%>

    <div class="control-group span5" id="provider_type_div">
        <label class="control-label" for="provider_type"><bean:message 
                key="admin.provider.formType" /><span style="color:red">*</span></label>
        <div class="controls">
		    <select id="provider_type" name="provider_type" required ="required" data-validation-required-message="<bean:message key="global.missing" />">
				<option value="receptionist"
					<% if (provider.getProviderType().equals("receptionist")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionReceptionist" /></option>
				<option value="doctor"
					<% if (provider.getProviderType().equals("doctor")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionDoctor" /></option>
				<option value="nurse"
					<% if (provider.getProviderType().equals("nurse")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionNurse" /></option>
				<option value="resident"
					<% if (provider.getProviderType().equals("resident")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionResident" /></option>
				<option value="midwife"
					<% if (provider.getProviderType().equals("midwife")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionMidwife" /></option>
				<option value="admin"
					<% if (provider.getProviderType().equals("admin")) { %>
					SELECTED <%}%>><bean:message
					key="admin.provider.formType.optionAdmin" /></option>
				<caisi:isModuleLoad moduleName="survey">
					<option value="er_clerk"
						<% if (provider.getProviderType().equals("er_clerk")) { %>
						SELECTED <%}%>><bean:message
						key="admin.provider.formType.optionErClerk" /></option>
				</caisi:isModuleLoad>
		</select> 
            <p class="help-block text-danger"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="status"><bean:message 
                key="admin.provider.formStatus" /><span style="color:red">*</span></label>
        <div class="controls">
		<input type="radio" id="statusActive" name="status" value="1" <%="1".equals(provider.getStatus()) ? "checked" : ""%>><bean:message key="admin.provider.formStatusActive"/>
		<input type="radio" id="statusInactive" name="status" value="0" <%=!"1".equals(provider.getStatus()) ? "checked" : ""%>><bean:message key="admin.provider.formStatusInactive"/>
            <p class="help-block text-danger"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for"confidentiality"><bean:message 
                key="admin.provider.confidentialityagreement" /><span style="color:red">*</span></label>
        <div class="controls">
		    <input type="date" name="confidentiality" value="<%= provider.getSignedConfidentiality()==null ? "" : provider.getSignedConfidentiality() %>" > 
            <p class="help-block text-danger"></p>
        </div>
    </div>
        <%
            
            List<ProviderData>providerL = providerDao.findAllBilling("1");
        %>
    <div class="control-group span5">
        <label class="control-label" for="supervisor"><bean:message 
                key="admin.provider.supervisor" /></label>
        <div class="controls">
		      <select id="supervisor" name="supervisor">
                    <option value="">- <bean:message 
                key="admin.provider.supervisor" /> -</option>
                    <%
                    for( ProviderData p : providerL ) {
                    %>
                    <option value="<%=p.getId()%>" <%if( provider.getSupervisor() != null &&  provider.getSupervisor().equals(p.getId())){%>SELECTED<%}%>><%=Encode.forHtmlContent(p.getLastName() + ", " + p.getFirstName())%></option>                       
                    <%
                    }
                    %> 
            </select>
            <p class="help-block text-danger"></p>
        </div>
    </div>

	<caisi:isModuleLoad moduleName="TORONTO_RFQ" reverse="true">
		<%
			if (OscarProperties.getInstance().getBooleanProperty("rma_enabled", "true")) {
		%>
    <div class="control-group span5">
        <label class="control-label" for="xml_p_nbr">Default Clinic NBR</label>
        <div class="controls">
				<select name="xml_p_nbr">
				<%
				ClinicNbrDao clinicNbrDAO = (ClinicNbrDao)SpringUtils.getBean("clinicNbrDao");
				List<ClinicNbr> nbrList = clinicNbrDAO.findAll();
				Iterator<ClinicNbr> nbrIter = nbrList.iterator();
				while (nbrIter.hasNext()) {
					ClinicNbr tempNbr = nbrIter.next();
					String valueString = tempNbr.getNbrValue() + " | " + tempNbr.getNbrString();
				%>
					<option value="<%=tempNbr.getNbrValue()%>" <%=SxmlMisc.getXmlContent(provider.getComments(),"xml_p_nbr").startsWith(tempNbr.getNbrValue())?"selected":""%>><%=valueString%></option>
				<%}%>

				</select>
            <p class="help-block"></p>
        </div>
    </div>
		<%} %>

	</caisi:isModuleLoad>

    <div class="control-group span5">
        <label class="control-label" for="practitionerNoType"><bean:message 
                key="admin.provider.formCPSIDType" /></label>
        <div class="controls">
		    <select name="practitionerNoType" id="practitionerNoType" >
					<option value="">- <bean:message key="admin.provider.formCPSIDType" /> -</option>
					<%
						LookupListManager lookupListManager = SpringUtils.getBean(LookupListManager.class);
						LookupList ll = lookupListManager.findLookupListByName(LoggedInInfo.getLoggedInInfoFromSession(request), "practitionerNoType");
						
						if(ll != null) {
							for(LookupListItem llItem : ll.getItems()) {
								if (llItem.isActive() || provider.getPractitionerNoType().equals(llItem.getValue())) {
									String selected="";
									if(provider.getPractitionerNoType().equals(llItem.getValue())) {
										selected = " selected=\"selected\" ";
									}
								%>
									
									<option value="<%=llItem.getValue()%>" <%=selected %>><%=llItem.getLabel() + (!llItem.isActive() ? " (inactive)"  : "")%></option>
								<%
								}
							}
						} else {
							%>
							
							<option value="" ><bean:message key="global.missing" /></option>
						<%
						}
					
					%>
				</select>
            <p class="help-block"></p>
        </div>
    </div>

<div id="registrationNumbers">
    <div class="control-group span5">
        <label class="control-label" for="practitionerNo"><bean:message 
                key="admin.provider.formCPSID" />#</label>
        <div class="controls">
		    <input type="text" name="practitionerNo" id="practitionerNo" maxlength="20"
		    value="<%= provider.getPractitionerNo()==null ? "" : Encode.forHtmlAttribute(provider.getPractitionerNo()) %>"    
                pattern="\d{0,20}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formPractitionerNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" />" 
                > 
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="ohip_no"><bean:message 
                key="admin.provider.formOhipNo" /></label>
        <div class="controls">
		    <input type="text" name="ohip_no" maxlength="20"
		    value="<%= provider.getOhipNo()==null ? "" : provider.getOhipNo() %>" 
                pattern="\d{1,20}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formOhipNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" />" 
                >
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="rma_no"><bean:message 
                key="admin.provider.formRmaNo"  /></label>
        <div class="controls">
		    <input type="text" name="rma_no" maxlength="20"
		    value="<%= provider.getRmaNo()==null ? "" : Encode.forHtmlAttribute(provider.getRmaNo()) %>"
                pattern="\d{1,20}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formRmaNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" />" 
                >
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="billing_no"><bean:message 
                key="admin.provider.formBillingNo" /></label>
        <div class="controls">
		    <input type="text" name="billing_no" maxlength="20"
		    value="<%= provider.getBillingNo()==null ? "" : Encode.forHtmlAttribute(provider.getBillingNo()) %>"
                pattern="\d{1,20}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formBillingNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" />" 
                > 
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="hso_no"><bean:message 
                key="admin.provider.formHsoNo"  /></label>
        <div class="controls">
		    <input type="text" name="hso_no" maxlength="10"
		    value="<%= provider.getHsoNo()==null ? "" : Encode.forHtmlAttribute(provider.getHsoNo()) %>"
                pattern="\d{1,10}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formHsoNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" />" 
                >  
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="xml_p_specialty_code"><bean:message 
                key="admin.provider.formSpecialtyCode" /></label>
        <div class="controls">
		    <input type="text" name="xml_p_specialty_code" maxlength="2"
		    value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_specialty_code")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_specialty_code")) %>"
                pattern="\d{2}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formSpecialtyCode" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.numericValue" /> nn" 
                > 
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="xml_p_billinggroup_no"><bean:message 
                key="admin.provider.formBillingGroupNo" /></label>
        <div class="controls">
		    <input type="text" name="xml_p_billinggroup_no" maxlength="4"
		    value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_billinggroup_no")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_billinggroup_no")) %>"
                pattern="[A-Z\d]{4}" 
                data-validation-pattern-message="<bean:message 
                key="admin.provider.formBillingGroupNo" /> <bean:message 
                key="oscarEncounter.oscarMeasurements.MeasurementsAction.mustBe" />  XXXX" 
                > 
            <p class="help-block"></p>
        </div>
    </div>
    <div class="control-group span5">
        <label class="control-label" for="admin.provider.billcenter"><bean:message 
                key="admin.provider.billcenter" /></label>
        <div class="controls">
		    <select name="billcenter">
				<option value=""></option>
			<%
                              ProviderBillCenter billCenter = new ProviderBillCenter();
                              String billCode = "";
                              String codeDesc = "";
                              Enumeration<?> keys = billCenter.getAllBillCenter().propertyNames();
                              String currentBillCode = billCenter.getBillCenter(provider_no2);
                              for(int i=0;i<billCenter.getAllBillCenter().size();i++){
                                  billCode=(String)keys.nextElement();
                                  codeDesc=billCenter.getAllBillCenter().getProperty(billCode);
                              %>
				<<option value=<%=Encode.forHtmlAttribute(billCode) %>
					<%=currentBillCode.compareTo(billCode)==0?"selected":""%>><%= codeDesc%></option>
				<%
                                }
                        %>
			</select>
            <p class="help-block"></p>
        </div>
    </div>
</div> <!-- end registration number division -->

 </div>

<div id="labs_div">
 <div  id="optionalSection" class="span11">
		<fieldset>
			<legend><bean:message key="oscarEncounter.Labs.title" />&nbsp;-&nbsp;<bean:message key="admin.admin.generalSettings" /></legend>
		</fieldset> 
		
		<%
		UserPropertyDAO userPropertyDAO = (UserPropertyDAO)SpringUtils.getBean("UserPropertyDAO");
		String ccType = StringUtils.trimToEmpty(userPropertyDAO.getStringValue(provider_no2, UserProperty.CLINICALCONNECT_TYPE));
		%>
		
    <div class="control-group span5">
        <label class="control-label" for="clinicalConnectId"><bean:message 
                key="admin.provider.formClinicalConnectId" /></label>
        <div class="controls">
            <input type="text" name="clinicalConnectId" 
            value="<%=Encode.forHtmlAttribute(StringUtils.trimToEmpty(userPropertyDAO.getStringValue(provider_no2, UserProperty.CLINICALCONNECT_ID)))%>" 
            maxlength="255">
        </div>
    </div>
     <div class="control-group span5">
        <label class="control-label" for="clinicalConnectType"><bean:message 
                key="admin.provider.formClinicalConnectType" /></label>
        <div class="controls">
            <select name="clinicalConnectType">
                <option value=""></option>
                <option value="hhsc" <%="hhsc".equals(ccType)?"selected":""%>>HHSC</option>
		        <option value="partners" <%="partners".equals(ccType)?"selected":""%>>PARTNERS</option>
		        <option value="hrcc" <%="hrcc".equals(ccType)?"selected":""%>>HRCC</option>
            </select>
        </div>
    </div>   
    <div class="control-group span5">
        <label class="control-label" for="officialFirstName"><bean:message 
                key="admin.provider.formOfficialFirstName" /></label>
        <div class="controls">
            <input type="text" name="officialFirstName" 
            value="<%=Encode.forHtmlAttribute(StringUtils.trimToEmpty(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_FIRST_NAME)))%>" 
                maxlength="255">
        </div>
    </div> 
    <div class="control-group span5">
        <label class="control-label" for="officialSecondName"><bean:message 
                key="admin.provider.formOfficialSecondName"  /></label>
        <div class="controls">
            <input type="text" name="officialSecondName" 
            value="<%=Encode.forHtmlAttribute(StringUtils.trimToEmpty(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_SECOND_NAME)))%>" 
                maxlength="255">
        </div>
    </div>   
    <div class="control-group span5">
        <label class="control-label" for="officialLastName"><bean:message 
                key="admin.provider.formOfficialLastName"  /></label>
        <div class="controls">
            <input type="text" name="officialLastName" 
            value="<%=Encode.forHtmlAttribute(StringUtils.trimToEmpty(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_LAST_NAME)))%>" 
                maxlength="255">
        </div>
    </div>  
    <div class="control-group span5">
        <label class="control-label" for="officialOlisIdtype"><bean:message 
                key="admin.provider.formOfficialOlisIdentifierType"  /></label>
        <div class="controls">
                <select name="officialOlisIdtype">
                        <option value=""><bean:message key="admin.provider.formOfficialOlisIdentifierType.option.notset" /></option>
		        <option value="MDL" <%="MDL".equals(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_OLIS_IDTYPE))?"SELECTED":""%>>
			        <bean:message key="admin.provider.formOfficialOlisIdentifierType.option.mdl" />
			</option> 
			<option value="DDSL" <%="DDSL".equals(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_OLIS_IDTYPE))?"SELECTED":""%>>
			        <bean:message key="admin.provider.formOfficialOlisIdentifierType.option.ddsl" />
			</option>
			<option value="NPL" <%="NPL".equals(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_OLIS_IDTYPE))?"SELECTED":""%>>
			        <bean:message key="admin.provider.formOfficialOlisIdentifierType.option.npl" />
			</option>
			<option value="ML" <%="ML".equals(userPropertyDAO.getStringValue(provider_no2, UserProperty.OFFICIAL_OLIS_IDTYPE))?"SELECTED":""%>>
			        <bean:message key="admin.provider.formOfficialOlisIdentifierType.option.ml" />
			</option>
		</select>
        </div>
    </div>   

 </div>
</div>

<div id="contact_div">
 <div  id="optionalSection" class="span11">
		<fieldset>
			<legend><bean:message key="admin.provider.contactinfo" /></legend>
		</fieldset> 


    <div class="control-group span5">
        <label class="control-label" for="team"><bean:message 
                key="admin.provider.formTeam" /></label>
        <div class="controls">
		    <input type="text" name="team" 
		     value="<%= provider.getTeam()==null ? "" : Encode.forHtmlAttribute(provider.getTeam()) %>"
		    maxlength="20"> 
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="specialty"><bean:message 
                key="admin.provider.formSpecialty" /></label>
        <div class="controls">
		    <input type="text" name="specialty"
		     value="<%= provider.getSpecialty()==null ? "" : Encode.forHtmlAttribute(provider.getSpecialty()) %>"
			onBlur="upCaseCtrl(this)" maxlength="40"> 
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="sex"><bean:message 
                key="admin.provider.formSex" /></label>
        <div class="controls">
            <select  name="sex" id="sex" >//Value are Codes F M T O U Texts are Female Male Transgender Other Undefined
                <option value=""></option>
                <% 
            	java.util.ResourceBundle oscarResources = ResourceBundle.getBundle("oscarResources", request.getLocale());
                String iterSex = "";
                String sexTag = "";
                for(Gender gn : Gender.values()){ 
                    sexTag = "global."+gn.getText();
                try{
                        iterSex = oscarResources.getString(sexTag) ;
                    } catch(Exception ex) {
                        //MiscUtils.getLogger().error("Error", ex);
                        //Fine then lets use the English default
                        iterSex = gn.getText();
                }
                %>
                <option value=<%=gn.name()%> <%=((provider.getSex().toUpperCase().equals(gn.name())) ? "selected" : "") %>><%=gn.getText()%></option>
		<% } %>
            </select>
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="dob"><bean:message 
                key="admin.provider.formDOB" /></label>
        <div class="controls">
		    <input type="date" name="dob" 
		    value="<%= oscar.MyDateFormat.getMyStandardDate(provider.getDob())==null ? "":  oscar.MyDateFormat.getMyStandardDate(provider.getDob()) %>"
		    > 
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="address"><bean:message 
                key="admin.provider.formAddress" /></label>
        <div class="controls">
		    <input type="text" name="address" 
		    value="<%= provider.getAddress()==null ? "" : Encode.forHtmlAttribute(provider.getAddress()) %>"
		    size="40" maxlength="40"> 
            <p class="help-block"></p>
        </div>
    </div>


    <div class="control-group span5">
        <label class="control-label" for="phone"><bean:message 
				key="admin.provider.formHomePhone" /></label>
        <div class="controls">
            <input type="text" name="phone" 
            value="<%= provider.getPhone()==null ? "" :  Encode.forHtmlAttribute(provider.getPhone()) %>"
            maxlength="20" onblur="formatPhone(this);"></td>
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="workphone"><bean:message 
                key="admin.provider.formWorkPhone" /></label>
        <div class="controls">
			<input type="text" name="workphone" 
			value="<%= provider.getWorkPhone()==null ? "" :  Encode.forHtmlAttribute(provider.getWorkPhone()) %>" 
			maxlength="20" onblur="formatPhone(this);">
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="email"><bean:message 
                key="admin.provider.formEmail" /></label>
        <div class="controls">
			<input type="email" name="email" 
			value="<%= provider.getEmail()==null ? "" :  Encode.forHtmlAttribute(provider.getEmail()) %>"
                data-validation-email-message="<bean:message key="global.alertinvalid" />"> 
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="xml_p_pager"><bean:message 
                key="admin.provider.formPager" /></label>
        <div class="controls">
			<input type="text" name="xml_p_pager" 
			value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_pager")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_pager"))  %>" 
			onblur="formatPhone(this);">
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="xml_p_cell"><bean:message 
                key="admin.provider.formCell" /></label>
        <div class="controls">
			<input type="text" name="xml_p_cell" 
			value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_cell")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_cell")) %>" 
			onblur="formatPhone(this);">
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="xml_p_phone2"><bean:message 
                key="admin.provider.formOtherPhone" /></label>
        <div class="controls">
			<input type="text" name="xml_p_phone2" 
			value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_phone2")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_phone2")) %>" 
			onblur="formatPhone(this);">
            <p class="help-block"></p>
        </div>
    </div>

    <div class="control-group span5">
        <label class="control-label" for="xml_p_fax"><bean:message 
                key="admin.provider.formFax" /></label>
        <div class="controls">
			<input type="text" name="xml_p_fax" 
			value="<%= SxmlMisc.getXmlContent(provider.getComments(),"xml_p_fax")==null ? "" : Encode.forHtmlAttribute(SxmlMisc.getXmlContent(provider.getComments(),"xml_p_fax")) %>" 
			onblur="formatPhone(this);">
            <p class="help-block"></p>
        </div>
    </div>


<!-- deprecated -->
		<input type="hidden" name="provider_activity" value="">	
		<input type="hidden" name="xml_p_slpusername">
		<input type="hidden" name="xml_p_slppassword">

			
 </div>
</div>
</div>

		<div align="center" class="span12">
		
		<input type="submit" name="subbutton" class="btn btn-primary"
			value="<bean:message key="admin.providerupdateprovider.btnSubmit"/>">
            &nbsp;&nbsp;
<a class="btn-link" onclick="$('#contact_div').toggle();"><bean:message key="global.showhide"/> <bean:message key="admin.provider.contactinfo"/></a>
		</div>


<%
  }
%>
</form>

</center>
</body>
</html:html>