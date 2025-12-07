from coremltools.models.neural_network import NeuralNetworkBuilder, AdamParams
print("Help for set_epochs:")
try:
    help(NeuralNetworkBuilder.set_epochs)
except:
    print("No accessible help")
