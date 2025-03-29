from transformers import pipeline

def test_ner_model():
    # Initialize the NER pipeline directly
    ner_pipe = pipeline("token-classification", 
                        model="Clinical-AI-Apollo/Medical-NER", 
                        aggregation_strategy='simple')

    # Test texts
    test_texts = [
        "Patient complains of chest pain and shortness of breath.",
        "The patient was diagnosed with hypertension and prescribed lisinopril.",
        "History of diabetes mellitus type 2 and coronary artery disease.",
        "Patient reports fever, cough, and fatigue for the past 3 days.",
        "MRI shows a 2cm mass in the left lung, suspicious for malignancy.",
    ]

    all_entity_types = set()

    for test_text in test_texts:
        print(f"\nProcessing: '{test_text}'")
        result = ner_pipe(test_text)

        print("NER Results:")
        for entity in result:
            print(f"Entity: {entity['word']}, Type: {entity['entity_group']}, Score: {entity['score']:.4f}")
            all_entity_types.add(entity['entity_group'])

    print("\nAll NER Types Detected:")
    for entity_type in sorted(all_entity_types):
        print(f"- {entity_type}")

    # Basic assertions
    assert len(all_entity_types) > 0, "No entity types were detected"

if __name__ == "__main__":
    test_ner_model()
    print("All tests passed!")