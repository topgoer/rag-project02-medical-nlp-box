import json
from ner_service import NERService
from std_service import StdService

# Initialize services
ner_service = NERService()
std_service = StdService()

# List of 100 medical notes (you should replace this with your actual list of notes)
medical_sentences = [
    "HCV cirrhosis c/b ascites, hiv on ART, h/o IVDU, COPD, bipolar, PTSD, presented from OSH ED with worsening abd distension over past week.",
    "Pt reports self-discontinuing lasix and spirnolactone weeks ago, because she feels like 'they don't do anything' and that she 'doesn't want to put more chemicals in her.'",
    "She does not follow Na-restricted diets.",
    "In the past week, she notes that she has been having worsening abd distension and discomfort.",
    "She denies edema, SOB, or orthopnea.",
    "She denies fever, chills, nausea, vomiting, diarrhea, or dysuria.",
    "She had food poisoning a week ago from eating stale cake, which resolved the same day.",
    "She denies other recent illness or sick contacts.",
    "She notes that she has been noticing gum bleeding while brushing her teeth in recent weeks.",
    "She denies easy bruising, melena, bright red blood per rectum, hemetesis, hemoptysis, or hematuria.",
    "Because of her abdominal pain, she went to OSH ED and was transferred to this hospital for further care.",
    "Per ED report, the patient had a brief period of confusion - she did not recall the ultrasound or bloodwork at OSH.",
    "She denies recent drug use or alcohol use.",
    "She denies feeling confused, but reports that she is forgetful at times.",
    "In the ED, initial vitals were 98.4, 70, 106/63, 16, 97%RA.",
    "Labs were notable for ALT, AST, AP, and Tbili1.6.",
    "The patient has HIV on HAART, COPD, and HCV cirrhosis complicated by ascites and hepatic encephalopathy.",
    "She was admitted with abdominal distention and pain.",
    "She had 3L of fluid removed recently and felt better, but since then her abdomen has become increasingly distended.",
    "Her diuretics were recently decreased due to worsening hyponatremia and hyperkalemia.",
    "Patient states she has been compliant with her HIV and diuretic medications but never filled out the lactulose prescription.",
    "She has had some visual hallucinations and forgetfulness.",
    "Her appetite has been poor.",
    "In the ED, initial vitals were 98.9, 88, 116/88, 18, 97% RA.",
    "CBC near baseline, INR 1.4, Na 125, Cr 0.6, AST and ALT mildly above baseline.",
    "Diagnostic paracentesis with 225 WBC, 7% PMN, total protein 0.3.",
    "UA with few bacteria, WBC, moderate leukocytes, negative nitrites, but contaminated with epithelial cells.",
    "CXR clear.",
    "RUQ ultrasound with no portal vein thrombus, moderate ascites.",
    "She was given ondansetron and morphine in the ED.",
    "On the floor, she is feeling improved but still has abdominal distention and discomfort.",
    "No black or bloody stools.",
    "Mrs. is a female with HIV, COPD, HCV cirrhosis, and hepatic encephalopathy who presented to the ED with hypotension after a paracentesis.",
    "The patient has had accelerated decompensation of her cirrhosis recently with worsening ascites.",
    "She is maintained on twice weekly paracentesis.",
    "During her regular session, she had hypotension to systolic blood pressure and felt lightheaded.",
    "Her outpatient hepatologist recommended that she go to the ED.",
    "In the ED, she was evaluated and deemed to have stable blood pressure.",
    "She was discharged home but had worsening mental status, leading to her return to the ED.",
    "Initial vitals were 98.7, 77, 96/50, 16, 98% RA.",
    "Labs notable for sodium, potassium, creatinine, ALT, AST, and total bilirubin.",
    "She received ceftriaxone, insulin, calcium gluconate, lactulose, and albumin.",
    "Upon transfer, vitals were 99.0, 93, 84/40, 16, 95% nasal cannula.",
    "On arrival to the MICU, the patient was more alert and conversant.",
    "She has no abdominal pain, nausea, vomiting, chest pain, or difficulty breathing.",
    "She has a chronic cough that has not changed.",
    "She reports taking all of her medications except lactulose, which she finds distasteful.",
    "Patient with HIV on HAART, COPD on 3L home O2, and HCV cirrhosis complicated by ascites requiring biweekly therapeutic paracenteses.",
    "She presented with worsening girth and abdominal pain.",
    "She had paracentesis recently but felt overdue for another.",
    "She reported worsening abdominal pain that radiates to her back, not associated with food.",
    "She denied any fever, chills, shortness of breath, or cough.",
    "In the ED, vitals were: 99.4, 105, 106/57, 18, 96% RA.",
    "Labs were significant for sodium, potassium, lactate, INR, ALT, and AST.",
    "Ascitic fluid showed 220 WBC.",
    "She was given morphine sulfate and a GI cocktail.",
    "A male patient with dyslipidemia and a history of prostate cancer referred to the ED for worsening gait and falls.",
    "The patient reports visual hallucinations.",
    "A patient with anxiety and dysphagia presented with worsened foreign body sensation.",
    "A patient was admitted for a femur fracture.",
    "A male with a history of factor VIII deficiency presented with neck swelling after a snowboarding accident.",
    "The patient reports loss of consciousness after the fall.",
    "CT imaging of the head and neck showed no intracranial hemorrhage, but a right platysma muscle hematoma.",
    "The patient was treated with DDAVP and admitted for further management.",
    "A patient with incidental finding of right renal mass suspicious for RCC following MRI.",
    "A male patient with history of AAA s/p repair complicated by MI presented with nasal fractures and epistaxis secondary to a fall.",
    "The patient tripped on the curb while coughing and suffered facial trauma.",
    "CT imaging showed nasal bone and septal fractures.",
    "He had persistent epistaxis, leading to the placement of bilateral RhinoRockets.",
    "In the ED, the patient experienced nausea and coughed up blood.",
    "The patient was noted to be hypotensive and bradycardic, with a brief loss of consciousness.",
    "He was transferred for further care and had no further episodes of syncope.",
    "A female patient with HIV, COPD, and HCV cirrhosis presented with worsening abdominal distention and pain.",
    "She had a history of ascites and therapeutic paracentesis.",
    "The patient was admitted for management of hepatic encephalopathy.",
    "She reported feeling confused and forgetful.",
    "Patient denied recent drug use or alcohol use.",
    "Labs were notable for ALT, AST, and total bilirubin levels.",
    "She was treated with lactulose and antibiotics in the ED.",
    "In the MICU, she was alert and conversant with no abdominal pain.",
    "A male patient with a history of factor VIII deficiency presented with bleeding after a snowboarding accident.",
    "The patient was admitted for management of hemophilia A.",
    "He was treated with desmopressin and admitted to the hematology floor.",
    "The patient had a history of significant bleeding after a circumcision and wisdom tooth extraction.",
    "A patient with renal cell carcinoma was admitted for further management following MRI findings.",
    "A patient presented with nasal fractures and epistaxis secondary to a fall and was transferred for further care."
]

def process_notes(notes):
    results = []
    for i, note in enumerate(notes):
        # Process through NER service
        ner_results = ner_service.process(note)
        
        # Process NER results through standardization service
        std_results = []
        for entity in ner_results:
            std_result = std_service.process(entity['word'])
            std_results.append({
                "original_term": entity['word'],
                "entity_group": entity['entity_group'],
                "start": entity['start'],
                "end": entity['end'],
                "score": entity['score'],
                "standardized_results": std_result
            })
        
        results.append({
            "note_id": i + 1,
            "note_text": note,
            "ner_results": ner_results,
            "std_results": std_results
        })
    
    return results

# Write results to JSON
def write_to_json(results, filename='results.json'):
    with open(filename, 'w', encoding='utf-8') as jsonfile:
        json.dump(results, jsonfile, ensure_ascii=False, indent=2)

# Main execution
if __name__ == "__main__":
    results = process_notes(medical_sentences)
    write_to_json(results)
    print("Processing complete. Results written to results.json")

