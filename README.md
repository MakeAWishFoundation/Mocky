[![Platform](https://img.shields.io/cocoapods/p/SwiftyMocky.svg?style=flat)](http://cocoapods.org/pods/SwiftyMocky)
[![Docs](https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/master/docs/badge.svg)](https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/master/docs/index.html)
[![License](https://img.shields.io/cocoapods/l/SwiftyMocky.svg?style=flat)](http://cocoapods.org/pods/SwiftyMocky)
[![Build Status](https://img.shields.io/travis/MakeAWishFoundation/SwiftyMocky.svg?label=SwiftyMocky&logo=travis)](https://travis-ci.org/MakeAWishFoundation/SwiftyMocky)
[![Integration tests](https://img.shields.io/travis/MakeAWishFoundation/SM-Integration-Tests.svg?label=Integration%20Tests&logo=travis)](https://travis-ci.org/MakeAWishFoundation/SM-Integration-Tests)

[![Version](https://img.shields.io/cocoapods/v/SwiftyMocky.svg?style=flat)](http://cocoapods.org/pods/SwiftyMocky)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
![Mint compatible](https://img.shields.io/badge/🌱%20Mint-compatible-brightgreen.svg)
![SPM compatible](https://img.shields.io/badge/SPM-compatible-orange.svg?style=flat&logo=swift)

# ![logo][logo]

Join our community on Slack! -> [invitation link here][link-slack]

Check out [guides][link-guides-contents], or full [documentation][link-docs]

## Table of contents

1. [Overview](#overview)
1. [Current Version](#current-version)
1. [Getting started:](#getting-started)
    1. [Installing SwiftyMocky CLI](#installation)
    1. [Integrating SwiftyMocky runtime into test target](#integration)
    1. [Generate mocks](#generation)
1. [Usage:](#usage)
    1. [Marking protocols to be mocked](#mock-annotate)
    1. [Stubbing return values for mock methods - Given](#given)
    1. [Check invocations of methods, subscripts and properties - Verify](#verify)
    1. [Take action when a stubbed method is called - Perform](#perform)
1. [Documentation](#guides)
    1. [All supported Features](#features)
    1. [Examples of usage](#examples)
    1. [Roadmap](#roadmap)
    1. [Authors](#authors)
    1. [License](#license)

<a name="overview"></a>

## Overview

**SwiftyMocky** is Lightweight, strongly typed framework for Mockito-like unit testing experience. As Swift doesn't support reflections well enough to allow building mocks in runtime, library depends on [Sourcery](https://github.com/krzysztofzablocki/Sourcery), that scans your source code and **generates Mocks Swift code for you!**

The idea of **SwiftyMocky** is to automatically mock Swift protocols and protocol compositions. The main features are:

 - easy syntax, utilising full power of auto-complete, which makes writing test easier and faster
 - **we DO support generics**
 - mock implementations generation
 - a way to specify what mock will return (given)
 - possibility to specify different return values for different attributes
 - record stubbed return values sequence
 - verify, whether a method was called on mock or not
 - check method invocations with specified attributes
 - it works with real device

<a name="current-version"></a>

## **Important!!!** Version 4.x.x

Current version has several significant changes. It removes deprecated methods (which might be breaking) and moves CLI to the new [repository](https://github.com/MakeAWishFoundation/SwiftyMockyCLI).

**SwiftyPrototype** was also extracted to separate library. There are no more compilation flags, so if you were relying on **SwiftyMocky** with `-DMockyCustom`, you will have to switch to `SwiftyPrototype`.

We consider current version as stable. We are moving toward using the new [Mockfile][link-guides-mockfile] but the previous configuration format would be still supported. Library works with Swift **4.1, 4.2, 5.0, 5.1.2**  and  Sourcery 1.0.x.

While it is technically possible to integrate SwiftyMocky on Linux targets, there is no Mock generation feature there yet. You can use SwiftyMokcy runtime via SwiftPM though, as long as your are fine with generating mocks on mac machine.

## Migration from 3.2.0 and below

The migration is not required, you can keep using **SwiftyMocky** as you did before. The [Legacy setup](https://github.com/MakeAWishFoundation/SwiftyMocky/blob/master/guides/Legacy.md) is described in [guides section](https://github.com/MakeAWishFoundation/SwiftyMocky/blob/master/guides/Contents.md).

Still, we would encourage to try new **CLI** and share a feedback. We believe it will make using and setting up **SwiftyMocky** way easier. If you have an existing setup, install CLI as per this [guide](https://github.com/MakeAWishFoundation/SwiftyMocky/blob/master/guides/Installation.md) and try:

```bash
> swiftymocky migrate
```

<a name="getting-started"></a>

## Getting started

To start working with **SwiftyMocky** you need to:

1. Install **CLI**
2. Integrate **SwiftyMocky** runtime library
3. Generate Mocks and add to your test target

<a name="installation"></a>

### 1. Installing SwiftyMocky CLI:

**[Mint 🌱](https://github.com/yonaskolb/Mint)**:

```bash
> brew install mint
> mint install MakeAWishFoundation/SwiftyMocky-CLI
```

**[Marathon 🏃](https://github.com/JohnSundell/Marathon)**:

```bash
> marathon install MakeAWishFoundation/SwiftyMocky-CLI
```

**Make**:

Clone from https://github.com/MakeAWishFoundation/SwiftyMockyCLI and run `make` in the root directory.

<a name="integration"></a>

### 2. Integrating SwiftyMocky runtime into test target:

**[CocoaPods](http://cocoapods.org)**:

SwiftyMocky is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod "SwiftyMocky"
```

**[Carthage](https://github.com/Carthage/Carthage)**:

To install, add following to you Cartfile:

```ruby
github "MakeAWishFoundation/SwiftyMocky"
```

Then execute `carthage update`

For [Carthage](https://github.com/Carthage/Carthage), few additional steps are required ⚠️. For detailed install instructions, see full [documentation][link-docs-installation-carthage] or consult [Carthage documentation][carthage-adding-framework].

**[Swift Package Manager](https://swift.org/package-manager/)**:

Add **SwiftyMocky** to you **Package.swift** dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/MakeAWishFoundation/SwiftyMocky", from: "4.0.4"),
]
```

> **Note:** Examples of **SwiftyMocky** integration as a tool for Unit tests, as well as a Prototyping framework, are here: [https://github.com/MakeAWishFoundation/SM-Integration-Tests](https://github.com/MakeAWishFoundation/SM-Integration-Tests)

<a name="generation"></a>

### 3. Generate mocks

[Annotate your protocols](#mock-annotate) that are going to be mocked, making them adopt `AutoMockable` protocol, or adding annotation comment above their definition in the source code.

Mocks are generated from your project root directory, based on configuration inside [Mockfile][link-guides-mockfile].

```bash
> swiftymocky setup     # if you don't have a Mockfile yet
> swiftymocky doctor    # validate your setup
> swiftymocky generate  # generate mocks
```

More informations about [CLI][link-guides-cli] and [mock generation][link-guides-cli-generate]

If you don't want to migrate to our **CLI** and prefer to use "raw" Sourcery, please refer [to this section in documentation][link-guides-cli-legacy].

<a name="usage"></a>

# Usage

<a name="mock-annotate"></a>

## 1. Marking protocols to be mocked

Create 'dummy' protocol somewhere in your project, like: `protocol AutoMockable { }`

Adopt it by every protocol you want to actually mock.

```swift
protocol ToBeMocked: AutoMockable {
  // ...
}
```

Alternatively, mark protocols that are meant to be mocked with sourcery annotation as following:

```swift
//sourcery: AutoMockable
protocol ToBeMocked {
  // ...
}
```

Or use it to protocol compositions:

```swift
typealias ToBeMocked = OneProtocol & TwoProtocols & AutoMockable
```

Every protocol in source directories, having this annotation, will be added to `Mock.generated.swift`

<a name="given"></a>

## 2. Stubbing return values for mock methods - **Given**

All mocks has **given** method (accessible both as instance method or global function), with easy to use syntax, allowing to specify what should be return values for given methods (based on specified attributes).

![Generating mock][example-given]

All protocol methods are nicely put into **Given**, with matching signature. That allows to use auto-complete (just type `.`) to see all mocked protocol methods, and specify return value for them.

All method attributes are wrapped as **Parameter** enum, allowing to choose between `any` and `value`, giving great flexibility to mock behaviour. Please consider following:

```swift
Given(mock, .surname(for name: .value("Johnny"), willReturn: "Bravo"))
Given(mock, .surname(for name: .any, willReturn: "Kowalsky"))

print(mock.surname(for: "Johny"))   // Bravo
print(mock.surname(for: "Mathew"))  // Kowalsky
print(mock.surname(for: "Joanna"))  // Kowalsky
```

In verions 3.0 we introduced sequences and policies for better control of mock behvaiour.

```swift
Given(mock, .surname(for name: .any, willReturn: "Bravo", "Kowalsky", "Nguyen"))

print(mock.surname(for: "Johny"))   // Bravo
print(mock.surname(for: "Johny"))   // Kowalsky
print(mock.surname(for: "Johny"))   // Nguyen
print(mock.surname(for: "Johny"))   // and again Bravo
// ...
```

For more details please see full [documentation][link-docs].

<a name="verify"></a>

## 3. Check invocations of methods, subscripts and properties - **Verify**

All mocks has **verify** method (accessible both as instance method or global function), with easy to use syntax, allowing to verify, whether a method was called on mock, and how many times. It also provides convenient way to specify, whether method attributes matters (and which ones).

![Generating mock][example-verify]

All protocol methods are nicely put into **Verify**, with matching signature. That allows to use auto-complete (just type `.`) to see all mocked protocol methods, and specify which one we want to verify.

All method attributes are wrapped as **Parameter** enum, allowing to choose between `any`, `value` and `matching`, giving great flexibility to tests. Please consider following:

```swift
// inject mock to sut. Every time sut saves user data, it should trigger storage storeUser method
sut.usersStorage = mockStorage
sut.saveUser(name: "Johny", surname: "Bravo")
sut.saveUser(name: "Johny", surname: "Cage")
sut.saveUser(name: "Jon", surname: "Snow")

// check if Jon Snow was stored at least one time
Verify(mockStorage, .storeUser(name: .value("Jon"), surname: .value("Snow")))
// storeUser method should be triggered 3 times in total, regardless of attributes values
Verify(mockStorage, 3, .storeUser(name: .any, surname: .any))
// storeUser method should be triggered 2 times with name Johny
Verify(mockStorage, 2, .storeUser(name: .value("Johny"), surname: .any))
// storeUser method should be triggered at least 2 times with name longer than 3
Verify(mockStorage, .moreOrEqual(to: 2), .storeUser(name: .matching({ $0.count > 3 }), surname: .any))
```

For **Verify**, you can use **Count** to specify how many times you expect something to be triggered. **Count** can be defined as explicit value, like `1`,`2`,... or in more descriptive and flexible way, like `.never`, `more(than: 1)`, etc.

From SwiftyMocky 3.0, it is possible to use `Given` and perform `Verify` on properties as well, with respect to whether it is get or set:

```swift
mock.name = "Danny"
mock.name = "Joanna"

print(mock.name)

// Verify getter:
Verify(mock, 1, .name)
// Verify setter:
Verify(mock, 2, .name(set: .any))
Verify(mock, 1, .name(set: .value("Danny")))
Verify(mock, .never, .name(set: .value("Bishop")))
```

<a name="perform"></a>

### 4. Take action when a stubbed method is called - **Perform**

All mocks has **perform** method (accessible both as instance method or global function), with easy to use syntax, allowing to specify closure, that will be executed upon stubbed method being called.

It uses same parameter wrapping features as given, so you can specify different **Perform** cases for different attributes set.

It's very handy when working with completion block based approach.

Example:

```swift
// Perform allows to execute given closure, with all the method parameters, as soon as it is being called
Perform(mock, .methodThatTakesCompletionBlock(completion: .any, perform: { completion in
    completion(true,nil)
}))
```

<a name="guides"></a>

# Documentation

Full documentation is available [here][link-docs], as well as through *docs* directory.

Guides - [Table of contents][link-guides-contents]

Changelog is available [here][link-changelog]

<a name="features"></a>

## All supported features

For list all supported features, check documentation [here][link-docs-features] or [guides][link-guides-features]

<a name="examples"></a>

## Examples of usage

For more examples, check out our example project, or examples section in [guides][link-guides-examples].

To run the example project, clone the repo, and run `pod install` from the Example directory first.

To trigger mocks generation, run `rake mock` or `swiftymocky generate` from root directory (if you installed CLI).

<a name="roadmap"></a>

## Roadmap

- [x] stubbing protocols in elegant way
- [x] template for generating mocks
- [x] example project
- [x] stubbing protocols with variables
- [x] method signature generation without name conflicts
- [ ] cover 95% of framework codebase with unit tests
- [x] cover 95% of framework codebase with documentation
- [ ] add unit tests for template
- [x] support for tvOS, Linux and MacOS
- [x] Carthage support
- [x] Subscripts support
- [x] Stub return values as sequences
- [x] Simple tool simplifying configuration process

<a name="authors"></a>

## Authors

- Przemysław Wośko, wosko.przemyslaw@gmail.com
- Andrzej Michnia, amichnia@gmail.com

<a name="license"></a>

## License

SwiftyMocky is available under the MIT license. See the [LICENSE][link-license] file for more info.

<!-- Links -->

[link-slack]: https://join.slack.com/t/swiftymocky/shared_invite/enQtMjkwNDE1NjY5MjA3LTU2YjA4YTI3NDE5MzNkZTU4MzlmMzkwYmUzNzRiNWRlN2U5NmUyMDNkN2U0NGE2ZDkxYTU4NGViYzIxYjc5ZmE
[link-license]: ./LICENSE
[link-guides-installation]: ./guides/Setup%20in%20project.md
[link-guides-setup]: ./guides/Installation.md
[link-guides-contents]: ./guides/Contents.md
[link-guides-features]: ./guides/Supported%20features.md
[link-guides-examples]: ./guides/Examples.md
[link-changelog]: ./guides/CHANGELOG.md

[link-guides-cli]: ./guides/Command%20Line%20Interface.md
[link-guides-cli-migration]: ./guides/Command%20Line%20Interface.md#migration
[link-guides-cli-legacy]: ./guides/Legacy.md
[link-guides-cli-generate]: ./guides/Command%20Line%20Interface.md#generate
[link-guides-mockfile]: ./guides/Mockfile.md

[carthage-adding-framework]: https://github.com/Carthage/Carthage#adding-frameworks-to-unit-tests-or-a-framework

<!-- Links based on tag -->

[link-docs]: https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/4.0.4/docs/index.html
[link-docs-features]: https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/4.0.4/docs/supported-features.html
[link-docs-installation]: https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/4.0.4/docs/installation.html
[link-docs-installation-carthage]: https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/4.0.4/docs/installation.html#installation-carthage
[link-docs-setup]: https://cdn.rawgit.com/MakeAWishFoundation/SwiftyMocky/4.0.4/docs/setup-in-project.html

<!-- Assets -->

[logo]: https://raw.githubusercontent.com/MakeAWishFoundation/SwiftyMocky/1.0.0/icon.png
[example-watcher]: https://raw.githubusercontent.com/MakeAWishFoundation/SwiftyMocky/1.0.0/guides/assets/example-watcher.gif "Example - generation"
[example-given]: https://raw.githubusercontent.com/MakeAWishFoundation/SwiftyMocky/1.0.0/guides/assets/example-given.gif "Example - given"
[example-verify]: https://raw.githubusercontent.com/MakeAWishFoundation/SwiftyMocky/1.0.0/guides/assets/example-verify.gif "Example - verify"
