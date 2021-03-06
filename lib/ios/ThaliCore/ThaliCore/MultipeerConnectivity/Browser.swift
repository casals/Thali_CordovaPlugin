//
//  Thali CordovaPlugin
//  Browser.swift
//
//  Copyright (C) Microsoft. All rights reserved.
//  Licensed under the MIT license.
//  See LICENSE.txt file in the project root for full license information.
//

import MultipeerConnectivity

/**
 The `Browser` class manages underlying `MCNearbyServiceBrowser` object
 and handles `MCNearbyServiceBrowserDelegate` events
 */
final class Browser: NSObject {

  // MARK: - Internal state

  /**
   Bool flag indicates if `Browser` object is listening for advertisements.
   */
  internal private(set) var listening: Bool = false

  /**
   Timeout for inviting a remote peer to a MCSession.
   */
  internal let invitePeerTimeout: NSTimeInterval = 30.0

  // MARK: - Private state

  /**
   MCNearbyServiceBrowser object.
   */
  private let browser: MCNearbyServiceBrowser

  /**
   Represents peers who can be invited into MCSession.
   */
  private var availablePeers: Atomic<[Peer: MCPeerID]> = Atomic([:])

  /**
   Handle finding nearby peer.
   */
  private let didFindPeerHandler: (Peer) -> Void

  /**
   Handle losing nearby peer.
   */
  private let didLosePeerHandler: (Peer) -> Void

  /**
   Handle failing browsing.
   */
  private var startBrowsingErrorHandler: (ErrorType -> Void)? = nil

  // MARK: - Initialization

  /**
   Returns a new `Browser` object or nil if it could not be created.

   - parameters:
     - serviceType:
       The type of service to browse.
       This should be a string in the format of Bonjour service type:
       1. *Must* be 1–15 characters long
       2. Can contain *only* ASCII letters, digits, and hyphens.
       3. *Must* contain at least one ASCII letter
       4. *Must* not begin or end with a hyphen
       5. Hyphens must not be adjacent to other hyphens

       For more details, see [RFC6335](https://tools.ietf.org/html/rfc6335#section-5.1).

     - foundPeer:
       Called when a nearby peer is found.

     - lostPeer:
       Called when a nearby peer is lost.

   - returns:
     An initialized `Browser` object, or nil if an object could not be created
     due to invalid `serviceType` format.
   */
  required init?(serviceType: String,
                 foundPeer: (Peer) -> Void,
                 lostPeer: (Peer) -> Void) {
    guard String.isValidServiceType(serviceType) else {
      return nil
    }

    let mcPeerID = MCPeerID(displayName: NSUUID().UUIDString)
    browser = MCNearbyServiceBrowser(peer: mcPeerID, serviceType: serviceType)
    didFindPeerHandler = foundPeer
    didLosePeerHandler = lostPeer
  }

  // MARK: - Internal methods
  /**
   Begins listening for `serviceType` provided in init method.

   This method sets `listening` value to `true`.
   It does not change state if `Browser` is already listening.

   - parameters:
     - startListeningErrorHandler:
       Called when a browser failed to start browsing for peers.
   */
  func startListening(startListeningErrorHandler: ErrorType -> Void) {
    if !listening {
      startBrowsingErrorHandler = startListeningErrorHandler
      browser.delegate = self
      browser.startBrowsingForPeers()
      listening = true
    }
  }

  /**
   Stops listening for the `serviceType` provided in init method.

   This method sets `listening` value to `false`.
   It does not change state if `Browser` is already not listening.
   */
  func stopListening() {
    browser.delegate = nil
    browser.stopBrowsingForPeers()
    listening = false
  }

  /**
   Invites Peer into the session

   - parameters:
     - peer:
       `Peer` to invite.

     - sessionConnected:
       Called when the peer is connected to this session.

     - sessionNotConnected:
       Called when the nearby peer is not (or is no longer) in this session.

   - throws: IllegalPeerID

   - returns: Session object that manages MCSession between peers
   */
  func inviteToConnect(peer: Peer,
                       sessionConnected: () -> Void,
                       sessionNotConnected: () -> Void) throws -> Session {

    let mcSession = MCSession(peer: browser.myPeerID,
                              securityIdentity: nil,
                              encryptionPreference: .None)

    guard let mcPeerID = availablePeers.value[peer] else {
      throw ThaliCoreError.IllegalPeerID
    }

    let session = Session(session: mcSession,
                          identifier: mcPeerID,
                          connected: sessionConnected,
                          notConnected: sessionNotConnected)

    browser.invitePeer(mcPeerID,
                       toSession: mcSession,
                       withContext: nil,
                       timeout: invitePeerTimeout)
    return session
  }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension Browser: MCNearbyServiceBrowserDelegate {

  func browser(browser: MCNearbyServiceBrowser,
               foundPeer peerID: MCPeerID,
               withDiscoveryInfo info: [String: String]?) {
    do {
      let peer = try Peer(mcPeerID: peerID)
      availablePeers.modify { $0[peer] = peerID }
      didFindPeerHandler(peer)
    } catch let error {
      print("cannot parse identifier \"\(peerID.displayName)\" because of error: \(error)")
    }
  }

  func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    do {
      let peer = try Peer(mcPeerID: peerID)
      availablePeers.modify { $0.removeValueForKey(peer) }
      didLosePeerHandler(peer)
    } catch let error {
      print("cannot parse identifier \"\(peerID.displayName)\" because of error: \(error)")
    }
  }

  func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
    stopListening()
    startBrowsingErrorHandler?(error)
  }
}
