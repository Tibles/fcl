//
//  File.swift
//  File
//
//  Created by lmcmz on 6/10/21.
//

import BigInt
import Combine
import Flow
import Foundation

extension FCL {
    public struct Signable: Encodable {
        public let fType: String = "Signable"
        public let fVsn: String = "1.0.1"
        public let data = [String: String]()
        public let message: String
        public let keyId: Int?
        public let addr: String?
        public let roles: Role
        public let cadence: String?
        public let args: [Flow.Argument]
        var interaction = Interaction()

        enum CodingKeys: String, CodingKey {
            case fType = "f_type"
            case fVsn = "f_vsn"
            case roles, data, message, keyId, addr, cadence, args, interaction, voucher
        }

        var voucher: Voucher {
            let insideSigners: [Singature] = interaction.findInsideSigners.compactMap { id in
                guard let account = interaction.accounts[id] else { return nil }
                return Singature(address: account.addr?.sansPrefix(),
                                 keyId: account.keyID,
                                 sig: account.signature)
            }

            let outsideSigners: [Singature] = interaction.findOutsideSigners.compactMap { id in
                guard let account = interaction.accounts[id] else { return nil }
                return Singature(address: account.addr?.sansPrefix(),
                                 keyId: account.keyID,
                                 sig: account.signature)
            }

            return Voucher(cadence: interaction.message.cadence,
                           refBlock: interaction.message.refBlock,
                           computeLimit: interaction.message.computeLimit,
                           arguments: interaction.message.arguments.compactMap { tempId in
                               interaction.arguments[tempId]?.asArgument
                           },
                           proposalKey: interaction.createProposalKey(),
                           payer: interaction.accounts[interaction.payer ?? ""]?.addr?.sansPrefix(),
                           authorizers: interaction.authorizations
                               .compactMap { cid in interaction.accounts[cid]?.addr?.sansPrefix() }
                               .uniqued(),
                           payloadSigs: insideSigners,
                           envelopeSigs: outsideSigners)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fType, forKey: .fType)
            try container.encode(fVsn, forKey: .fVsn)
            try container.encode(data, forKey: .data)
            try container.encode(message, forKey: .message)
            try container.encode(keyId, forKey: .keyId)
            try container.encode(roles, forKey: .roles)
            try container.encode(cadence, forKey: .cadence)
            try container.encode(addr, forKey: .addr)
            try container.encode(args, forKey: .args)
            try container.encode(interaction, forKey: .interaction)
            try container.encode(voucher, forKey: .voucher)
        }
    }

    struct PreSignable: Encodable {
        let fType: String = "PreSignable"
        let fVsn: String = "1.0.1"
        let roles: Role
        let cadence: String
        var args: [Flow.Argument] = []
        let data = [String: String]()
        var interaction = Interaction()

        var voucher: Voucher {
            let insideSigners: [Singature] = interaction.findInsideSigners.compactMap { id in
                guard let account = interaction.accounts[id] else { return nil }
                return Singature(address: account.addr,
                                 keyId: account.keyID,
                                 sig: account.signature)
            }

            let outsideSigners: [Singature] = interaction.findOutsideSigners.compactMap { id in
                guard let account = interaction.accounts[id] else { return nil }
                return Singature(address: account.addr,
                                 keyId: account.keyID,
                                 sig: account.signature)
            }

            return Voucher(cadence: interaction.message.cadence,
                           refBlock: interaction.message.refBlock,
                           computeLimit: interaction.message.computeLimit,
                           arguments: interaction.message.arguments.compactMap { tempId in
                               interaction.arguments[tempId]?.asArgument
                           },
                           proposalKey: interaction.createProposalKey(),
                           payer: interaction.payer,
                           authorizers: interaction.authorizations
                               .compactMap { cid in interaction.accounts[cid]?.addr }
                               .uniqued(),
                           payloadSigs: insideSigners,
                           envelopeSigs: outsideSigners)
        }

        enum CodingKeys: String, CodingKey {
            case fType = "f_type"
            case fVsn = "f_vsn"
            case roles, cadence, args, interaction
            case voucher
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fType, forKey: .fType)
            try container.encode(fVsn, forKey: .fVsn)
            try container.encode(roles, forKey: .roles)
            try container.encode(cadence, forKey: .cadence)
            try container.encode(args, forKey: .args)
            try container.encode(interaction, forKey: .interaction)
            try container.encode(voucher, forKey: .voucher)
        }
    }

    struct Argument: Encodable {
        var kind: String
        var tempId: String
        var value: Flow.Cadence.FValue
        var asArgument: Flow.Argument
        var xform: Xform
    }

    struct Xform: Codable {
        var label: String
    }

    struct Interaction: Encodable {
        var tag: Tag = .unknown
        var assigns = [String: String]()
        var status: Status = .ok
        var reason: String?
        var accounts = [String: SignableUser]()
        var params = [String: String]()
        var arguments = [String: Argument]()
        var message = Message()
        var proposer: String?
        var authorizations = [String]()
        var payer: String?
        var events = Events()
        var transaction = Id()
        var block = Block()
        var account = Account()
        var collection = Id()

        enum Status: String, CaseIterable, Codable {
            case ok = "OK"
            case bad = "BAD"
        }

        enum Tag: String, CaseIterable, Codable {
            case unknown = "UNKNOWN"
            case script = "SCRIPT"
            case transaction = "TRANSACTION"
            case getTransactionStatus = "GET_TRANSACTION_STATUS"
            case getAccount = "GET_ACCOUNT"
            case getEvents = "GET_EVENTS"
            case getLatestBlock = "GET_LATEST_BLOCK"
            case ping = "PING"
            case getTransaction = "GET_TRANSACTION"
            case getBlockById = "GET_BLOCK_BY_ID"
            case getBlockByHeight = "GET_BLOCK_BY_HEIGHT"
            case getBlock = "GET_BLOCK"
            case getBlockHeader = "GET_BLOCK_HEADER"
            case getCollection = "GET_COLLECTION"
        }

        var isUnknown: Bool { `is`(.unknown) }
        var isScript: Bool { `is`(.script) }
        var isTransaction: Bool { `is`(.transaction) }

        func `is`(_ tag: Tag) -> Bool {
            self.tag == tag
        }

        @discardableResult
        mutating func setTag(_ tag: Tag) -> Self {
            self.tag = tag
            return self
        }

      var findInsideSigners: [String] {
        // Inside Signers Are: (authorizers + proposer) - payer

        var ins: [String] = []

        authorizations.forEach {
          if !ins.contains($0) {
            ins.append($0)
          }
        }

        if let proposer = proposer, !ins.contains(proposer) {
          ins.append(proposer)
        }

        if let payer = payer {
          ins.removeAll { $0 == payer }
        }

        return ins
      }

        var findOutsideSigners: [String] {
            // Outside Signers Are: (payer)
            guard let payer = payer else {
                return []
            }
            let outside = Set([payer])
            return Array(outside)
        }

        func createProposalKey() -> ProposalKey {
            guard let proposer = proposer,
                  let account = accounts[proposer]
            else {
                return ProposalKey()
            }

            return ProposalKey(address: account.addr?.sansPrefix(),
                               keyID: account.keyID,
                               sequenceNum: account.sequenceNum)
        }

        func createFlowProposalKey() async throws -> Flow.TransactionProposalKey {
            guard let proposer = proposer,
                  var account = accounts[proposer],
                  let address = account.addr,
                  let keyID = account.keyID
            else {
                throw FCLError.invaildProposer
            }

            let flowAddress = Flow.Address(hex: address)

            if account.sequenceNum == nil {
                let accountData = try await flow.accessAPI.getAccountAtLatestBlock(address: flowAddress)
                account.sequenceNum = Int(accountData.keys[keyID].sequenceNumber)
                let key = Flow.TransactionProposalKey(address: Flow.Address(hex: address),
                                                      keyIndex: keyID,
                                                      sequenceNumber: Int64(account.sequenceNum ?? 0))
                return key
            } else {
                let key = Flow.TransactionProposalKey(address: Flow.Address(hex: address),
                                                      keyIndex: keyID,
                                                      sequenceNumber: Int64(account.sequenceNum ?? 0))
                return key
            }
        }

        func buildPreSignable(role: Role) -> PreSignable {
            return PreSignable(roles: role,
                               cadence: message.cadence ?? "",
                               args: message.arguments.compactMap { tempId in arguments[tempId]?.asArgument },
                               interaction: self)
        }

        func toFlowTransaction() async throws -> Flow.Transaction {
            let proposalKey = try await createFlowProposalKey()

            guard let payerAccount = payer,
                  let payerAddress = accounts[payerAccount]?.addr
            else {
                throw FCLError.missingPayer
            }

            var tx = Flow.Transaction(script: Flow.Script(text: message.cadence ?? ""),
                                      arguments: message.arguments.compactMap { tempId in arguments[tempId]?.asArgument },
                                      referenceBlockId: Flow.ID(hex: message.refBlock ?? ""),
                                      gasLimit: BigUInt(message.computeLimit ?? 100),
                                      proposalKey: proposalKey,
                                      payer: Flow.Address(hex: payerAddress),
                                      authorizers: authorizations
                                          .compactMap { cid in accounts[cid]?.addr }
                                          .uniqued()
                                          .compactMap { Flow.Address(hex: $0) })

            let insideSigners = findInsideSigners
            insideSigners.forEach { address in
                if let account = accounts[address],
                   let address = account.addr,
                   let keyId = account.keyID,
                   let signature = account.signature
                {
                    tx.addPayloadSignature(address: Flow.Address(hex: address),
                                           keyIndex: keyId,
                                           signature: Data(signature.hexValue))
                }
            }

            let outsideSigners = findOutsideSigners

            outsideSigners.forEach { address in
                if let account = accounts[address],
                   let address = account.addr,
                   let keyId = account.keyID,
                   let signature = account.signature
                {
                    tx.addEnvelopeSignature(address: Flow.Address(hex: address),
                                            keyIndex: keyId,
                                            signature: Data(signature.hexValue))
                }
            }
            return tx
        }
    }

    struct Block: Codable {
        var id: String?
        var height: Int64?
        var isSealed: Bool?
    }

    struct Account: Codable {
        var addr: String?
    }

    struct Id: Encodable {
        var id: String?
    }

    struct Events: Codable {
        var eventType: String?
        var start: String?
        var end: String?
        var blockIDS: [String] = []

        enum CodingKeys: String, CodingKey {
            case eventType, start, end
            case blockIDS = "blockIds"
        }
    }

    struct Message: Codable {
        var cadence: String?
        var refBlock: String?
        var computeLimit: Int?
        var proposer: String?
        var payer: String?
        var authorizations: [String] = []
        var params: [String] = []
        var arguments: [String] = []
    }

    struct Voucher: Codable {
        let cadence: String?
        let refBlock: String?
        let computeLimit: Int?
        let arguments: [Flow.Argument]
        let proposalKey: ProposalKey
        var payer: String?
        let authorizers: [String]?
        let payloadSigs: [Singature]?
        let envelopeSigs: [Singature]?
    }

    struct Accounts: Encodable {
        let currentUser: SignableUser

        enum CodingKeys: String, CodingKey {
            case currentUser = "CURRENT_USER"
        }
    }

    struct Singature: Codable {
        let address: String?
        let keyId: Int?
        let sig: String?
    }

    struct SignableUser: Encodable, Equatable {
        var kind: String?
        var tempID: String?
        var addr: String?
        var signature: String?
        var keyID: Int?
        var sequenceNum: Int?
        var role: Role

        var signer: FCLSigner?
        var signerIndex: [String: Int]?

        enum CodingKeys: String, CodingKey {
            case kind
            case tempID = "tempId"
            case addr
            case keyID = "keyId"
            case sequenceNum, signature, role
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            try container.encode(tempID, forKey: .tempID)
            try container.encode(addr, forKey: .addr)
            try container.encode(signature, forKey: .signature)
            try container.encode(keyID, forKey: .keyID)
            try container.encode(sequenceNum, forKey: .sequenceNum)
            try container.encode(role, forKey: .role)
        }

        static func == (lhs: SignableUser, rhs: SignableUser) -> Bool {
            guard let lId = lhs.tempID, let rId = rhs.tempID else {
                return false
            }
            return lId == rId
        }
    }

    struct ProposalKey: Codable {
        var address: String?
        var keyID: Int?
        var sequenceNum: Int?

        enum CodingKeys: String, CodingKey {
            case address
            case keyID = "keyId"
            case sequenceNum
        }
    }

    public struct Role: Encodable {
        public var proposer: Bool = false
        public var authorizer: Bool = false
        public var payer: Bool = false
        public var param: Bool?

        mutating func merge(role: Role) {
            proposer = proposer || role.proposer
            authorizer = authorizer || role.authorizer
            payer = payer || role.payer
        }
    }

    // TODO: Change to OptionSet
    public enum Roles: String {
        case proposer
        case authorizer
        case payer
    }
}

// MARK: - CurrentUser

extension Flow.Argument {
    func toFCLArgument() -> FCL.Argument {
        func randomString(length: Int) -> String {
            let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
            return String((0 ..< length).map { _ in letters.randomElement()! })
        }

        return FCL.Argument(kind: "ARGUMENT",
                            tempId: randomString(length: 10),
                            value: value,
                            asArgument: self,
                            xform: FCL.Xform(label: type.rawValue))
    }
}

public protocol FCLSigner {
    var address: Flow.Address { get }
    var keyIndex: Int { get }
    func signingFunction(signable: FCL.Signable) async throws -> AuthzResponse
}

public protocol AuthzResponse {
    var addr: Flow.Address { get }
    var keyId: Int { get }
    var signature: Flow.Signature { get }
}

extension FCLSigner {
    var tempID: String {
        [address.hex.addHexPrefix(), String(keyIndex)].joined(separator: "|")
    }

    var signableUser: FCL.SignableUser {
        .init(kind: nil,
              tempID: tempID,
              addr: address.hex.addHexPrefix(),
              signature: nil,
              keyID: keyIndex,
              sequenceNum: nil,
              role: FCL.Role(),
              signer: self)
    }
}

extension FCL.SignableUser: FCLSigner {
    var address: Flow.Address {
        .init(hex: addr ?? "0x")
    }

    var keyIndex: Int {
        keyID ?? 0
    }

    func signingFunction(signable: FCL.Signable) async throws -> AuthzResponse {
        if let signer {
            return try await signer.signingFunction(signable: signable)
        }

        if let preAuthz = fcl.preAuthz {
            var array = (preAuthz.data?.payer ?? []) + (preAuthz.data?.authorization ?? [])
            if let proposer = preAuthz.data?.proposer {
                array.append(proposer)
            }
            guard let authz = array.first(where: { $0.identity?.address.addHexPrefix() == addr?.addHexPrefix() }) else {
                throw FCLError.missingAuthz
            }

            return try await fcl.getStategy().execService(service: authz, request: signable)
        }

        guard let authzList = fcl.currentUser?.services?.filter({ $0.type == .authz }),
              let authz = authzList.first(where: { $0.identity?.address.addHexPrefix() == addr?.addHexPrefix() })
        else {
            throw FCLError.missingAuthz
        }

        return try await fcl.getStategy().execService(service: authz, request: signable)
    }
}

extension FCL.SignableUser {
    func toIndentity() -> FCL.Identity? {
        if let addr {
            return .init(address: addr, keyId: keyIndex)
        }
        return nil
    }

    func toService() -> FCL.Service? {
        guard let addr else {
            return nil
        }

        return .init(fType: "Service",
                     fVsn: "1.0.0",
                     type: .authz,
                     method: .walletConnect,
                     endpoint: URL(string: fcl.config.get(.authn) ?? ""),
                     identity: .init(address: addr, keyId: keyIndex),
                     data: nil,
                     signer: signer)
    }
}
