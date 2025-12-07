import coremltools as ct

try:
    model = ct.models.MLModel("VibeClassifier.mlmodel")
    spec = model.get_spec()
    nn = spec.neuralNetworkClassifier
    
    print("--- Outputs ---")
    for o in spec.description.output:
        print(f"Name: {o.name}, Type: {o.type.WhichOneof('Type')}")
        if o.type.HasField('dictionaryType'):
            print(f"  KeyType: {o.type.dictionaryType.WhichOneof('KeyType')}")

    print("\n--- Class Labels ---")
    if nn.HasField('int64ClassLabels'):
        print(f"Int64 Labels: {nn.int64ClassLabels.vector}")
    elif nn.HasField('stringClassLabels'):
        print(f"String Labels: {nn.stringClassLabels.vector}")
    else:
        print("No Class Labels found in NeuralNetworkClassifier!")

    print(f"\n--- Layers ({len(nn.layers)}) ---")
    for layer in nn.layers:
        type_name = layer.WhichOneof('layer')
        print(f"Layer: {layer.name}, Type: {type_name}")
        if type_name == "categoricalCrossEntropyLossLayer":
            loss = layer.categoricalCrossEntropyLossLayer
            print(f"  [LOSS] Input: {loss.input}")
            print(f"  [LOSS] Target: '{loss.target}'")

except Exception as e:
    print(e)
