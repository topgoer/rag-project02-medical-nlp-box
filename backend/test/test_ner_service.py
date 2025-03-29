from ner_service import NERService

def test_ner_service():
    # Initialize the NER service
    ner_service = NERService()

    # Test text
    test_text = "The patient was diagnosed with hypertension and prescribed lisinopril."
    test_text = "Patient complains of chest pain and shortness of breath."

    # Process the text
    result = ner_service.process(test_text)

    # Print the results
    print("NER Results:")
    for entity in result:
        print(f"Entity: {entity['word']}, Type: {entity['entity_group']}, Score: {entity['score']:.4f}")

    # Basic assertions
    assert len(result) > 0, "No entities were detected"
    assert all(isinstance(entity['score'], float) for entity in result), "Scores are not converted to float"

if __name__ == "__main__":
    test_ner_service()
    print("All tests passed!")