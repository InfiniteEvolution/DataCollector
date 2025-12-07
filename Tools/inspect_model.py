import coremltools as ct

try:
    model = ct.models.MLModel("VibeClassifier.mlmodel")
    print("--- Inputs ---")
    for i in model.input_description:
        print(f"Name: {i}, Type: {model.input_description[i]}")

    print("\n--- Outputs ---")
    for o in model.output_description:
        print(f"Name: {o}, Type: {model.output_description[o]}")
        
    print("\n--- Spec Outputs ---")
    for o in model.get_spec().description.output:
        print(f"Name: {o.name}, Type: {o.type.WhichOneof('Type')}")
        
except Exception as e:
    print(e)
