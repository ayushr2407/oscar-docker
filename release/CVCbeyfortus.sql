-- patch for Beyfortus RSV vaccine
INSERT INTO `CVCImmunization` ( versionId, snomedConceptId, generic, parentConceptId, ispa, typicalDose, typicalDoseUofM, strength, shelfStatus)
VALUES ( '0', '58531000087106', '1', '', '0', '0.5', 'mL', '100 mg', 'Marketed');
SET @gen_imm_id = LAST_INSERT_ID();

INSERT INTO `CVCImmunization` ( versionId, snomedConceptId, generic, parentConceptId, ispa, typicalDose, typicalDoseUofM, strength, shelfStatus)
VALUES ( '0', '58291000087105', '0', '58531000087106', '0', '0.5', 'mL', '100 mg', 'Marketed');
SET @trade_imm_id = LAST_INSERT_ID();


INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','http://snomed.info/sct', '900000000000003001','Fully Specified Name','Product containing only nirsevimab (medicinal product)', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','http://snomed.info/sct', '900000000000013009','Synonym','RSVAb respiratory syncytial virus unspecified', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','http://snomed.info/sct', '900000000000013009','Synonym','RSVAc respiratory syncytial virus unspecified', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enPublicPicklistTerm','Public Tradename Picklist (en)','Respiratory syncytial virus', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frPublicPicklistTerm','Public Tradename Picklist (fr)','virus respiratoire syncytial', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enClinicianPicklistTerm','Clinician Tradename Picklist (en)','[RSVAb] Respiratory syncytial virus', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frClinicianPicklistTerm','Clinician Tradename Picklist (fr)','[RSVAc] virus respiratoire syncytial', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enAbbreviation','Generic Agent Abbreviation (en)','RSVAb', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frAbbreviation','Generic Agent Abbreviation (fr)','RSVAc', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enAbbreviationON','Ontario Generic Agent Abbreviation (en)','RSVAb', @gen_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frAbbreviationON','Ontario Generic Agent Abbreviation (fr)','RSVAc', @gen_imm_id);

INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','http://snomed.info/sct', '900000000000003001','Fully Specified Name','BEYFORTUS 100 milligrams per 1 milliliter solution for injection syringe Sanofi Pasteur Limited (real clinical drug)', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','http://snomed.info/sct', '900000000000013009','Synonym','RSVAb BEYFORTUS 100 mg/1 mL syringe SP', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','http://snomed.info/sct', '900000000000013009','Synonym','RSVAc BEYFORTUS 100 mg/1 mL seringue SP', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enPublicPicklistTerm','Public Tradename Picklist (en)','Respiratory syncytial virus', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frPublicPicklistTerm','Public Tradename Picklist (fr)','Respiratory syncytial virus', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enClinicianPicklistTerm', 'Clinician Tradename Picklist (en)', 'BEYFORTUS (RSVAb)', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frClinicianPicklistTerm', 'Clinician Tradename Picklist (fr)', 'BEYFORTUS (RSVAc)', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enAbbreviation','Generic Agent Abbreviation (en)','RSVAb', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frAbbreviation','Generic Agent Abbreviation (fr)','RSVAc', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('en','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'enAbbreviationON','Ontario Generic Agent Abbreviation (en)','RSVAb', @trade_imm_id);
INSERT INTO `CVCImmunizationName` (language,useSystem,useCode,useDisplay,`value`,CVCImmunizationId)
VALUES ('fr','https://api.cvc.canimmunize.ca/v3/NamingSystem/ca-cvc-display-terms-designation', 'frAbbreviationON','Ontario Generic Agent Abbreviation (fr)','RSVAc', @trade_imm_id);

INSERT INTO `CVCMedication` (versionId,din,dinDisplayName,snomedCode,snomedDisplay,status,isBrand,manufacturerDisplay)
VALUES ('0',2537214 ,'02537214 ', '58291000087105', 'BEYFORTUS 100 milligrams per 1 milliliter solution for injection syringe Sanofi Pasteur Limited', 'Marketed','0','Sanofi');
SET @cvcmed_id = LAST_INSERT_ID();

INSERT INTO `CVCMedicationGTIN` (cvcMedicationId, gtin) VALUES (@cvcmed_id,"None");

-- INSERT INTO `CVCMedicationLotNumber` (cvcMedicationId, lotNumber, expiryDate) VALUES (@cvcmed_id,"lotNo", "2025-03-31");
