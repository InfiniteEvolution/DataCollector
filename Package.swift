// swift-tools-version: 6.0
//
//  Package.swift
//  DataCollector
//
//  Created by sijo using AI on 30/11/25.
//

import PackageDescription

let package = Package(
    name: "DataCollector",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "DataCollector",
            targets: ["DataCollector"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/InfiniteEvolution/Trainer.git", branch: "M0")
    ],
    targets: [
        .target(
            name: "DataCollector",
            dependencies: [
                .product(name: "Trainer", package: "Trainer"),
            ]
        ),
        .testTarget(
            name: "DataCollectorTests",
            dependencies: ["DataCollector"]
        ),
    ]
)
