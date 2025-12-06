#!/usr/bin/env swift

import Foundation

// Create weighted dataset by duplicating rows based on probability
// High (≥0.9): 3 copies, Medium (0.7-0.9): 2 copies, Low (<0.7): 1 copy

let inputPath = "vibe_research_backed_dataset.csv"
let outputPath = "vibe_weighted_dataset.csv"

print("📊 Creating weighted dataset...")
print("   Input: \(inputPath)")
print("   Output: \(outputPath)")

guard let input = try? String(contentsOfFile: inputPath) else {
    print("❌ Error: Could not read input file")
    exit(1)
}

let lines = input.components(separatedBy: "\n")
guard let header = lines.first else {
    print("❌ Error: Empty file")
    exit(1)
}

var weightedLines: [String] = [header]
var stats = [String: Int]()

for line in lines.dropFirst() {
    guard !line.isEmpty else { continue }

    let columns = line.components(separatedBy: ",")
    guard columns.count == 9 else { continue }

    // Get probability (last column)
    guard let probability = Double(columns[8]) else { continue }

    // Determine weight
    let copies: Int
    let category: String
    if probability >= 0.9 {
        copies = 3
        category = "High"
    } else if probability >= 0.7 {
        copies = 2
        category = "Medium"
    } else {
        copies = 1
        category = "Low"
    }

    stats[category, default: 0] += 1

    // Add copies
    for _ in 0..<copies {
        weightedLines.append(line)
    }
}

// Write output
let output = weightedLines.joined(separator: "\n")
do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("✅ Weighted dataset created!")
    print("\n📈 Statistics:")
    print("   Original samples: \(lines.count - 1)")
    print("   Weighted samples: \(weightedLines.count - 1)")
    print(
        "\n   High confidence (≥0.9): \(stats["High", default: 0]) samples × 3 = \(stats["High", default: 0] * 3)"
    )
    print(
        "   Medium confidence (0.7-0.9): \(stats["Medium", default: 0]) samples × 2 = \(stats["Medium", default: 0] * 2)"
    )
    print(
        "   Low confidence (<0.7): \(stats["Low", default: 0]) samples × 1 = \(stats["Low", default: 0])"
    )
} catch {
    print("❌ Error writing file: \(error)")
    exit(1)
}
