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
package org.oscarehr.integration.born;

import java.io.IOException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
//import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.*;
import java.util.stream.Collectors;


import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.logging.log4j.Logger;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;
import org.apache.struts.actions.DispatchAction;
import org.oscarehr.common.model.CVCImmunization;
import org.oscarehr.common.model.CVCMedication;
import org.oscarehr.common.model.CVCMedicationLotNumber;
import org.oscarehr.managers.CanadianVaccineCatalogueManager;
import org.oscarehr.managers.CanadianVaccineCatalogueManager2;
import org.oscarehr.managers.SecurityInfoManager;
import org.oscarehr.util.LoggedInInfo;
import org.oscarehr.util.MiscUtils;
import org.oscarehr.util.SpringUtils;

import net.sf.json.JSONArray;
import net.sf.json.JSONObject;

/**
 * 
 * @author marc
 *
 *
 */
public class CVCTesterAction extends DispatchAction {

	Logger logger = MiscUtils.getLogger();
	
	CanadianVaccineCatalogueManager cvcManager = SpringUtils.getBean(CanadianVaccineCatalogueManager.class);
	private SecurityInfoManager securityInfoManager = SpringUtils.getBean(SecurityInfoManager.class);
	
	public ActionForward updateCVC(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws Exception {
		//
		 if(!securityInfoManager.hasPrivilege(LoggedInInfo.getLoggedInInfoFromSession(request), "_prevention.updateCVC", "r", null)) {
             throw new SecurityException("missing required security object (_prevention.updateCVC)");
           }

		CanadianVaccineCatalogueManager2 cvcManager2 = SpringUtils.getBean(CanadianVaccineCatalogueManager2.class);
		logger.info("starting CVC update");
		try {
			cvcManager2.update(LoggedInInfo.getLoggedInInfoFromSession(request));
		}catch(Exception e) {
			logger.error("error",e);
			//response.setStatus(400,e.getLocalizedMessage());
			response.sendError(400,e.getLocalizedMessage());
			return null;
		}
		logger.info("completed CVC update");
		return null;
	}
	
	public ActionForward addLotNumberAndExpiryDates(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws IOException, ParseException {
		String snomedConceptId = request.getParameter("snomedConceptId");
		String lot = request.getParameter("lot");
		String expiry = request.getParameter("expiry");
		String reply = "fail";
		SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd");
		Date lotExpiry = formatter.parse(expiry);
		
		if(snomedConceptId != null) {
			CVCMedication med = cvcManager.getMedicationBySnomedConceptId(snomedConceptId);
			reply = cvcManager.saveLot(med,lot,lotExpiry);
		}
		response.setContentType("text/plain"); 
		response.setCharacterEncoding("UTF-8"); 
		response.getWriter().write(reply);
		return null;
	}
	
	
	public ActionForward deleteLotNumbers(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws IOException, ParseException {
		String snomedConceptId = request.getParameter("snomedConceptId");
		String lots = request.getParameter("lots");
		String reply = "";
		List<String> list =
		  Stream.of(lots.split(","))
		  .collect(Collectors.toList());
		if(snomedConceptId != null) {
			for(String lot : list) {
				reply += cvcManager.deleteLot(snomedConceptId,lot) + " ";
			}
		}
		response.setContentType("text/plain"); 
		response.setCharacterEncoding("UTF-8"); 
  		response.getWriter().write(reply.trim());
		return null;
	}
	
	public ActionForward getLotNumberAndExpiryDates(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws IOException {
		String snomedConceptId = request.getParameter("snomedConceptId");
		if(snomedConceptId != null) {
			CVCMedication med = cvcManager.getMedicationBySnomedConceptId(snomedConceptId);
			JSONObject result = new JSONObject();
			
			JSONArray json =  new JSONArray();
			for(CVCMedicationLotNumber ln : med.getLotNumberList()) {
				JSONObject obj = new JSONObject();
				obj.put("lotNumber", ln.getLotNumber());
				obj.put("expiryDate", ln.getExpiryDate());
				json.add(obj);
			}
			result.put("lots",json);
			
			CVCImmunization imm = cvcManager.getBrandNameImmunizationBySnomedCode(LoggedInInfo.getLoggedInInfoFromSession(request), snomedConceptId);
			if(imm != null) {
				JSONObject t = new JSONObject();
				t.put("dose",imm.getTypicalDose());
				t.put("UoM",imm.getTypicalDoseUofM());
				t.put("route",imm.getRoute());
				result.put("typicalDose",t);
			}
			result.write(response.getWriter());
		}
		return null;
	}
	
	public ActionForward getDIN(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws IOException {
		String snomedConceptId = request.getParameter("snomedConceptId");
		if(snomedConceptId != null) {
			CVCMedication med = cvcManager.getMedicationBySnomedConceptId(snomedConceptId);
			String din = med.getDinDisplayName();
			JSONObject json =  new JSONObject();
			json.put("din", din);
			json.put("manufacture", med.getManufacturerDisplay());
			json.put("status", med.getStatus());			
			json.write(response.getWriter());
		}
		return null;
	}
	

	public ActionForward query(ActionMapping mapping, ActionForm form, HttpServletRequest request, HttpServletResponse response) throws IOException {
		String query = request.getParameter("query");
		
		JSONArray arr = new JSONArray();
		StringBuilder matchedLotNumber = new StringBuilder();
		
		
		List<CVCImmunization> results = new ArrayList<CVCImmunization>();
		
		//name
		List<CVCImmunization> l1 = cvcManager.query(query, true, true, false, false,null);
		
		//lot#
		List<CVCImmunization> l2 = cvcManager.query(query, false, false, true, false,matchedLotNumber);
		
		//GTIN not availabe in NVC
		//List<CVCImmunization> l3 = cvcManager.query(query, false, false, false, true,null);
		
		results.addAll(l1);
		results.addAll(l2);
		//results.addAll(l3);
		
		//unique it
		Map<String, CVCImmunization> tmp = new HashMap<String, CVCImmunization>();
		for (CVCImmunization i : results) {
			tmp.put(i.getSnomedConceptId(), i);
		}
		List<CVCImmunization> uniqueResults = new ArrayList<CVCImmunization>(tmp.values());

		//sort it prevalence not available in NVC
		//Collections.sort(uniqueResults, new PrevalenceComparator());
				
		
		
		for(CVCImmunization result:uniqueResults) {
			JSONObject obj = new JSONObject();
			obj.put("name", result.getPicklistName());
			obj.put("generic", result.isGeneric());
			obj.put("genericSnomedId", result.isGeneric() ? result.getSnomedConceptId() : result.getParentConceptId());
			obj.put("snomedId",result.getSnomedConceptId());
			obj.put("lotNumber", uniqueResults.size() == 1 && matchedLotNumber != null && matchedLotNumber.length()>0 ? matchedLotNumber.toString() : "");
			arr.add(obj);
		}
		
		JSONObject t = new JSONObject();
		t.put("results",arr);
		response.setContentType("application/json");
		t.write(response.getWriter());
		
		return null;
	}
	
}

class PrevalenceComparator implements Comparator<CVCImmunization> {
    public int compare( CVCImmunization i1, CVCImmunization i2 ) {
		//note that prevalence is not currently populated by the NVC bundle  
            Integer d1 = i1.getPrevalence();
            Integer d2 = i2.getPrevalence();
            
            if( d1 == null && d2 != null )
                    return 1;
            else if( d1 != null && d2 == null )
                    return -1;
            else if( d1 == null && d2 == null )
                    return 0;
            else
                    return d1.compareTo(d2) * -1;
    }
}