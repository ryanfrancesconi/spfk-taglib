// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SPFKTagLib",
	products: [
		.library(
			name: "taglib",
			targets: [
				"taglib",
			]),
	],
	targets: [
		.target(
			name: "taglib",
			cxxSettings: [
				.headerSearchPath("include/taglib"),
				.headerSearchPath("utfcpp/source"),
				.headerSearchPath("."),
				.headerSearchPath("mod"),
				.headerSearchPath("riff"),
				.headerSearchPath("toolkit"),
			]),
		.testTarget(
			name: "SPFKTagLibTests",
			dependencies: [
				"taglib",
			]),
	],
	cxxLanguageStandard: .cxx17
)
