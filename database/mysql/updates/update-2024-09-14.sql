-- update-2024-09-14.sql
-- this moves existing preventions to Health Canada codes as used by PHAC and 
-- the National Vaccine Catalog, the NVC https://nvc-cnv.canada.ca/en/vaccine-catalogue

UPDATE `preventions` SET `prevention_type`="Pneu-P-23" WHERE `prevention_type` = "Pneumovax";
UPDATE `preventions` SET `prevention_type`="Inf" WHERE `prevention_type` ="Flu";
UPDATE `preventions` SET `prevention_type`="LZV" WHERE `prevention_type` ="HZV";
UPDATE `preventions` SET `prevention_type`="Rota" WHERE `prevention_type` ="Rot";
UPDATE `preventions` SET `prevention_type`="MMR-Var" WHERE `prevention_type` ="MMRV";
UPDATE `preventions` SET `prevention_type`="HB" WHERE `prevention_type` ="HepB";
UPDATE `preventions` SET `prevention_type`="HAHB" WHERE `prevention_type` ="HepAB";
UPDATE `preventions` SET `prevention_type`="Var" WHERE `prevention_type` ="VZ";
UPDATE `preventions` SET `prevention_type`="Tdap" WHERE `prevention_type` ="dTap";	
UPDATE `preventions` SET `prevention_type`="RSV" WHERE `prevention_type` ="RSVPreF3";

-- CVC to NVC conversions, safe to run even if you never used CVC, essential if you have

UPDATE `preventions` SET `prevention_type`="Zos" WHERE `prevention_type` LIKE "[Zos]%";
UPDATE `preventions` SET `prevention_type`="YF" WHERE `prevention_type` LIKE "[YF]%";
UPDATE `preventions` SET `prevention_type`="Var" WHERE `prevention_type` LIKE "[Var]%";
UPDATE `preventions` SET `prevention_type`="Typh" WHERE `prevention_type` LIKE "[Typh%";
UPDATE `preventions` SET `prevention_type`="Td" WHERE `prevention_type` LIKE "[Td]%";
UPDATE `preventions` SET `prevention_type`="Tdap" WHERE `prevention_type` LIKE "[Tdap]%";
UPDATE `preventions` SET `prevention_type`="Tdap-IPV" WHERE `prevention_type` LIKE "[Tdap-IPV]%";
UPDATE `preventions` SET `prevention_type`="RSV" WHERE `prevention_type` LIKE "[RSV]%";
UPDATE `preventions` SET `prevention_type`="RSVAb" WHERE `prevention_type` LIKE "[RSVAb]%";
UPDATE `preventions` SET `prevention_type`="Rota" WHERE `prevention_type` LIKE "[Rota]%";
UPDATE `preventions` SET `prevention_type`="Rota" WHERE `prevention_type` LIKE "[Rota-1]%";
UPDATE `preventions` SET `prevention_type`="Rota-5" WHERE `prevention_type` LIKE "[Rota-5]%";
UPDATE `preventions` SET `prevention_type`="Rab" WHERE `prevention_type` LIKE "[Rab]%";
UPDATE `preventions` SET `prevention_type`="COVID-19" WHERE `prevention_type` LIKE "[COVID%";
UPDATE `preventions` SET `prevention_type`="Inf" WHERE `prevention_type` LIKE "[Inf%";
UPDATE `preventions` SET `prevention_type`="Pneu" WHERE `prevention_type` LIKE "[Pneu]%";
UPDATE `preventions` SET `prevention_type`="Pneu-P" WHERE `prevention_type` LIKE "[Pneu-P]%";
UPDATE `preventions` SET `prevention_type`="Pneu-P-23" WHERE `prevention_type` LIKE "[Pneu-P-23]%";
UPDATE `preventions` SET `prevention_type`="Pneu-C-20" WHERE `prevention_type` LIKE "[Pneu-C-20]%";
UPDATE `preventions` SET `prevention_type`="Pneu-C-15" WHERE `prevention_type` LIKE "[Pneu-C-15]%";
UPDATE `preventions` SET `prevention_type`="Pneu-C-13" WHERE `prevention_type` LIKE "[Pneu-C-13]%";
UPDATE `preventions` SET `prevention_type`="Pneu-C-10" WHERE `prevention_type` LIKE "[Pneu-C-10]%";
UPDATE `preventions` SET `prevention_type`="Pneu-C-7" WHERE `prevention_type` LIKE "[Pneu-C-7]%";
UPDATE `preventions` SET `prevention_type`="OPV" WHERE `prevention_type` LIKE "[OPV]%";
UPDATE `preventions` SET `prevention_type`="M" WHERE `prevention_type` LIKE "[M]%";
UPDATE `preventions` SET `prevention_type`="MMR" WHERE `prevention_type` LIKE "[MMR]%";
UPDATE `preventions` SET `prevention_type`="MMR-Var" WHERE `prevention_type` LIKE "[MMR-Var]%";
UPDATE `preventions` SET `prevention_type`="Men" WHERE `prevention_type` LIKE "[Men]%";
UPDATE `preventions` SET `prevention_type`="Men-C" WHERE `prevention_type` LIKE "[Men-C]%";
UPDATE `preventions` SET `prevention_type`="Men-C-C" WHERE `prevention_type` LIKE "[Men-C-C]%";
UPDATE `preventions` SET `prevention_type`="Men-C-ACYW" WHERE `prevention_type` LIKE "[Men-C-ACYW]%";
UPDATE `preventions` SET `prevention_type`="Men-C-ACYW-135" WHERE `prevention_type` LIKE "[Men-C-ACYW-135]%";
UPDATE `preventions` SET `prevention_type`="Men-ACYW-135" WHERE `prevention_type` LIKE "[Men-ACYW-135]%";
UPDATE `preventions` SET `prevention_type`="JE" WHERE `prevention_type` LIKE "[JE]%";
UPDATE `preventions` SET `prevention_type`="IPV" WHERE `prevention_type` LIKE "[IPV]%";
UPDATE `preventions` SET `prevention_type`="HPV" WHERE `prevention_type` LIKE "[HPV]%";
UPDATE `preventions` SET `prevention_type`="HPV-4" WHERE `prevention_type` LIKE "[HPV-4]%";
UPDATE `preventions` SET `prevention_type`="HPV-9" WHERE `prevention_type` LIKE "[HPV-9]%";
UPDATE `preventions` SET `prevention_type`="Hib" WHERE `prevention_type` LIKE "[Hib]%";
UPDATE `preventions` SET `prevention_type`="HB" WHERE `prevention_type` LIKE "[HB]%";
UPDATE `preventions` SET `prevention_type`="HAHB" WHERE `prevention_type` LIKE "[HAHB]%";
UPDATE `preventions` SET `prevention_type`="HA" WHERE `prevention_type` LIKE "[HA]%";
UPDATE `preventions` SET `prevention_type`="DT" WHERE `prevention_type` LIKE "[DT]%";
UPDATE `preventions` SET `prevention_type`="DTaP" WHERE `prevention_type` LIKE "[DTaP]%";
UPDATE `preventions` SET `prevention_type`="DTaP-IPV" WHERE `prevention_type` LIKE "[DTaP-IPV]%";
UPDATE `preventions` SET `prevention_type`="DTaP-IPV-Hib" WHERE `prevention_type` LIKE "[DTaP-IPV-Hib]%";
UPDATE `preventions` SET `prevention_type`="DTaP-HB-IPV-Hib" WHERE `prevention_type` LIKE "[DTaP-HB-IPV-Hib]%";
UPDATE `preventions` SET `prevention_type`="DPT" WHERE `prevention_type` LIKE "[DPT]%";
UPDATE `preventions` SET `prevention_type`="DPT-Hib" WHERE `prevention_type` LIKE "[DPT-Hib]%";
UPDATE `preventions` SET `prevention_type`="Chol-Ecol-O" WHERE `prevention_type` LIKE "[Chol-Ecol-O]%";
UPDATE `preventions` SET `prevention_type`="BCG" WHERE `prevention_type` LIKE "[BCG]%";