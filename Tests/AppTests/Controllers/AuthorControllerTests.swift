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

import Vapor
import XCTest

class AuthorControllerTests: AppTestCase {

    func test_query() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let pid = p.id
        try Repository(package: p, owner: "owner").save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        let pkg = try AuthorController.query(on: app.db, owner: "owner").wait()

        // validate
        XCTAssertEqual(pkg.map(\.model.id), [pid])
    }

    func test_query_no_version() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, owner: "owner").save(on: app.db).wait()

        // MUT
        XCTAssertThrowsError(
            try AuthorController.query(on: app.db, owner: "owner").wait()
        ) {
            // validate
            let error = $0 as? Abort
            XCTAssertEqual(error?.status, .notFound)
        }
    }

    func test_query_sort_by_score() throws {
        // setup
        try (0..<3).shuffled().forEach { index in
            let score = index > 0 ? index : nil
            let p = Package(url: "\(index)".url, score: score)
            try p.save(on: app.db).wait()
            try Repository(package: p, owner: "owner").save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }

        // MUT
        let pkg = try AuthorController.query(on: app.db, owner: "owner").wait()

        // validate
        XCTAssertEqual(pkg.map(\.model.url), ["2", "1", "0"])
    }

    func test_show_owner() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, owner: "owner").save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_show_owner_empty() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, owner: "owner").save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/fake-owner", afterResponse: { response in
            XCTAssertEqual(response.status, .notFound)
        })
    }

    func test_query_package_name() throws {
        // Ensure version.packageName is populated by query
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, owner: "owner").save(on: app.db).wait()
        try Version(package: p,
                    latest: .defaultBranch,
                    packageName: "package name").save(on: app.db).wait()

        // MUT
        let packages = try AuthorController.query(on: app.db, owner: "owner")
            .wait()

        // validate
        XCTAssertEqual(packages.map { $0.version?.packageName }, ["package name"])
    }

}
