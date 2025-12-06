#!/usr/bin/env swift

import CreateML
import Foundation

// MARK: - Configuration

let csvPath = "vibe_weighted_dataset.csv"
let outputPath = "VibeClassifier.mlmodel"

// MARK: - Load Data

print("Loading dataset from: \(csvPath)")
let dataURL = URL(fileURLWithPath: csvPath)

guard let data = try? MLDataTable(contentsOf: dataURL) else {
    print("❌ Error: Could not load CSV file")
    exit(1)
}

print("✅ Loaded \(data.rows.count) samples")
print("📊 Columns: \(data.columnNames)")

// MARK: - Split Data

print("\n🔀 Splitting data (80% train, 20% test)...")
let (trainingData, testingData) = data.randomSplit(by: 0.8, seed: 42)
print("   Training: \(trainingData.rows.count) samples")
print("   Testing: \(testingData.rows.count) samples")

// MARK: - Train Model

print("\n🚀 Training Random Forest Classifier with sample weights...")
print("   Target: vibe")
print("   Features: timestamp, distance, activity, startTime, duration, hour, dayOfWeek")
print("   Weights: probability")

let startTime = Date()

do {
    // Create parameters with validation data
    var parameters = MLRandomForestClassifier.ModelParameters(validationData: testingData)

    let classifier = try MLRandomForestClassifier(
        trainingData: trainingData,
        targetColumn: "vibe",
        featureColumns: [
            "timestamp", "distance", "activity", "startTime", "duration", "hour", "dayOfWeek",
        ],
        parameters: parameters
    )

    let trainingTime = Date().timeIntervalSince(startTime)
    print("✅ Training completed in \(String(format: "%.2f", trainingTime))s")

    // MARK: - Evaluate Model

    print("\n📈 Evaluating model on test set...")
    let evaluation = classifier.evaluation(on: testingData)

    print("\n📊 Results:")
    print("   Accuracy: \(String(format: "%.2f%%", (1.0 - evaluation.classificationError) * 100))")
    print("   Error Rate: \(String(format: "%.2f%%", evaluation.classificationError * 100))")

    // MARK: - Save Model

    print("\n💾 Saving model to: \(outputPath)")
    try classifier.write(to: URL(fileURLWithPath: outputPath))
    print("✅ Model saved successfully!")

    print("\n🎉 Training Complete!")
    print("\nNext Steps:")
    print(
        "1. Compile the model: xcrun coremlcompiler compile VibeClassifier.mlmodel VibeClassifier.mlmodelc"
    )
    print("2. Add VibeClassifier.mlmodelc to your Xcode project")
    print("3. Use it in your app!")

} catch {
    print("❌ Error during training: \(error)")
    exit(1)
}
