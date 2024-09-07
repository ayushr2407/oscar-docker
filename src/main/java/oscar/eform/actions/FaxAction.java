/**
 * Copyright (c) 2008-2012 Indivica Inc.
 *
 * This software is made available under the terms of the
 * GNU General Public License, Version 2, 1991 (GPLv2).
 * License details are available via "indivica.ca/gplv2"
 * and "gnu.org/licenses/gpl-2.0.html".
 */
package oscar.eform.actions;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;

import javax.servlet.http.HttpServletRequest;

import com.sun.xml.messaging.saaj.util.ByteInputStream;
import com.sun.xml.messaging.saaj.util.ByteOutputStream;

import org.apache.commons.io.FileUtils;
import org.apache.logging.log4j.Logger;
import org.oscarehr.common.dao.EFormDataDao;
import org.oscarehr.common.model.EFormData;
import org.oscarehr.hospitalReportManager.dao.HRMDocumentToDemographicDao;
import org.oscarehr.hospitalReportManager.model.HRMDocumentToDemographic;
import org.oscarehr.hospitalReportManager.HRMPDFCreator;
import org.oscarehr.util.LoggedInInfo;
import org.oscarehr.util.MiscUtils;
import org.oscarehr.util.SpringUtils;
import org.oscarehr.util.WKHtmlToPdfUtils;

import oscar.dms.EDoc;
import oscar.dms.EDocUtil;
import oscar.eform.EFormUtil;
import oscar.oscarEncounter.oscarConsultationRequest.pageUtil.ImagePDFCreator;
import oscar.oscarLab.ca.all.pageUtil.LabPDFCreator;
import oscar.oscarLab.ca.on.CommonLabResultData;
import oscar.oscarLab.ca.on.LabResultData;
import oscar.OscarProperties;
import oscar.util.ConcatPDF;

import com.itextpdf.text.DocumentException;

public final class FaxAction {

	private static final Logger logger = MiscUtils.getLogger();

	private String localUri = null;
	
	private boolean skipSave = false;

	public FaxAction(HttpServletRequest request) {
		localUri = getEformRequestUrl(request);
		skipSave = "true".equals(request.getParameter("skipSave"));
	}

	/**
	 * This method is a copy of Apache Tomcat's ApplicationHttpRequest getRequestURL method with the exception that the uri is removed and replaced with our eform viewing uri. Note that this requires that the remote url is valid for local access. i.e. the
	 * host name from outside needs to resolve inside as well. The result needs to look something like this : https://127.0.0.1:8443/oscar/eformViewForPdfGenerationServlet?fdid=2&parentAjaxId=eforms
	 */
	private String getEformRequestUrl(HttpServletRequest request) {
		StringBuilder url = new StringBuilder();
		String scheme = request.getScheme();
		Integer port;
		try { port = new Integer(OscarProperties.getInstance().getProperty("oscar_port")); }
	    catch (Exception e) { port = 8443; }
		if (port < 0) port = 80; // Work around java.net.URL bug

		url.append(scheme);
		url.append("://");
		//url.append(request.getServerName());
		url.append("127.0.0.1");
		
		if ((scheme.equals("http") && (port != 80)) || (scheme.equals("https") && (port != 443))) {
			url.append(':');
			url.append(port);
		}
		url.append(request.getContextPath());
		url.append("/EFormViewForPdfGenerationServlet?parentAjaxId=eforms&prepareForFax=true&providerId=");
		url.append(request.getParameter("providerId"));
		url.append("&fdid=");

		return (url.toString());
	}

	/**
	 * This method will take eforms and send them to files for faxing.
	 * @throws DocumentException 
	 */
	
		public void faxForms(HttpServletRequest request, LoggedInInfo loggedInInfo, String[] numbers, String formId, String providerId) {	
		File tempFile = null;

		byte[] buffer;
		ByteInputStream bis;
		ByteOutputStream bos;
		ArrayList<InputStream> streams = new ArrayList<InputStream>();
		ArrayList<Object> alist = new ArrayList<Object>();
		
		EFormDataDao efmDataDao = SpringUtils.getBean(EFormDataDao.class);
		EFormData eformData = efmDataDao.find(Integer.parseInt(formId));
		ArrayList<EDoc> docs = EDocUtil.listDocsAttachedToEForm(loggedInInfo, String.valueOf(eformData.getDemographicId()), formId, EDocUtil.ATTACHED);
		String path = OscarProperties.getInstance().getProperty("DOCUMENT_DIR");
		
		CommonLabResultData consultLabs = new CommonLabResultData();
		ArrayList<LabResultData> labs = consultLabs.populateLabResultsDataEForm(loggedInInfo, String.valueOf(eformData.getDemographicId()), formId, CommonLabResultData.ATTACHED);
		HRMDocumentToDemographicDao hrmDocumentToDemographicDao = SpringUtils.getBean(HRMDocumentToDemographicDao.class);
		List<HRMDocumentToDemographic> attachedHRMReports = hrmDocumentToDemographicDao.findHRMDocumentsAttachedToEForm(formId);

		try {
			tempFile = File.createTempFile("EForm." + formId, ".pdf");

			logger.info("Writing a base pdf to : "+"EForm." + formId + ".pdf");
			
			bos = new ByteOutputStream();
			buffer = WKHtmlToPdfUtils.convertToPdf(localUri + formId);
			bis = new ByteInputStream(buffer, buffer.length);
            streams.add(bis);
            alist.add(bis);
			for (int i = 0; i < docs.size(); i++) {
				EDoc doc = docs.get(i);  
				if (doc.isPrintable()) {
					if (doc.isImage()) {
						bos = new ByteOutputStream();
						request.setAttribute("imagePath", path + doc.getFileName());
						request.setAttribute("imageTitle", doc.getDescription());
						ImagePDFCreator ipdfc = new ImagePDFCreator(request, bos);
						ipdfc.printPdf();
						
						buffer = bos.getBytes();
						bis = new ByteInputStream(buffer, bos.getCount());
						bos.close();
						streams.add(bis);
						alist.add(bis);
						
					}
					else if (doc.isPDF()) {
						alist.add(path + doc.getFileName());
					}
					else {
						logger.error("EctConsultationFormRequestPrintAction: " + doc.getType() + " is marked as printable but no means have been established to print it.");	
					}
				}
			}

			// Iterating over requested labs.
			for (int i = 0; labs != null && i < labs.size(); i++) {
				// Storing the lab in PDF format inside a byte stream.
				bos = new ByteOutputStream();
				request.setAttribute("segmentID", labs.get(i).segmentID);
				LabPDFCreator lpdfc = new LabPDFCreator(request, bos);
				lpdfc.printPdf();

				// Transferring PDF to an input stream to be concatenated with
				// the rest of the documents.
				buffer = bos.getBytes();
				bis = new ByteInputStream(buffer, bos.getCount());
				bos.close();
				streams.add(bis);
				alist.add(bis);

			}

			for (HRMDocumentToDemographic attachedHRM : attachedHRMReports) {
				bos = new ByteOutputStream();
				HRMPDFCreator hrmPdfCreator = new HRMPDFCreator(bos, attachedHRM.getHrmDocumentId(), loggedInInfo);
				hrmPdfCreator.printPdf();

				buffer = bos.getBytes();
				bis = new ByteInputStream(buffer, bos.getCount());
				bos.close();
				streams.add(bis);
				alist.add(bis);
			}
			
			List<EFormData> eForms = EFormUtil.listPatientEformsCurrentAttachedToEForm(formId);
            for (EFormData eForm : eForms) {
                String localUri = PrintAction.getEformRequestUrl(request);
                buffer = WKHtmlToPdfUtils.convertToPdf(localUri + eForm.getId());
                bis = new ByteInputStream(buffer, buffer.length);
                streams.add(bis);
                alist.add(bis);
            }
            
			if (alist.size() > 0) {
				
				bos = new ByteOutputStream();
				ConcatPDF.concat(alist, bos);
				byte[] data = bos.toByteArray();
				FileOutputStream fos = new FileOutputStream(tempFile);
				fos.write(data);
				// Close the FileOutputStream
			    fos.close();
			}
		
			// Removing all non digit characters from fax numbers.
			for (int i = 0; i < numbers.length; i++) { 
				numbers[i] = numbers[i].trim().replaceAll("\\D", "");
			}
			ArrayList<String> recipients = new ArrayList<String>(Arrays.asList(numbers));
			
			// Removing duplicate phone numbers.
			recipients = new ArrayList<String>(new HashSet<String>(recipients));
			String tempPath = OscarProperties.getInstance().getProperty(
				"fax_file_location", System.getProperty("java.io.tmpdir"));
			FileOutputStream fos;
			
			for (int i = 0; i < recipients.size(); i++) {					
			    String faxNo = recipients.get(i).trim().replaceAll("\\D", "");
				logger.info("Generating PDF and text files for recipient "+faxNo+" for eForm " + formId);	
			    if (faxNo.length() < 7) { throw new DocumentException("Document target fax number '"+faxNo+"' is invalid."); }
			    String tempName = "EForm-" + formId + "." + System.currentTimeMillis();
				
				String tempPdf = String.format("%s%s%s.pdf", tempPath, File.separator, tempName);
				String tempTxt = String.format("%s%s%s.txt", tempPath, File.separator, tempName);
			
				// Copying the fax pdf.
				FileUtils.copyFile(tempFile, new File(tempPdf));
				
				// Creating text file with the specialists fax number.
				fos = new FileOutputStream(tempTxt);				
				PrintWriter pw = new PrintWriter(fos);
				pw.println(faxNo);
				pw.close();
				fos.close();
				
				// A little sanity check to ensure both files exist.
				if (!new File(tempPdf).exists() || !new File(tempTxt).exists()) {
					throw new DocumentException("Unable to create files for fax of eform " + formId + ".");
				}		
				if (skipSave) {
		        	 EFormDataDao eFormDataDao=(EFormDataDao) SpringUtils.getBean("EFormDataDao");
		        	 EFormData eFormData=eFormDataDao.find(Integer.parseInt(formId));
		        	 eFormData.setCurrent(false);
		        	 eFormDataDao.merge(eFormData);
				}
			}
			// Removing the eform pdf.
			tempFile.delete();			
						
		} catch (DocumentException | IOException e) {
			MiscUtils.getLogger().error("Error converting and sending eform. id="+formId, e);
		} 
	}

}
