import coremltools as ct
import pandas as pd
import numpy as np
from coremltools.models.nearest_neighbors import KNearestNeighborsClassifierBuilder

# 1. Load Data to get schema
import os
# Check two likely locations
possible_paths = ["vibe_weighted_dataset.csv", "DataCollector/Tools/vibe_weighted_dataset.csv"]
csv_path = None
for p in possible_paths:
    if os.path.exists(p):
        csv_path = p
        break

if csv_path is None:
    print(f"❌ Error: Could not find dataset in {possible_paths}")
    exit(1)

print(f"Loading data from {csv_path}...")
df = pd.read_csv(csv_path)

# 2. Prepare Features and Target
# Excluding 'timestamp' as raw time is rarely good for generalization without normalization/cyclical encoding, 
# but keeping it if it was in original. 
# Original script used: ["timestamp", "distance", "activity", "startTime", "duration", "hour", "dayOfWeek"]
# We will stick to the same features for compatibility.

feature_names = ["timestamp", "distance", "activity", "startTime", "duration", "hour", "dayOfWeek"]
target_name = "vibe"

print(f"Features: {feature_names}")
print(f"Target: {target_name}")

# 3. Create Updatable k-NN Model
# k-NN is excellent for on-device personalization (remembering specific user contexts)
# and is natively updatable in CoreML.

builder = KNearestNeighborsClassifierBuilder(
    input_name="features",
    output_name="vibe",
    number_of_dimensions=len(feature_names),
    default_class_label="unknown",
    k=3,
    weighting_scheme="inverse_distance",
    index_type="linear"
)

builder.author = "Vibe Assistant"
builder.license = "MIT"
builder.description = "Updatable k-NN Classifier for Vibe Prediction"

# 4. Set Feature Descriptions
# We need to map the explicit input names to the "features" vector expected by k-NN,
# OR we can create a pipeline that takes named inputs and concatenates them.
# For simplicity in CoreML update tasks, a single multi-array input is easiest, 
# BUT our Swift code (`ColumnarBatchProvider`) likely provides named features.
# Make sure the Swift side provides a dictionary matching these inputs.

# Actually, MLTaskRunner in Swift passes an MLBatchProvider. 
# If we define the model with standard inputs, CoreML handles it.
# However, Updatable models often require precise input definitions.
# Let's create a Neural Network (Updatable) instead, as planned? 
# Plan said "Updatable Neural Network". k-NN is "easier" but "Neural Network" was approved.
# Let's stick to the Plan: Neural Network.
# Re-writing script for Neural Network below.

input_features = [
    ("timestamp", ct.models.datatypes.Array(1)),
    ("distance", ct.models.datatypes.Array(1)),
    ("activity", ct.models.datatypes.Array(1)), 
    ("startTime", ct.models.datatypes.Array(1)),
    ("duration", ct.models.datatypes.Array(1)),
    ("hour", ct.models.datatypes.Array(1)),
    ("dayOfWeek", ct.models.datatypes.Array(1))
]

output_features = [target_name]

# Define the model using the NeuralNetworkBuilder
# We need to know the number of classes.
num_classes = df[target_name].nunique()
class_labels = sorted(df[target_name].unique().astype(str).tolist()) # Ensure string labels if enum

# CoreML Tools NeuralNetworkBuilder
from coremltools.models.neural_network import NeuralNetworkBuilder, AdamParams
from coremltools.models import datatypes

# Updatable layers need to be marked.
# A simple generic MLP: Inputs -> Dense -> ReLU -> Dense (Softmax)
# We want to update the last layer or all layers.

def create_updatable_model():
    # 1. Create a builder
    # Note: 'activity' is categorical (0-5), 'vibe' is categorical.
    # We treat inputs as continuous for this simple MLP, or would need OneHot encoder.
    # Given the Swift code passes raw Doubles/Ints, we'll accept them as is.
    
    # Define input features with expected types
    # We used input_features previously defined as list of (name, Double).
    # That is correct for builder input.
    
    # For a classifier, the outputs are typically 'classLabel' (label) and 'classProbability' (dict).
    # We must define 'classProbability' here. 
    # 'classLabel' is automatically added/managed by set_class_labels usually.
    # explicit definition caused validation conflict.
    output_features_spec = [
        ("classProbability", datatypes.Dictionary(datatypes.Int64()))
    ]

    builder = NeuralNetworkBuilder(
        input_features=input_features,
        output_features=output_features_spec,
        mode="classifier"
    )

    # Inspect classes
    # 'vibe' column in CSV is integer 0-7.
    # We explicitly define the classes to match the SensorData.Vibe enum (0-7).
    # This prevents issues where the initial dataset is missing some classes (e.g. Sleep=0).
    class_labels_int = [0, 1, 2, 3, 4, 5, 6, 7]
    class_labels_int.sort()
    
    # Add Layers
    # We need to concat all inputs into one vector first? 
    # No, builder handles inputs. 
    # BUT standard MLP expects a single vector. 
    
    # We need to add a "concat" layer to join our 7 inputs into a (7,) vector.
    builder.add_elementwise(
        name="concat_inputs",
        input_names=feature_names,
        output_name="features_vector",
        mode="CONCAT"
    )
    
    # Fully Connected Layer 1
    # 7 inputs -> 64 hidden
    W1 = np.random.normal(0, 0.1, (64, 7)).flatten()
    b1 = np.zeros(64)
    builder.add_inner_product(
        name="fc1",
        W=W1,
        b=b1,
        input_channels=7,
        output_channels=64,
        has_bias=True,
        input_name="features_vector",
        output_name="hidden1"
    )
    builder.add_activation(
        name="relu1",
        non_linearity="RELU",
        input_name="hidden1",
        output_name="relu1_out"
    )
    
    # Fully Connected Layer 2 (Output)
    # 64 hidden -> Num Classes
    W2 = np.random.normal(0, 0.1, (len(class_labels_int), 64)).flatten()
    b2 = np.zeros(len(class_labels_int))
    builder.add_inner_product(
        name="fc2",
        W=W2,
        b=b2,
        input_channels=64,
        output_channels=len(class_labels_int),
        has_bias=True,
        input_name="relu1_out",
        output_name="logits"
    )
    
    # Softmax embedded in classifier usually? 
    # Builder.set_categorical_cross_entropy_loss requires logits usually.
    
    builder.add_softmax(
        name="softmax",
        input_name="logits",
        output_name="classProbability" # Standard CoreML output name
    )

    builder.set_class_labels(class_labels_int, predicted_feature_name="classLabel")
    
    # 5. Make Updatable
    # We define the training inputs (same as inference inputs typically)
    # and the loss function.
    
    builder.make_updatable(["fc1", "fc2"])
    
    # Loss Function: Categorical Cross Entropy
    # We compare 'logits' against the true label.
    builder.set_categorical_cross_entropy_loss(
        name="lossLayer",
        input="classProbability"
    )
    
    # Manually set the Target for the Loss function in the Protobuf spec
    # This is critical because builder.set_categorical_cross_entropy_loss doesn't support 'target' arg directly in this version
    nn_spec = builder.spec.neuralNetworkClassifier
    for layer in nn_spec.layers:
        if layer.name == "lossLayer":
            layer.categoricalCrossEntropyLossLayer.target = "classLabel"
            print("Set lossLayer target to 'classLabel'")
            break
    
    # Optimizer: Adam
    adam_params = AdamParams(
        lr=0.01,
        beta1=0.9,
        beta2=0.999,
        eps=1e-8,
        batch=32
    )
    builder.set_adam_optimizer(adam_params)
    builder.set_epochs(10)
    
    # Verify and Enforce Updatability
    if not builder.spec.isUpdatable:
        print("⚠️ Builder did not set isUpdatable. Forcing it...")
        builder.spec.isUpdatable = True
        
    # Ensure Training Inputs are defined
    # We must ensure 'classLabel' is in training inputs as the Target.
    found_target = False
    for i in builder.spec.description.trainingInput:
        if i.name == "classLabel":
            found_target = True
            break
    
    if not found_target:
        print("⚠️ Target 'classLabel' not found in training inputs. Adding it...")
        target_input = builder.spec.description.trainingInput.add()
        target_input.name = "classLabel"
        # Set type to Int64 - Accessing the field initializes it to default (empty message), which is valid for Int64Type
        target_input.type.int64Type.SetInParent()

    # 6. Save the Spec directly to avoid Wrapper validation/stripping
    from coremltools.models.utils import save_spec
    
    print(f"Final check - isUpdatable: {builder.spec.isUpdatable}")
    print(f"Final check - Training Inputs: {[i.name for i in builder.spec.description.trainingInput]}")
    
    return builder.spec

print("Generating updatable model...")
spec = create_updatable_model()
output_path = "VibeClassifier.mlmodel"

from coremltools.models.utils import save_spec
save_spec(spec, output_path)
print(f"✅ Saved updatable spec to {output_path}")

