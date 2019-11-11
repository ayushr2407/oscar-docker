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

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;

import org.oscarehr.common.dao.CtlDocumentDao;
import org.oscarehr.common.dao.DocumentDao;
import org.oscarehr.common.dao.ProviderInboxRoutingDao;
import org.oscarehr.common.model.ConsentType;
import org.oscarehr.common.model.CtlDocument;
import org.oscarehr.common.model.Document;
import org.oscarehr.common.model.ProviderInboxItem;
import org.oscarehr.util.LoggedInInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import oscar.log.LogAction;

@Service
public class DocumentManager {
	@Autowired
	private DocumentDao documentDao;

	@Autowired
	private CtlDocumentDao ctlDocumentDao;
	
	@Autowired
	private PatientConsentManager patientConsentManager;
	
	@Autowired
	private ProviderInboxRoutingDao providerInboxRoutingDao;
	
	public Document getDocument(LoggedInInfo loggedInInfo, Integer id)
	{
		Document result=documentDao.find(id);
		
		//--- log action ---
		if (result != null) {
			LogAction.addLogSynchronous(loggedInInfo, "DocumentManager.getDocument", "id=" + id);
		}

		return(result);
	}
	
	public CtlDocument getCtlDocumentByDocumentId(LoggedInInfo loggedInInfo, Integer documentId)
	{
		CtlDocument result=ctlDocumentDao.getCtrlDocument(documentId);
		
		//--- log action ---
		if (result != null) {
			LogAction.addLogSynchronous(loggedInInfo, "DocumentManager.getCtlDocumentByDocumentNoAndModule", "id=" + documentId);
		}

		return(result);
	}
	
	public List<Document> getDocumentsUpdateAfterDate(LoggedInInfo loggedInInfo, Date updatedAfterThisDateExclusive, int itemsToReturn) {
		List<Document> results = documentDao.findByUpdateDate(updatedAfterThisDateExclusive, itemsToReturn);

		LogAction.addLogSynchronous(loggedInInfo, "DocumentManager.getUpdateAfterDate", "updatedAfterThisDateExclusive=" + updatedAfterThisDateExclusive);

		return (results);
	}
	
	public List<Document> getDocumentsByDemographicIdUpdateAfterDate(LoggedInInfo loggedInInfo, Integer demographicId, Date updatedAfterThisDateExclusive) {
		List<Document> results = new ArrayList<Document>();
		ConsentType consentType = patientConsentManager.getProviderSpecificConsent(loggedInInfo);
		if (patientConsentManager.hasPatientConsented(demographicId, consentType)) {
			results = documentDao.findByDemographicUpdateAfterDate(demographicId, updatedAfterThisDateExclusive);
			LogAction.addLogSynchronous(loggedInInfo, "DocumentManager.getDocumentsByDemographicIdUpdateAfterDate", "demographicId="+demographicId+" updatedAfterThisDateExclusive="+updatedAfterThisDateExclusive);
		}
		return (results);
	}

	public List<Document> getDocumentsByProgramProviderDemographicDate(LoggedInInfo loggedInInfo, Integer programId, String providerNo, Integer demographicId, Calendar updatedAfterThisDateExclusive, int itemsToReturn) {
		List<Document> results = documentDao.findByProgramProviderDemographicUpdateDate(programId, providerNo, demographicId, updatedAfterThisDateExclusive.getTime(), itemsToReturn);

		LogAction.addLogSynchronous(loggedInInfo, "DocumentManager.getDocumentsByProgramProviderDemographicDate", "programId=" + programId+", providerNo="+providerNo+", demographicId="+demographicId+", updatedAfterThisDateExclusive="+updatedAfterThisDateExclusive.getTime());

		return (results);
	}

	public List<String> getProvidersThatHaveAcknowledgedDocument(LoggedInInfo loggedInInfo, Integer documentId) {
		List<ProviderInboxItem> inboxList = providerInboxRoutingDao.getProvidersWithRoutingForDocument("DOC", documentId);
		List<String> providerList = new ArrayList<String>();
		for(ProviderInboxItem item: inboxList) {
			if(ProviderInboxItem.ACK.equals(item.getStatus())){ 
				//If this has been acknowledge add the provider_no to the list.
				providerList.add(item.getProviderNo());
			}
		}
		return providerList;
	}
}
