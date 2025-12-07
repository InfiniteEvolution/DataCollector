import coremltools as ct

try:
    model = ct.models.MLModel("VibeClassifier.mlmodel")
    spec = model.get_spec()
    
    print("--- Training Inputs ---")
    if spec.HasField("isUpdatable") and spec.isUpdatable:
        print("Model is Updatable.")
        print(f"Update Interface inputs: {len(spec.description.trainingInput)}")
        for i in spec.description.trainingInput:
            print(f"Name: {i.name}, Type: {i.type.WhichOneof('Type')}")
    else:
        print("Model is NOT marked as Updatable.")

    # Check loss layer configuration
    print("\n--- Network Loss Layers ---")
    nn = spec.neuralNetworkClassifier
    for layer in nn.layers:
        if layer.HasField("categoricalCrossEntropyLossLayer"):
            print(f"Layer: {layer.name}")
            loss = layer.categoricalCrossEntropyLossLayer
            print(f"  Input: {loss.input}")
            print(f"  Target: {loss.target}")

except Exception as e:
    print(e)
