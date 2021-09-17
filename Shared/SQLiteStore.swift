import KeychainStored
import Crypto
import CypherMessaging
import FluentSQLiteDriver
import Foundation
import FluentKit

enum SQLiteError: Error {
    case notFound
}

fileprivate final class _ConfigurationModel: FluentKit.Model {
    static let schema = "a"

    @ID(custom: .id) var id: String?
    @Field(key: "a") var data: Data

    init() {}

    init(key: String, data: Data) {
        self.id = key
        self.data = data
    }
}

fileprivate final class _ConversationModel: FluentKit.Model {
    static let schema = "b"

    @ID(key: .id) var id: UUID?
    @Field(key: "a") var data: Data

    init() {}

    init(conversation: ConversationModel, new: Bool) {
        self.id = conversation.id
        $id.exists = !new
        self.data = conversation.props.makeData()
    }

    func makeConversation() throws -> ConversationModel {
        try ConversationModel(
            id: id!,
            props: Encrypted<ConversationModel.SecureProps>(representing: AES.GCM.SealedBox(combined: data))
        )
    }
}

fileprivate final class _ChatMessageModel: FluentKit.Model {
    static let schema = "c"

    @ID(key: .id) var id: UUID?
    @Field(key: "a") var data: Data
    @Field(key: "b") var conversationId: UUID
    @Field(key: "c") var senderId: Int
    @Field(key: "d") var order: Int
    @Field(key: "e") var remoteId: String

    init() {}

    init(chatMessage: ChatMessageModel, new: Bool) {
        self.id = chatMessage.id
        $id.exists = !new
        self.data = chatMessage.props.makeData()
        self.conversationId = chatMessage.conversationId
        self.senderId = chatMessage.senderId
        self.order = chatMessage.order
        self.remoteId = chatMessage.remoteId
    }

    func makeChatMessage() throws -> ChatMessageModel {
        try ChatMessageModel(
            id: id!,
            conversationId: conversationId,
            senderId: senderId,
            order: order,
            props: .init(representing: AES.GCM.SealedBox(combined: data))
        )
    }
}

fileprivate final class _DeviceIdentityModel: FluentKit.Model {
    static let schema = "d"

    @ID(key: .id) var id: UUID?
    @Field(key: "a") var data: Data

    init() {}

    init(deviceIdentity: DeviceIdentityModel, new: Bool) {
        self.id = deviceIdentity.id
        self.$id.exists = !new
        self.data = deviceIdentity.props.makeData()
    }

    func makeDeviceIdentity() throws -> DeviceIdentityModel {
        try DeviceIdentityModel(
            id: id!,
            props: Encrypted<DeviceIdentityModel.SecureProps>(representing: AES.GCM.SealedBox(combined: data))
        )
    }
}

fileprivate final class _JobModel: FluentKit.Model {
    static let schema = "e"

    @ID(key: .id) var id: UUID?
    @Field(key: "a") var data: Data

    init() {}

    init(job: JobModel, new: Bool) {
        self.id = job.id
        self.$id.exists = !new
        self.data = job.props.makeData()
    }

    func makeJob() throws -> JobModel {
        try JobModel(
            id: id!,
            props: Encrypted<JobModel.SecureProps>(representing: AES.GCM.SealedBox(combined: data))
        )
    }
}

fileprivate final class _ContactModel: FluentKit.Model {
    static let schema = "f"

    @ID(key: .id) var id: UUID?
    @Field(key: "a") var data: Data

    init() {}

    init(contact: ContactModel, new: Bool) {
        self.id = contact.id
        $id.exists = !new
        self.data = contact.props.makeData()
    }

    func makeContact() throws -> ContactModel {
        try ContactModel(
            id: id!,
            props: Encrypted<ContactModel.SecureProps>(representing: AES.GCM.SealedBox(combined: data))
        )
    }
}

struct CreateConfigMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ConfigurationModel.schema)
            .id()
            .field("a", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ConfigurationModel.schema).delete()
    }
}

struct CreateChatMessagesMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ChatMessageModel.schema)
            .id()
            .field("a", .data, .required)
            .field("b", .string, .required)
            .field("c", .int, .required)
            .field("d", .int, .required)
            .field("e", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ChatMessageModel.schema).delete()
    }
}

struct CreateConversationsMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ConversationModel.schema)
            .id()
            .field("a", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ConversationModel.schema).delete()
    }
}

struct CreateDeviceIdentitiesMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_DeviceIdentityModel.schema)
            .id()
            .field("a", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_DeviceIdentityModel.schema).delete()
    }
}

struct CreateJobMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_JobModel.schema)
            .id()
            .field("a", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_JobModel.schema).delete()
    }
}

struct CreateContactMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ContactModel.schema)
            .id()
            .field("a", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(_ContactModel.schema).delete()
    }
}

fileprivate func makeSQLiteURL() -> String {
    guard var url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
        fatalError()
    }

    url = url.appendingPathComponent("db")

    if FileManager.default.fileExists(atPath: url.path) {
        var excludedFromBackup = URLResourceValues()
        excludedFromBackup.isExcludedFromBackup = true
        try! url.setResourceValues(excludedFromBackup)
    }

    return url.path
}

// TODO: This can become a `struct` when the keychain property is in function scope
final class SQLiteStore: CypherMessengerStore {
    let databases: Databases
    let database: Database
    var eventLoop: EventLoop { database.eventLoop }

    // TODO: Property in function scope
    @KeychainStored(service: "com.example.dbsalt")  var keychainSalt: String?

    private init(databases: Databases, database: Database) {
        self.databases = databases
        self.database = database
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: makeSQLiteURL())
    }

    static func destroy() {
        try? FileManager.default.removeItem(atPath:makeSQLiteURL())
    }

    func destroy() {
        // TODO: Support multiple containers
        Self.destroy()
    }

    public static func create(
        on eventLoop: EventLoop
    ) async throws -> SQLiteStore {
        try await self.create(withConfiguration: .file(makeSQLiteURL()), on: eventLoop).get()
    }

    static func create(
        withConfiguration configuration: SQLiteConfiguration,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SQLiteStore> {
        let databases = Databases(
            threadPool: NIOThreadPool(numberOfThreads: 1),
            on: eventLoop
        )

        databases.use(.sqlite(configuration), as: .sqlite)
        let logger = Logger(label: "sqlite")

        let migrations = Migrations()
        migrations.add(CreateConfigMigration())
        migrations.add(CreateConversationsMigration())
        migrations.add(CreateChatMessagesMigration())
        migrations.add(CreateDeviceIdentitiesMigration())
        migrations.add(CreateJobMigration())
        migrations.add(CreateContactMigration())

        let migrator = Migrator(databases: databases, migrations: migrations, logger: logger, on: eventLoop)
        return migrator.setupIfNeeded().flatMap {
            migrator.prepareBatch()
        }.recover { _ in }.map {
            return SQLiteStore(
                databases: databases,
                database: databases.database(logger: logger, on: eventLoop)!
            )
        }.flatMapErrorThrowing { error in
            databases.shutdown()
            throw error
        }
    }
    
    func fetchContacts() async throws -> [ContactModel] {
        try await _ContactModel.query(on: database).all().flatMapEachThrowing {
            try $0.makeContact()
        }.get()
    }
    
    func createContact(_ contact: ContactModel) async throws {
        try await _ContactModel(contact: contact, new: true).create(on: database).get()
    }
    func updateContact(_ contact: ContactModel) async throws {
        try await _ContactModel(contact: contact, new: false).update(on: database).get()
    }
    func removeContact(_ contact: ContactModel) async throws {
        try await _ContactModel(contact: contact, new: false).delete(on: database).get()
    }
    
    func fetchConversations() async throws -> [ConversationModel] {
        try await _ConversationModel.query(on: database).all().flatMapEachThrowing {
            try $0.makeConversation()
        }.get()
    }
    func createConversation(_ conversation: ConversationModel) async throws {
        try await _ConversationModel(conversation: conversation, new: true).create(on: database).get()
    }
    func updateConversation(_ conversation: ConversationModel) async throws {
        try await _ConversationModel(conversation: conversation, new: false).update(on: database).get()
    }
    func removeConversation(_ conversation: ConversationModel) async throws {
        try await _ConversationModel(conversation: conversation, new: false).delete(on: database).get()
    }
    
    func fetchDeviceIdentities() async throws -> [DeviceIdentityModel] {
        try await _DeviceIdentityModel.query(on: database).all().flatMapEachThrowing {
            try $0.makeDeviceIdentity()
        }.get()
    }
    func createDeviceIdentity(_ deviceIdentity: DeviceIdentityModel) async throws {
        try await _DeviceIdentityModel(deviceIdentity: deviceIdentity, new: true).create(on: database).get()
    }
    func updateDeviceIdentity(_ deviceIdentity: DeviceIdentityModel) async throws {
        try await _DeviceIdentityModel(deviceIdentity: deviceIdentity, new: false).update(on: database).get()
    }
    func removeDeviceIdentity(_ deviceIdentity: DeviceIdentityModel) async throws {
        try await _DeviceIdentityModel(deviceIdentity: deviceIdentity, new: false).delete(on: database).get()
    }
    
    func fetchChatMessage(byId messageId: UUID) async throws -> ChatMessageModel {
        try await _ChatMessageModel.find(messageId, on: database).unwrap(orError: SQLiteError.notFound).flatMapThrowing {
            try $0.makeChatMessage()
        }.get()
    }
    func fetchChatMessage(byRemoteId remoteId: String) async throws -> ChatMessageModel {
        guard let message = try await _ChatMessageModel.query(on: database).filter(\.$remoteId == remoteId).first().get() else {
            throw SQLiteError.notFound
        }
        
        return try message.makeChatMessage()
    }
    func createChatMessage(_ message: ChatMessageModel) async throws {
        try await _ChatMessageModel(chatMessage: message, new: true).create(on: database).get()
    }
    func updateChatMessage(_ message: ChatMessageModel) async throws {
        try await _ChatMessageModel(chatMessage: message, new: false).update(on: database).get()
    }
    func removeChatMessage(_ message: ChatMessageModel) async throws {
        try await _ChatMessageModel(chatMessage: message, new: false).delete(on: database).get()
    }
    func listChatMessages(
        inConversation conversationId: UUID,
        senderId: Int,
        sortedBy sortMode: SortMode,
        minimumOrder: Int?,
        maximumOrder: Int?,
        offsetBy offset: Int,
        limit: Int
    ) async throws -> [ChatMessageModel] {
        var query = _ChatMessageModel.query(on: database)
            .filter(\.$conversationId == conversationId)
            .filter(\.$senderId == senderId)

        if let minimumOrder = minimumOrder {
            query = query.filter(\.$order > minimumOrder)
        }

        if let maximumOrder = maximumOrder {
            query = query.filter(\.$order < maximumOrder)
        }

        return try await query
            .sort(\.$order, sortMode == .ascending ? .ascending : .descending)
            .offset(offset)
            .limit(limit)
            .all()
            .flatMapEachThrowing { message in
                try message.makeChatMessage()
            }.get()
    }
    
    func readLocalDeviceConfig() async throws -> Data {
        try await _ConfigurationModel.find("config", on: database)
            .unwrap(orError: SQLiteError.notFound)
            .map(\.data)
            .get()
    }
    
    func writeLocalDeviceConfig(_ data: Data) async throws {
        try await _ConfigurationModel.find("config", on: database).flatMap { config -> EventLoopFuture<Void> in
            if let config = config {
                config.data = data
                return config.save(on: self.database)
            } else {
                return _ConfigurationModel(key: "config", data: data).save(on: self.database)
            }
        }.get()
    }
    
    func readLocalDeviceSalt() async throws -> String {
        if let keychainSalt = keychainSalt {
            return keychainSalt
        } else {
            let keychainSalt = UUID().uuidString
            self.keychainSalt = keychainSalt
            return keychainSalt
        }
    }
    
    func readJobs() async throws -> [JobModel] {
        try await _JobModel.query(on: database).all().flatMapEachThrowing {
            try $0.makeJob()
        }.get()
    }
    
    func createJob(_ job: JobModel) async throws {
        try await _JobModel(job: job, new: true).create(on: database).get()
    }
    
    func updateJob(_ job: JobModel) async throws {
        try await _JobModel(job: job, new: false).update(on: database).get()
    }
    
    func removeJob(_ job: JobModel) async throws {
        try await _JobModel(job: job, new: false).delete(on: database).get()
    }
    

    deinit {
        DispatchQueue.main.async { [databases] in
            databases.shutdown()
        }
    }
}
