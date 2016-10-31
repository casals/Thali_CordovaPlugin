//
//  Thali CordovaPlugin
//  AdvertiserTests.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import MultipeerConnectivity
@testable import ThaliCore
import XCTest

class AdvertiserTests: XCTestCase {

    // MARK: - State
    var randomlyGeneratedServiceType: String!
    var randomlyGeneratedPeer: Peer!
    let startAdvertisingErrorTimeout: NSTimeInterval = 5.0

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        randomlyGeneratedServiceType = String.randomValidServiceType(length: 7)
        randomlyGeneratedPeer = Peer()
    }

    override func tearDown() {
        randomlyGeneratedServiceType = nil
        randomlyGeneratedPeer = nil
        super.tearDown()
    }

    // MARK: - Tests
    func testAdvertiserReturnsObjectWhenValidServiceType() {
        // Given, When
        let advertiser = Advertiser(peer: randomlyGeneratedPeer,
                                    serviceType: randomlyGeneratedServiceType,
                                    receivedInvitation: unexpectedReceivedSessionHandler,
                                    sessionNotConnected: unexpectedDisconnectHandler)

        // Then
        XCTAssertNotNil(advertiser, "Advertiser object is nil and could not be created")
    }

    func testAdvertiserReturnsNilWhenEmptyServiceType() {
        // Given
        let emptyServiceType = String.randomValidServiceType(length: 0)

        // When
        let advertiser = Advertiser(peer: randomlyGeneratedPeer,
                                    serviceType: emptyServiceType,
                                    receivedInvitation: unexpectedReceivedSessionHandler,
                                    sessionNotConnected: unexpectedDisconnectHandler)

        // Then
        XCTAssertNil(advertiser, "Advertiser object is created with empty serviceType parameter")
    }

    func testStartStopChangesAdvertisingState() {
        // Given
        let newAdvertiser = Advertiser(peer: randomlyGeneratedPeer,
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       sessionNotConnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            failAdvertiserMustNotBeNil()
            return
        }

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)
        // Then
        XCTAssertTrue(advertiser.advertising)

        // When
        advertiser.stopAdvertising()
        // Then
        XCTAssertFalse(advertiser.advertising)
    }

    func testStartStopStartChangesAdvertisingState() {
        // Given
        let newAdvertiser = Advertiser(peer: randomlyGeneratedPeer,
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       sessionNotConnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            failAdvertiserMustNotBeNil()
            return
        }

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)
        // Then
        XCTAssertTrue(advertiser.advertising)

        // When
        advertiser.stopAdvertising()
        // Then
        XCTAssertFalse(advertiser.advertising)

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)
        // Then
        XCTAssertTrue(advertiser.advertising)
    }

    func testStartCalledTwiceChangesStateProperly() {
        // Given
        let newAdvertiser = Advertiser(peer: randomlyGeneratedPeer,
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       sessionNotConnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            failAdvertiserMustNotBeNil()
            return
        }

        advertiser.startAdvertising(unexpectedErrorHandler)
        XCTAssertTrue(advertiser.advertising)

        // When
        advertiser.startAdvertising(unexpectedErrorHandler)

        // Then
        XCTAssertTrue(advertiser.advertising)
    }

    func testStopCalledTwiceChangesStateProperly() {
        // Given
        let newAdvertiser = Advertiser(peer: randomlyGeneratedPeer,
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       sessionNotConnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            failAdvertiserMustNotBeNil()
            return
        }

        advertiser.startAdvertising(unexpectedErrorHandler)
        XCTAssertTrue(advertiser.advertising)
        advertiser.stopAdvertising()
        XCTAssertFalse(advertiser.advertising)

        // When
        advertiser.stopAdvertising()

        // Then
        XCTAssertFalse(advertiser.advertising)
    }

    func testStartAdvertisingErrorHandlerInvoked() {
        // Expectations
        var startAdvertisingErrorHandlerCalled: XCTestExpectation?

        // Given
        startAdvertisingErrorHandlerCalled =
            expectationWithDescription("startAdvertisingErrorHandler is called")

        let newAdvertiser = Advertiser(peer: randomlyGeneratedPeer,
                                       serviceType: randomlyGeneratedServiceType,
                                       receivedInvitation: unexpectedReceivedSessionHandler,
                                       sessionNotConnected: unexpectedDisconnectHandler)

        guard let advertiser = newAdvertiser else {
            failAdvertiserMustNotBeNil()
            return
        }

        advertiser.startAdvertising {
            [weak startAdvertisingErrorHandlerCalled] error in
            startAdvertisingErrorHandlerCalled?.fulfill()
        }

        let mcAdvertiser = MCNearbyServiceAdvertiser(peer: MCPeerID(displayName: "test"),
                                                     discoveryInfo: nil,
                                                     serviceType: "test")

        // When
        // Fake invocation of delegate method
        let error = NSError(domain: "org.thaliproject.test",
                            code: 42,
                            userInfo: nil)
        advertiser.advertiser(mcAdvertiser, didNotStartAdvertisingPeer: error)

        // Then
        waitForExpectationsWithTimeout(startAdvertisingErrorTimeout) {
            error in
            startAdvertisingErrorHandlerCalled = nil
        }
    }

    // MARK: - Private methods
    private func failAdvertiserMustNotBeNil() {
        XCTFail("Advertiser must not be nil")
    }
}
