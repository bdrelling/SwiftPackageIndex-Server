// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import XCTVapor


class RecentViewsTests: AppTestCase {
    
    func test_recentPackages() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           name: "1",
                           owner: "foo",
                           summary: "pkg 1").create(on: app.db).wait()
            try Version(package: pkg, packageName: "1").save(on: app.db).wait()
        }
        do {  // 2nd package should not be selected, because it has no package name
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           name: "2",
                           owner: "foo",
                           summary: "pkg 2").create(on: app.db).wait()
            try Version(package: pkg).save(on: app.db).wait()
        }
        do {  // 3rd package is eligible
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           name: "3",
                           owner: "foo",
                           summary: "pkg 3").create(on: app.db).wait()
            try Version(package: pkg, packageName: "3").save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()
        
        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()
        
        // validate
        XCTAssertEqual(res.map(\.packageName), ["3", "1"])
        XCTAssertEqual(res.map(\.packageSummary), ["pkg 3", "pkg 1"])
    }
    
    func test_recentReleases() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           defaultBranch: "default",
                           name: "1",
                           owner: "foo",
                           summary: "pkg 1").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 0),
                        packageName: "1",
                        reference: .tag(.init(1, 2, 3)),
                        url: "1/release/1.2.3").save(on: app.db).wait()
        }
        do {  // 2nd package is ineligible, because it has a branch reference
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           defaultBranch: "default",
                           name: "2",
                           owner: "foo",
                           summary: "pkg 2").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 0),
                        packageName: "2",
                        reference: .branch("default"),
                        url: "2/branch/default").save(on: app.db).wait()
        }
        do {  // 3rd package is ineligible, because it has no package name
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           defaultBranch: "default",
                           name: "3",
                           owner: "foo",
                           summary: "pkg 3").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 0),
                        reference: .branch("default"),
                        url: "2/branch/default").save(on: app.db).wait()
        }
        do {  // 4th package is ineligible, because it has no reference
            let pkg = Package(id: UUID(), url: "4")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           defaultBranch: "default",
                           name: "4",
                           owner: "foo",
                           summary: "pkg 4").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 0),
                        packageName: "4").save(on: app.db).wait()
        }
        do {  // 5th package is eligible - should come before 1st because of more recent commit date
            let pkg = Package(id: UUID(), url: "5")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           defaultBranch: "default",
                           name: "5",
                           owner: "foo",
                           summary: "pkg 5").create(on: app.db).wait()
            try Version(package: pkg,
                        commitDate: Date(timeIntervalSince1970: 1),
                        packageName: "5",
                        reference: .tag(.init(2, 0, 0)),
                        url: "5/release/2.0.0").save(on: app.db).wait()
        }
        
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()
        
        // MUT
        let res = try RecentRelease.fetch(on: app.db).wait()
        
        // validate
        XCTAssertEqual(res.map(\.packageName), ["5", "1"])
        XCTAssertEqual(res.map(\.version), ["2.0.0", "1.2.3"])
        XCTAssertEqual(res.map(\.packageSummary), ["pkg 5", "pkg 1"])
        XCTAssertEqual(res.map(\.releaseUrl), ["5/release/2.0.0", "1/release/1.2.3"])
    }
    
    func test_recentReleases_Filter() throws {
        XCTAssertTrue(RecentRelease.Filter.minor == .init("minor"))
        XCTAssertTrue(RecentRelease.Filter.major == .init("major"))
        XCTAssertTrue(RecentRelease.Filter.patch == .init("patch"))
        XCTAssertTrue(RecentRelease.Filter.all == [.init("minor"), .init("major"), .init("patch"), .init("pre")])
        XCTAssertTrue(RecentRelease.Filter.all == .init("nonsensical defaults to all"))
    }
    
    func test_recentReleases_filter() throws {
        // List only major releases
        // setup
        let releases: [RecentRelease] = (1...12).map {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pre = $0 <= 10 ? "" : "-b1"
            return RecentRelease(packageId: UUID(),
                                 repositoryOwner: "",
                                 repositoryName: "",
                                 packageName: "",
                                 packageSummary: nil,
                                 version: "\(major).\(minor).\(patch)\(pre)",
                                 releasedAt: Date(),
                                 releaseUrl: "release url")
        }
        
        // MUT
        let all = RecentRelease.filterReleases(releases, by: .all)
        let majorOnly = RecentRelease.filterReleases(releases, by: .major)
        let minorOnly = RecentRelease.filterReleases(releases, by: .minor)
        let majorMinor = RecentRelease.filterReleases(releases, by: [.major, .minor])
        let pre = RecentRelease.filterReleases(releases, by: [.pre])
        
        // validate
        XCTAssertEqual(
            all.map(\.version),
            ["0.1.1", "0.2.0", "1.0.1", "1.1.0", "1.2.1", "2.0.0", "2.1.1", "2.2.0", "3.0.1", "3.1.0",
             "3.2.1-b1", "4.0.0-b1"])
        XCTAssertEqual(
            majorOnly.map(\.version), ["2.0.0"])
        XCTAssertEqual(
            minorOnly.map(\.version), ["0.2.0", "1.1.0", "2.2.0", "3.1.0"])
        XCTAssertEqual(
            majorMinor.map(\.version), ["0.2.0", "1.1.0", "2.0.0", "2.2.0", "3.1.0"])
        XCTAssertEqual(
            pre.map(\.version), ["3.2.1-b1", "4.0.0-b1"])
    }
    
    func test_recentPackages_dedupe_issue() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/315
        // setup
        // Package with two eligible versions that differ in package name
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "bar",
                       owner: "foo",
                       summary: "pkg summary").create(on: app.db).wait()
        try Version(package: pkg,
                    commitDate: Date(timeIntervalSince1970: 0),
                    packageName: "pkg-bar").save(on: app.db).wait()
        try Version(package: pkg,
                    commitDate: Date(timeIntervalSince1970: 1),
                    packageName: "pkg-bar-updated").save(on: app.db).wait()
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()
        
        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()
        
        // validate
        XCTAssertEqual(res.map(\.packageName), ["pkg-bar-updated"])
    }
    
    func test_recentReleases_dedupe_issue() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/315
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "bar",
                       owner: "foo",
                       summary: "pkg summary").create(on: app.db).wait()
        try Version(package: pkg,
                    commitDate: Date(timeIntervalSince1970: 0),
                    packageName: "pkg-bar",
                    reference: .tag(.init(1, 0, 0))).save(on: app.db).wait()
        try Version(package: pkg,
                    commitDate: Date(timeIntervalSince1970: 1),
                    packageName: "pkg-bar-updated",
                    reference: .tag(.init(1, 0, 1))).save(on: app.db).wait()
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()
        
        // MUT
        let res = try RecentRelease.fetch(on: app.db).wait()
        
        // validate
        XCTAssertEqual(res.map(\.packageName), ["pkg-bar-updated"])
    }
    
}
