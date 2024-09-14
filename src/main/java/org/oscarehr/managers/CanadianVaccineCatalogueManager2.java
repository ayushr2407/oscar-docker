/**
 * Copyright (c) 2001-2002. Department of Family Medicine, McMaster University. All Rights Reserved.
 * This software is published under the GPL GNU General Public License.
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 * This software was written for the
 * Department of Family Medicine
 * McMaster University
 * Hamilton
 * Ontario, Canada
 */
package org.oscarehr.managers;

import java.io.File;
import java.io.IOException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.http.HttpEntity;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.logging.log4j.Logger;
import org.hl7.fhir.r4.model.Bundle;
import org.hl7.fhir.r4.model.Bundle.BundleEntryComponent;
import org.hl7.fhir.r4.model.CodeableConcept;
import org.hl7.fhir.r4.model.Coding;
import org.hl7.fhir.r4.model.Extension;
import org.hl7.fhir.r4.model.Medication;
import org.hl7.fhir.r4.model.Resource;
import org.hl7.fhir.r4.model.ResourceType;
import org.hl7.fhir.r4.model.ValueSet;
import org.hl7.fhir.r4.model.ValueSet.ConceptReferenceComponent;
import org.hl7.fhir.r4.model.ValueSet.ConceptReferenceDesignationComponent;
import org.hl7.fhir.r4.model.ValueSet.ConceptSetComponent;
import org.oscarehr.common.dao.CVCImmunizationDao;
import org.oscarehr.common.dao.CVCMedicationDao;
import org.oscarehr.common.dao.CVCMedicationGTINDao;
import org.oscarehr.common.dao.CVCMedicationLotNumberDao;
import org.oscarehr.common.dao.UserPropertyDAO;
import org.oscarehr.common.model.CVCImmunization;
import org.oscarehr.common.model.CVCImmunizationName;
import org.oscarehr.common.model.CVCMedication;
import org.oscarehr.common.model.CVCMedicationGTIN;
import org.oscarehr.common.model.CVCMedicationLotNumber;
import org.oscarehr.common.model.LookupList;
import org.oscarehr.common.model.LookupListItem;
import org.oscarehr.common.model.UserProperty;
import org.oscarehr.integration.dhdr.OmdGateway;
import org.oscarehr.util.LoggedInInfo;
import org.oscarehr.util.MiscUtils;
import org.oscarehr.util.SpringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import ca.uhn.fhir.context.FhirContext;
import ca.uhn.fhir.parser.IParser;
import ca.uhn.fhir.rest.client.api.IGenericClient;
import ca.uhn.fhir.rest.client.api.IRestfulClientFactory;
import ca.uhn.fhir.rest.client.api.ServerValidationModeEnum;
import ca.uhn.fhir.rest.client.interceptor.AdditionalRequestHeadersInterceptor;
import ca.uhn.fhir.rest.client.interceptor.CapturingInterceptor;
import ca.uhn.fhir.rest.client.interceptor.LoggingInterceptor;

import oscar.OscarProperties;
import oscar.log.LogAction;

@Service
public class CanadianVaccineCatalogueManager2 {
	
	protected static FhirContext ctxR4 = null;
	Logger logger = MiscUtils.getLogger();
	
	private static final String CVCFirstDate = "cvc.firstdate";

	@Autowired
	CVCMedicationDao medicationDao;
	@Autowired
	CVCMedicationLotNumberDao lotNumberDao;
	@Autowired
	CVCMedicationGTINDao gtinDao;
	@Autowired
	CVCImmunizationDao immunizationDao;
	
	static {
		ctxR4 = FhirContext.forR4(); //Creates and returns a new FhirContext with version R4
	}
	
	Map<String,String> dinManufactureMap = new HashMap<String,String>();
	Map<String,String> dinStatusMap = new HashMap<String,String>();
	Map<String,String> dinDinMap = new HashMap<String,String>();
	
	public void update(LoggedInInfo loggedInInfo) throws IOException {
		OmdGateway omdGateway = new OmdGateway();
		
		Bundle bundle =null;
		String jsonString = null;
		
		try {
			//bundle= getBundleFromServer(); use this instead of the following if the server is HAPI FHIR compliant
			jsonString = getJsonStringFromServer();
			bundle = getBundleFromJsonString(jsonString);
			
		}catch(Exception e) {
			omdGateway.logError(loggedInInfo, "CVC", "DOWNLOAD", e.getLocalizedMessage());
			
			throw(e);
		}
		
		String bundleJSON = ctxR4.newJsonParser().setPrettyPrint(true).encodeResourceToString(bundle);
		omdGateway.logDataReceived(loggedInInfo, "CVC", "DOWNLOAD", "data loaded", null);

		OscarProperties oscarProperties = OscarProperties.getInstance();
		if(oscarProperties.hasProperty("CVC_BUNDLE_LOCAL_FILE")){
			// the download eases debugging the parsing that follows aquisition of the bundle
			try {
				FileUtils.writeStringToFile(new File(oscarProperties.getProperty("CVC_BUNDLE_LOCAL_FILE")), bundleJSON);
			}catch(IOException e) {
				logger.error("Error",e);
			}
		}else {
			logger.info("CVC_BUNDLE_LOCAL_FILE property not set. Not writing to file to disk. (not needed) ");
		}
		 
		clearCurrentData();		
		
		for(Bundle.BundleEntryComponent bec : bundle.getEntry()) {
			Resource res = bec.getResource();
			if(res.getResourceType() ==  ResourceType.ValueSet) {
				if(res.getIdElement().getIdPart().equals("Generic")) { 
					updateGenericImmunizations(loggedInInfo,(ValueSet)res);
				} else if(res.getIdElement().getIdPart().equals("Tradename")) {
					updateBrandNameImmunizations(loggedInInfo,(ValueSet)res);
				} else if(res.getIdElement().getIdPart().equals("AnatomicalSite")) { //? NA
					updateAnatomicalSites(loggedInInfo,(ValueSet)res);
				} else if(res.getIdElement().getIdPart().equals("RouteOfAdmin")) {
					updateRoutes(loggedInInfo,(ValueSet)res);
				} else {
					//Disease, AntigenIgAntitoxin, AdminGender, ForecastStatus, ShelfStatus, HealthcareProviderRoleType
					logger.debug("value-set " + res.getId());
				}
			} else if(res.getResourceType() ==  ResourceType.Bundle) {
				if(res.getIdElement().getIdPart().equals("Tradename")) {
					updateMedications(loggedInInfo,(Bundle)res);
				}
			} else {
				logger.warn("resource type = " + res.getResourceType().toString());	
			}
		}
		
		//store when we last update
		setUpdatedInPropertyTable();
		setFirstDateInPropertyTable();
	}

	private void setUpdatedInPropertyTable() {
		UserPropertyDAO userPropertyDao = SpringUtils.getBean(UserPropertyDAO.class);
		SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd");
		UserProperty up = userPropertyDao.getProp("cvc.updated");
		if(up == null) {
			up = new UserProperty();
			up.setName("cvc.updated");
		}
		up.setValue(formatter.format(new Date()));
		
		userPropertyDao.merge(up);
		
	}
	
	private void setFirstDateInPropertyTable() {
		UserPropertyDAO userPropertyDao = SpringUtils.getBean(UserPropertyDAO.class);
		UserProperty up = userPropertyDao.getProp(CVCFirstDate);
		if(up == null) {
			up = new UserProperty();
			up.setName(CVCFirstDate);
			up.setValue(""+(new Date()).getTime());
			userPropertyDao.persist(up);
		}
	}
	
	private void clearCurrentData() {
		medicationDao.removeAll();
		lotNumberDao.removeAll();
		gtinDao.removeAll();
		immunizationDao.removeAll();
	}

	private Bundle getBundleFromServer() {
		// this requires a HAPI fhir compliant server, not just the file format
		IRestfulClientFactory clientFactory = ctxR4.getRestfulClientFactory();
		
		// Disable server fhir validation (don't pull the server's metadata first)
		clientFactory.setServerValidationMode(ServerValidationModeEnum.NEVER);
		
		// create the client
		IGenericClient client = clientFactory.newGenericClient(CanadianVaccineCatalogueManager2.getCVCURL());
		// serverBase=https://nvc-cnv.canada.ca/v1
		logger.debug("serverBase=" + CanadianVaccineCatalogueManager2.getCVCURL());	

		// acceptable Accept headers are "application/json+fhir" and "application/json"

		String Accept = OscarProperties.getInstance().getProperty("NVC_ACCEPT","application/json+fhir");
		String xAppDesc = OscarProperties.getInstance().getProperty("NVC_X_APP","OSCAREMR");
		String relUrl = OscarProperties.getInstance().getProperty("NVC_BUNDLE","/Bundle/NVC");		
		logger.debug("Full Url=" + CanadianVaccineCatalogueManager2.getCVCURL()+relUrl);			
		
		// Register an additional headers interceptor
		AdditionalRequestHeadersInterceptor interceptor = new AdditionalRequestHeadersInterceptor();
		interceptor.addHeaderValue("Accept", Accept);
		interceptor.addHeaderValue("x-app-desc", xAppDesc);
		client.registerInterceptor(interceptor);
		logger.debug("Accept=" + Accept);	
		logger.debug("x-app-desc=" + xAppDesc);	
				
		// Register a logging interceptor against the client
		LoggingInterceptor loggingInterceptor = new LoggingInterceptor();
		client.registerInterceptor(loggingInterceptor);
		
		// Register a capturing interceptor against the client
		CapturingInterceptor capturingInterceptor = new CapturingInterceptor();
		client.registerInterceptor(capturingInterceptor);

		Bundle bundle = client.search().byUrl(CanadianVaccineCatalogueManager2.getCVCURL()+relUrl).returnBundle(Bundle.class).execute();
			
		logger.info(capturingInterceptor.getLastRequest().toString());
		logger.debug(capturingInterceptor.getLastResponse().toString());
		// tidy up and clear the buffer
		capturingInterceptor.clear();
		//client.unregisterInterceptor(capturingInterceptor);
		
		return bundle;

	}

	private String getJsonStringFromServer() throws IOException {

        CloseableHttpClient httpClient = HttpClients.createDefault();
		String result = null;
		String serverBase = CanadianVaccineCatalogueManager2.getCVCURL();
		logger.debug("serverBase=" + CanadianVaccineCatalogueManager2.getCVCURL());
		// acceptable Accept headers are "application/json+fhir" and "application/json"

		String Accept = OscarProperties.getInstance().getProperty("NVC_ACCEPT","application/json+fhir");
		String xAppDesc = OscarProperties.getInstance().getProperty("NVC_X_APP","OSCAREMR");
		String relUrl = OscarProperties.getInstance().getProperty("NVC_BUNDLE","/Bundle/NVC");		
		logger.debug("Full Url=" + serverBase+relUrl);
		
        try {
            HttpGet request = new HttpGet(serverBase+relUrl);
            // add request headers
            request.addHeader("Accept", Accept);
            request.addHeader("x-app-desc", xAppDesc);
            CloseableHttpResponse response = httpClient.execute(request);
            try {
                // Get HttpResponse Status
                logger.debug(response.getProtocolVersion());              // HTTP/1.1
                logger.debug(response.getStatusLine().getStatusCode());   // 200
                logger.debug(response.getStatusLine().getReasonPhrase()); // OK
                logger.debug(response.getStatusLine().toString());        // HTTP/1.1 200 OK

                HttpEntity entity = response.getEntity();
                if (entity != null) {
                    // return it as a String
                    result = EntityUtils.toString(entity);
                    if (result.length()>300) {
						logger.debug(result.substring(0,70)+"... ");
                    }
                }
            } finally {
                response.close();
            }
        } finally {
            httpClient.close();
        }
		return result;
    }

	private Bundle getBundleFromJsonString( String jsonString ) {	
		IParser parser = ctxR4.newJsonParser().setPrettyPrint(true);
		Bundle bundle = parser.parseResource(Bundle.class,jsonString);
		return bundle;	
	}

	public void updateGenericImmunizations(LoggedInInfo loggedInInfo, ValueSet vs) {
		 
		for (ConceptSetComponent c : vs.getCompose().getInclude()) {
			List<ConceptReferenceComponent> cons = c.getConcept();
			for (ConceptReferenceComponent cc : cons) {
				CVCImmunization imm = new CVCImmunization();

				imm.setSnomedConceptId(cc.getCode());
				imm.setVersionId(0);
				logger.info("Loading names for generic concept "+cc.getCode());
				String pickListTerm = null;
				String useDisplay = null;
				
				for(ConceptReferenceDesignationComponent cr : cc.getDesignation()) {
					Coding use = cr.getUse();
					CVCImmunizationName name = new CVCImmunizationName();
					name.setLanguage(cr.getLanguage());
					if(use  != null) {
						name.setUseSystem(use.getSystem());
						name.setUseCode(use.getCode());
						useDisplay=use.getDisplay();
						name.setUseDisplay(use.getDisplay());
						logger.debug(cc.getCode()+" display name "+use.getDisplay()+" cc display "+cc.getDisplay());
						if(use.getCode().equals("enAbbreviation")) { pickListTerm=cr.getValue(); }
					}else {
						logger.error("USE WAS NULL for "+cr.getValue() +" "+c.toString());
					}
					if (useDisplay.equals("Fully Specified Name")){
						name.setValue(cr.getValue()+" (generic)");
					} else {
						name.setValue(cr.getValue());
					}
					imm.getNames().add(name);
				}
				if (pickListTerm != null) {
					// make up a picklist term for the generic concept
					CVCImmunizationName name2 = new CVCImmunizationName();
					name2.setLanguage("en");
					name2.setUseSystem("https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation");
					name2.setUseCode("enClinicianPicklistTerm");
					name2.setUseDisplay("Clinician Tradename Picklist (en)");
					name2.setValue(pickListTerm);
					imm.getNames().add(name2);
				}
				for (Extension ext : cc.getExtension()) {
					// https://nvc-cnv.canada.ca/v1
					if ((getCVCURL() + "/StructureDefinition/nvc-product-status").equals(ext.getUrl())) {
						CodeableConcept shelfStatusConcept = (CodeableConcept)ext.getValue();
						//active or inactive
						//String status = ext.getValueAsPrimitive().getValueAsString();
						for(Coding parentConceptCode :shelfStatusConcept.getCoding()) {                        
							if ((getCVCURL() + "/ValueSet/ShelfStatus").equals(parentConceptCode.getSystem())) {
								imm.setShelfStatus(parentConceptCode.getDisplay());
								logger.debug("status: "+parentConceptCode.getDisplay());
							}
						}
					}
				
					
					
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-last-updated").equals(ext.getUrl())) {
						Date lastUpdated = (Date)ext.getValueAsPrimitive().getValue();
					}
					
					//if ((getCVCURL() + "/StructureDefinition/nvc-ontario-ispa-vaccine".equals(ext.getUrl())) {
					//	Boolean ispa = (Boolean)ext.getValueAsPrimitive().getValue();
					//	imm.setIspa(ispa);	
					//}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-passive-immunizing-agent").equals(ext.getUrl())) {
						Boolean passiveImmAgent = (Boolean)ext.getValueAsPrimitive().getValue();
						
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-contains-antigen").equals(ext.getUrl())) {
						//more structure
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-protects-against-diseases").equals(ext.getUrl())) {
						//more structure
					}
					
					
					
				}
				
				
				/*
				for (Extension ext : cc.getExtension()) {
					if ("https://api.cvc.canimmunize.ca/extensions/prevalence".equals(ext.getUrl())) {
						Integer prevalence = (Integer) ext.getValueAsPrimitive().getValue();
						imm.setPrevalence(prevalence);
					}
					
				}
				*/
				imm.setGeneric(true);
				saveImmunization(loggedInInfo, imm);
			}
		}
	}
	
	public void saveImmunization(LoggedInInfo loggedInInfo, CVCImmunization immunization) {
		immunizationDao.saveEntity(immunization);
		LogAction.addLogSynchronous(loggedInInfo, "CanadianVaccineCatalogueManager.saveImmunization", immunization.getId().toString());

	}

	public void updateBrandNameImmunizations(LoggedInInfo loggedInInfo, ValueSet vs) {
	
		for (ConceptSetComponent c : vs.getCompose().getInclude()) {
			List<ConceptReferenceComponent> cons = c.getConcept();
			for (ConceptReferenceComponent cc : cons) {
				CVCImmunization imm = new CVCImmunization();

				imm.setSnomedConceptId(cc.getCode());
				imm.setVersionId(0);
				logger.info("Loading names for brand concept "+cc.getCode());
				String enAbbreviation = null;
				String fullName = null;
				
				for(ConceptReferenceDesignationComponent cr : cc.getDesignation()) {
					// Fully Specified Name, Synonym, enAbbreviation, frAbbreviation
					Coding use = cr.getUse();
					CVCImmunizationName name = new CVCImmunizationName();
					name.setLanguage(cr.getLanguage());
					if(use  != null) {
						name.setUseSystem(use.getSystem());
						name.setUseCode(use.getCode());
						name.setUseDisplay(use.getDisplay());
						logger.debug("Code:"+cc.getCode()+" display name:"+use.getDisplay()+" cc display:"+cc.getDisplay());
						if(use.getCode().equals("enAbbreviation")) { enAbbreviation=cr.getValue(); }
						if(use.getCode().equals("900000000000003001")) { fullName=cr.getValue(); }
					} else {
						logger.error("USE WAS NULL for "+cr.getValue() +" "+c.toString());
					}
					name.setValue(cr.getValue());
					imm.getNames().add(name);
				}
				if (enAbbreviation != null && fullName != null) {
					// make up a picklist term for the brand concept
					CVCImmunizationName name2 = new CVCImmunizationName();
					name2.setLanguage("en");
					name2.setUseSystem("https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation");
					name2.setUseCode("enClinicianPicklistTerm");
					name2.setUseDisplay("Clinician Tradename Picklist (en)");
					String arr[] = fullName.split(" ");
					name2.setValue(arr[0]+" ("+enAbbreviation+")");
					imm.getNames().add(name2);
				}
				String din = null;
				String dinDisplay = null;
				String manufactureDisplay = null;
				String routeDisplay = null;
				String routeCode = null;				
				String typicalDose = null;
				String typicalDoseUofM = null;
				String strength = null;
				
				String shelfStatus = null;
				String parentConcept = null;

				for (Extension ext : cc.getExtension()) {
					/*
					nvc-concept-status-extension
					nvc-concept-last-updated
					nvc-passive-immunizing-agent
					nvc-parent-concept
					nvc-contains-antigens ... sub extentions nvc-contains-antigen
					nvc-protects-against-diseases ... sub extensions nvc-protects-against-disease
					
					*/
					if ((getCVCURL() + "/StructureDefinition/nvc-product-statuses").equals(ext.getUrl())) {
						for(Extension statusExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-product-status").equals(statusExt.getUrl())) {
								CodeableConcept shelfStatusConcept = (CodeableConcept)statusExt.getValue();
								for(Coding codingShelfStatus :shelfStatusConcept.getCoding()) {  
									if ((getCVCURL() + "/ValueSet/ShelfStatus").equals(codingShelfStatus.getSystem())) {
										shelfStatus = codingShelfStatus.getDisplay(); //Marketed
										imm.setShelfStatus(shelfStatus);
									}									
								}
							}
						}					
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-parent-concept").equals(ext.getUrl())) {
						CodeableConcept parentConceptC = (CodeableConcept)ext.getValue();
						for(Coding parentConceptCode :parentConceptC.getCoding()) {
							if((getCVCURL() + "/ValueSet/Generic").equals(parentConceptCode.getSystem())) {
								parentConcept = parentConceptCode.getCode(); 
								imm.setParentConceptId(parentConcept);
							}
						}
					}
					
					if((getCVCURL() + "/StructureDefinition/nvc-market-authorization-holders").equals(ext.getUrl())) {
						for(Extension marketExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-market-authorization-holder").equals(marketExt.getUrl())) {
								manufactureDisplay = marketExt.getValue().primitiveValue();  // for loading into CVCMedication table
							}
						}
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-typical-dose-sizes").equals(ext.getUrl())) {
						for(Extension typicalExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-typical-dose-size").equals(typicalExt.getUrl())) {
								typicalDose = typicalExt.getValue().primitiveValue(); 
								imm.setTypicalDose(typicalDose); // 0.5
							}
						}
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-typical-dose-sizes-uom").equals(ext.getUrl())) {
						for(Extension uomExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-typical-dose-size-uom").equals(uomExt.getUrl())) {
								typicalDoseUofM = uomExt.getValue().primitiveValue(); 
								imm.setTypicalDoseUofM(typicalDoseUofM); // ML
							}
						}
					}
								
					if ((getCVCURL() + "/StructureDefinition/nvc-strengths").equals(ext.getUrl())) {
						for(Extension strExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-strength").equals(strExt.getUrl())) {
								strength = strExt.getValue().primitiveValue(); 
								imm.setStrength(strength); // see product monograph
							}
						}
					}
					
					if ((getCVCURL() + "/StructureDefinition/nvc-route-of-admins").equals(ext.getUrl())) {
						for(Extension routeExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-route-of-admin").equals(routeExt.getUrl())) {
								CodeableConcept routeConcept = (CodeableConcept)routeExt.getValue();
								for(Coding routeConceptCode :routeConcept.getCoding()) {
									if((getCVCURL() + "/ValueSet/RouteOfAdmin").equals(routeConceptCode.getSystem())) {
										routeCode = routeConceptCode.getCode(); 
										routeDisplay = routeConceptCode.getDisplay(); 
										imm.setRoute(routeCode);
									}
								}
							}
						}
					}	
					
					if ((getCVCURL() + "/StructureDefinition/nvc-dins").equals(ext.getUrl())) {
						for(Extension dinExt : ext.getExtension()) {
							if ((getCVCURL() + "/StructureDefinition/nvc-din").equals(dinExt.getUrl())) {
								CodeableConcept dinConcept = (CodeableConcept)dinExt.getValue();
								for(Coding dinConceptCode :dinConcept.getCoding()) {
									if(("http://hl7.org/fhir/NamingSystem/ca-hc-din").equals(dinConceptCode.getSystem())) {
										din = dinConceptCode.getCode(); 
										dinDisplay = dinConceptCode.getDisplay(); 
									}
								}
							}
						}
					}
					
					/*
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-status-extension").equals(ext.getUrl())) {
						CodeableConcept shelfStatusConcept = (CodeableConcept)ext.getValue();
						//active or inactive
						//String status = ext.getValueAsPrimitive().getValueAsString();
						for(Coding parentConceptCode :shelfStatusConcept.getCoding()) {                        
							if ((getCVCURL() + "/ValueSet/ShelfStatus").equals(parentConceptCode.getSystem())) {
								shelfStatus = parentConceptCode.getDisplay();
								imm.setShelfStatus(shelfStatus);
							}
						}
					}
									

					if ((getCVCURL() + "/StructureDefinition/nvc-din").equals(ext.getUrl())) {
						CodeableConcept dinConcept = (CodeableConcept)ext.getValue();
						if(dinConcept.hasCoding()) {
							din = dinConcept.getCoding().get(0).getDisplay();
						}
					}
					*/
					
										
				}
				
				if(imm.getSnomedConceptId() != null && manufactureDisplay != null) {
					dinManufactureMap.put(imm.getSnomedConceptId(),manufactureDisplay);
				}
				if(imm.getSnomedConceptId() != null && din != null) {
					if (dinDisplay == null ) { dinDisplay = din; }
					dinDinMap.put(imm.getSnomedConceptId(),din);
				}
				
				
				imm.setGeneric(false);
				logger.debug("din:"+din+" By:"+manufactureDisplay+" Strength:"+strength+" Typical Dose:"+typicalDose+" "+typicalDoseUofM+" route:"+routeDisplay+"/"+routeCode+" Status:"+shelfStatus);
				
				saveImmunization(loggedInInfo, imm);
			}
		}
	}
	
	public void updateMedications(LoggedInInfo loggedInInfo,Bundle bundle) {
		
		processMedicationBundle(loggedInInfo, bundle);
		/*
		logger.debug("Retrieved Bundle ID + " + bundle.getId() + ", total records found = " + bundle.getTotal());
		while (bundle.getLink(Bundle.LINK_NEXT) != null) {
			bundle = client.loadPage().next(bundle).execute();
			logger.debug("Retrieved Next Bundle ID + " + bundle.getId());
			processMedicationBundle(loggedInInfo, bundle);
		}
		*/
	}
	
	private void processMedicationBundle(LoggedInInfo loggedInInfo, Bundle bundle) {

		SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd");
		Date curdate = new Date();
		for (BundleEntryComponent entry : bundle.getEntry()) {
			CVCMedication cMed = new CVCMedication();

			Medication med = (Medication) entry.getResource();
			
			logger.debug("processing " + med.getIdBase() +" : "+med.getIdElement().getIdPart()); //processing Medication/19291000087108/_history/1.24 : 19291000087108
			if(dinManufactureMap.containsKey(med.getIdElement().getIdPart())) {
				cMed.setManufacturerDisplay(dinManufactureMap.get(med.getIdElement().getIdPart()));
				logger.debug("...adding :"+dinManufactureMap.get(med.getIdElement().getIdPart())+" for "+med.getIdElement().getIdPart());
			}
			if(dinDinMap.containsKey(med.getIdElement().getIdPart())) {
				cMed.setDin(dinDinMap.get(med.getIdElement().getIdPart()));
				cMed.setDinDisplayName(dinDinMap.get(med.getIdElement().getIdPart()));
				logger.debug("...adding din:"+dinDinMap.get(med.getIdElement().getIdPart())+" for "+med.getIdElement().getIdPart());
			}
		//	cMed.setBrand(med.getIsBrand());
			cMed.setStatus(med.getStatus().toString());

			for (Coding c : med.getCode().getCoding()) {
			/*
				if ("http://hl7.org/fhir/sid/ca-hc-din".equals(c.getSystem())) {
					cMed.setDin(c.getCode());
					cMed.setDinDisplayName(c.getDisplay());
					
				}
			*/
				if ("http://snomed.info/sct".equals(c.getSystem())) { 
					cMed.setSnomedCode(c.getCode());
					cMed.setSnomedDisplay(c.getDisplay());
					logger.debug("...adding snomed code / display:"+c.getCode()+"/"+c.getDisplay());
				}
				/*
				if ("http://www.gs1.org/gtin".equals(c.getSystem())) { // not a thing
					cMed.getGtinList().add(new CVCMedicationGTIN(cMed, c.getCode()));
				}
				*/
			}
			
			
			
			for (Extension ext : med.getExtension()) {		
				
				if ((getCVCURL() + "/StructureDefinition/nvc-market-authorization-holder").equals(ext.getUrl())) {
					cMed.setManufacturerDisplay(ext.getValue().primitiveValue());
				}

				if ((getCVCURL() + "/StructureDefinition/nvc-product-status").equals(ext.getUrl())) {
					CodeableConcept shelfStatusConcept = (CodeableConcept)ext.getValue();
					for(Coding parentConceptCode :shelfStatusConcept.getCoding()) {
						if ((getCVCURL() + "/ValueSet/ShelfStatus").equals(parentConceptCode.getSystem())) {
							cMed.setStatus(parentConceptCode.getDisplay());
						}
					}
					
					
				}
				
				if ((getCVCURL() + "/StructureDefinition/nvc-concept-last-updated").equals(ext.getUrl())) {
					
				}
				
				if ((getCVCURL() + "/StructureDefinition/nvc-container").equals(ext.getUrl())) {  //not a thing
					
				}
				
						
				if ((getCVCURL() + "/StructureDefinition/nvc-lots").equals(ext.getUrl())) {
					for(Extension lotsExt : ext.getExtension()) {
						if ((getCVCURL() + "/StructureDefinition/nvc-lot").equals(lotsExt.getUrl())) {
							String lotNumber = null;
							String expiry = null;
							for(Extension lotExt : lotsExt.getExtension()) {
								if ((getCVCURL() + "/StructureDefinition/nvc-lot-number").equals(lotExt.getUrl())) {
									lotNumber= lotExt.getValueAsPrimitive().getValueAsString();
								}
								if ((getCVCURL() + "/StructureDefinition/nvc-expiry-date").equals(lotExt.getUrl())) {
									expiry = lotExt.getValueAsPrimitive().getValueAsString();
								}
							}
							try {
								Date edate = formatter.parse(expiry);
								// add only future lot numbers to the picklist
								if(edate.after(curdate)) {  
									cMed.getLotNumberList().add(new CVCMedicationLotNumber(cMed, lotNumber, formatter.parse(expiry)));
								}
							}catch(ParseException e) {
								logger.warn("Error",e);
							}
						}
					}
				}
			}
			
			
/*
			if (med.getManufacturer() != null) {
				//med.getManufacturer().getIdentifier().getSystem();			
				cMed.setManufacturerId(med.getManufacturer().getIdentifier().getValue());
				cMed.setManufacturerDisplay(med.getManufacturer().getDisplay());
			}

			for (MedicationPackageBatchComponent comp : med.getPackage().getBatch()) {
				cMed.getLotNumberList().add(new CVCMedicationLotNumber(cMed, comp.getLotNumber(), comp.getExpirationDate()));
			}
*/
			//logger.info("saving a medication: " + cMed.getDinDisplayName());

			saveMedication(loggedInInfo, cMed);
		}

	}
	
	public void saveMedication(LoggedInInfo loggedInInfo, CVCMedication medication) {
		Set<CVCMedicationGTIN> gtins = medication.getGtinList();
		Set<CVCMedicationLotNumber> lotNumbers = medication.getLotNumberList();

		medication.setGtinList(null);
		medication.setLotNumberList(null);
		medicationDao.saveEntity(medication);

		for (CVCMedicationGTIN g : gtins) {
			gtinDao.saveEntity(g);
		}

		for (CVCMedicationLotNumber l : lotNumbers) {
			lotNumberDao.saveEntity(l);
		}

		//--- log action ---
		LogAction.addLogSynchronous(loggedInInfo, "CanadianVaccineCatalogueManager.saveMedication", medication.getId().toString());

	}

	public void updateAnatomicalSites(LoggedInInfo loggedInInfo, ValueSet vs) {
		int displayOrder = 0;
		String siteData = FhirContext.forR4().newJsonParser().encodeResourceToString(vs);
		
		//create and/or get reference to LookupList
		//clear existing list
		LookupListManager llm = SpringUtils.getBean(LookupListManager.class);
		LookupList ll = llm.findLookupListByName(loggedInInfo,"AnatomicalSite");
		if(ll == null) {
			ll = new LookupList();
			ll.setActive(true);
			ll.setCreatedBy("OSCAR");
			ll.setDateCreated(new Date());
			ll.setDescription("Anatomical Sites from CVC");
			ll.setName("AnatomicalSite");
			ll.setListTitle("Anatomical Site");
			ll = llm.addLookupList(loggedInInfo, ll);
		} else {
			llm.removeLookupListItems(loggedInInfo, ll.getId());
			ll = llm.findLookupListByName(loggedInInfo,"AnatomicalSite");
		}
		
		for (ConceptSetComponent c : vs.getCompose().getInclude()) {
			String version = c.getVersion();
			String system = c.getSystem();
			
			
			List<ConceptReferenceComponent> cons = c.getConcept();
			for (ConceptReferenceComponent cc : cons) {
				for(Extension ext : cc.getExtension()) {
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-status-extension").equals(ext.getUrl())) {
						String status = (String)ext.getValueAsPrimitive().getValue();
					}
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-last-updated").equals(ext.getUrl())) {
						Date dateLastUpdated = (Date)ext.getValueAsPrimitive().getValue();
					}
				}
				String code = cc.getCode();
				String display = cc.getDisplay();
				
				for(ConceptReferenceDesignationComponent crdc : cc.getDesignation()) {
					String language = crdc.getLanguage();
					String value = crdc.getValue();
					if(crdc.getUse() != null) {
						String useSystem = crdc.getUse().getSystem();
						String useCode = crdc.getUse().getCode();
						String useDisplay = crdc.getUse().getDisplay();
					}
				}
				
				LookupListItem lli = new LookupListItem();
				lli.setActive(true);
				lli.setCreatedBy("OSCAR");
				lli.setDateCreated(new Date());
				lli.setLabel(display);
				lli.setValue(code);
				lli.setLookupListId(ll.getId());
				lli.setDisplayOrder(displayOrder++);
				llm.addLookupListItem(loggedInInfo, lli);
			}	
		}
	}
	
	public void updateRoutes(LoggedInInfo loggedInInfo, ValueSet vs) {
		int displayOrder = 0;
		
		String routeData = FhirContext.forR4().newJsonParser().encodeResourceToString(vs);
		//logger.info("routeData=" + routeData);
		//create and/or get reference to LookupList
		//clear existing list
		LookupListManager llm = SpringUtils.getBean(LookupListManager.class);
		LookupList ll = llm.findLookupListByName(loggedInInfo,"RouteOfAdmin");
		if(ll == null) {
			ll = new LookupList();
			ll.setActive(true);
			ll.setCreatedBy("OSCAR");
			ll.setDateCreated(new Date());
			ll.setDescription("Routes of Administration from CVC");
			ll.setName("RouteOfAdmin");
			ll.setListTitle("Routes of Administration");
			ll = llm.addLookupList(loggedInInfo, ll);
		} else {
			llm.removeLookupListItems(loggedInInfo, ll.getId());
			ll = llm.findLookupListByName(loggedInInfo,"RouteOfAdmin");
		}
		
		for (ConceptSetComponent c : vs.getCompose().getInclude()) {
			String version = c.getVersion();
			String system = c.getSystem();
			
			List<ConceptReferenceComponent> cons = c.getConcept();
			for (ConceptReferenceComponent cc : cons) {
				for(Extension ext : cc.getExtension()) {
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-status-extension").equals(ext.getUrl())) {
						String status = (String)ext.getValueAsPrimitive().getValue();
					}
					if ((getCVCURL() + "/StructureDefinition/nvc-concept-last-updated").equals(ext.getUrl())) {
						Date dateLastUpdated = (Date)ext.getValueAsPrimitive().getValue();
					}
				}
				String code = cc.getCode();
				String display = cc.getDisplay();
				
				for(ConceptReferenceDesignationComponent crdc : cc.getDesignation()) {
					String language = crdc.getLanguage();
					String value = crdc.getValue();
					if(crdc.getUse() != null) {
						String useSystem = crdc.getUse().getSystem();
						String useCode = crdc.getUse().getCode();
						String useDisplay = crdc.getUse().getDisplay();
					}
				}
				
				LookupListItem lli = new LookupListItem();
				lli.setActive(true);
				lli.setCreatedBy("OSCAR");
				lli.setDateCreated(new Date());
				lli.setLabel(display);
				lli.setValue(code);
				lli.setLookupListId(ll.getId());
				lli.setDisplayOrder(displayOrder++);
				llm.addLookupListItem(loggedInInfo, lli);
			}	
		}
		
	}
	
	public static String getCVCURL() {
		String url = OscarProperties.getInstance().getProperty("cvc.url");
		UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
		
		UserProperty up =  upDao.getProp("cvc.url");
		if(up != null && !StringUtils.isEmpty(up.getValue())) {
			url = up.getValue();
		}
		
		return url;
	}
	
	public static boolean getCVCActive(Date creationDate) {
		boolean cvcActive = false;
		UserPropertyDAO upDao = SpringUtils.getBean(UserPropertyDAO.class);
		UserProperty up =  upDao.getProp(CVCFirstDate);
		
		if(up != null && !StringUtils.isEmpty(up.getValue())) {
			if(creationDate == null) {
				cvcActive = true;
			}else {
				long timeInMillis = Long.parseLong(up.getValue());
				Date cvcfirstDate = new Date(timeInMillis);
				if(cvcfirstDate.before(creationDate)) {
					cvcActive = true;
				}
			}
		}
		
		return cvcActive;
	}
	
}
