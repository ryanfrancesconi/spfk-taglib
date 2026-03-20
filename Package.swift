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
				.headerSearchPath("."),
				.headerSearchPath("toolkit"),
				.headerSearchPath("ape"),
				.headerSearchPath("asf"),
				.headerSearchPath("dsdiff"),
				.headerSearchPath("dsf"),
				.headerSearchPath("flac"),
				.headerSearchPath("it"),
				.headerSearchPath("matroska"),
				.headerSearchPath("matroska/ebml"),
				.headerSearchPath("mod"),
				.headerSearchPath("mp4"),
				.headerSearchPath("mpc"),
				.headerSearchPath("mpeg"),
				.headerSearchPath("mpeg/id3v1"),
				.headerSearchPath("mpeg/id3v2"),
				.headerSearchPath("mpeg/id3v2/frames"),
				.headerSearchPath("ogg"),
				.headerSearchPath("ogg/flac"),
				.headerSearchPath("ogg/opus"),
				.headerSearchPath("ogg/speex"),
				.headerSearchPath("ogg/vorbis"),
				.headerSearchPath("riff"),
				.headerSearchPath("riff/aiff"),
				.headerSearchPath("riff/wav"),
				.headerSearchPath("s3m"),
				.headerSearchPath("shorten"),
				.headerSearchPath("trueaudio"),
				.headerSearchPath("wavpack"),
				.headerSearchPath("xm"),
				.headerSearchPath("utfcpp/source"),
			]),
		.target(
			name: "TagLibTestHelper",
			dependencies: ["taglib"],
			publicHeadersPath: "include",
			cxxSettings: [
				.headerSearchPath("include"),
			]),
		.testTarget(
			name: "SPFKTagLibTests",
			dependencies: [
				"TagLibTestHelper",
			],
			resources: [
				.copy("Resources"),
			]),
	],
	cxxLanguageStandard: .cxx17
)
