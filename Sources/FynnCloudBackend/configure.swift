import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import JWT
import SotoCore
import SotoS3
import Vapor

public func configure(_ app: Application) async throws {
    let config = AppConfig.load(for: app)
    app.config = config

    app.routes.defaultMaxBodySize = config.maxBodySize
    configureCORS(app, config: config)
    configureErrorMiddleware(app)

    switch config.database {
    case .postgres(let pgConfig):
        app.databases.use(.postgres(configuration: pgConfig), as: .psql)
    case .sqlite(let filename):
        app.databases.use(.sqlite(.file(filename)), as: .sqlite)
    }

    switch config.storage {
    case .s3(let bucket):
        app.logger.info("Using S3 storage with bucket: \(bucket)")
        let awsClient = AWSClient(
            credentialProvider: .static(
                accessKeyId: config.aws.accessKey,
                secretAccessKey: config.aws.secretKey
            ),
            retryPolicy: .default,
            options: .init(),
            logger: app.logger
        )
        app.services.awsClient.use { _ in awsClient }
        app.lifecycle.use(AWSLifecycleHandler())
        app.fileStorage = S3StorageProvider(
            s3: S3(
                client: awsClient, region: .init(awsRegionName: config.aws.region),
                endpoint: config.aws.endpoint), bucket: bucket)

    case .local(let path):
        app.logger.info("Using local storage with path: \(path)")
        app.fileStorage = LocalFileSystemProvider(storageDirectory: path)
    }

    if config.ldapEnabled {
        let ldapService = LDAPService(configuration: config.ldapConfig)
        app.services.ldap.use { _ in ldapService }
        app.lifecycle.use(LDAPLifecycleHandler())
        app.logger.info("Connecting to LDAP...")
        do {
            try await ldapService.connect()
            app.logger.info("✅ LDAP Connected Successfully")
        } catch {
            app.logger.error("❌ Failed to connect to LDAP: \(error)")
        }
    } else {
        app.logger.info("LDAP is disabled")
    }

    await app.jwt.keys.add(hmac: HMACKey(from: config.jwtSecret), digestAlgorithm: .sha256)

    app.migrations.add(CreateInitialMigration())
    app.migrations.add(CreateSyncLog())
    app.migrations.add(CreateOAuthCode())
    app.migrations.add(AddClientIdAndStateToOAuthCode())
    app.migrations.add(CreateOAuthGrant())
    app.migrations.add(UpdateGrantForRotation())
    app.migrations.add(CreateMultipartUploadSessions())

    try await app.autoMigrate()
    try routes(app)
}

// MARK: - Middleware

private func configureCORS(_ app: Application, config: AppConfig) {
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: app.environment == .production
            ? .any(config.corsAllowedOrigins)
            : .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [
            .accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent,
            .accessControlAllowOrigin,
        ],
        allowCredentials: false
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)
}

private func configureErrorMiddleware(_ app: Application) {
    app.middleware.use(
        ErrorMiddleware { req, error in
            let status: HTTPResponseStatus
            let reason: String
            let headers: HTTPHeaders
            let localizationKey: String?

            if let localizedError = error as? LocalizedAbort {
                status = localizedError.status
                reason = localizedError.reason
                headers = localizedError.headers
                localizationKey = localizedError.localizationKey
            } else if let abort = error as? (any AbortError) {
                status = abort.status
                reason = abort.reason
                headers = abort.headers
                localizationKey = "error.generic"
            } else {
                status = .internalServerError
                reason =
                    req.application.environment == .production
                    ? "An unexpected error occurred."
                    : String(reflecting: error)
                headers = [:]
                localizationKey = "error.generic"
            }

            let response = Response(status: status, headers: headers)
            var body: [String: String] = ["error": "true", "reason": reason]
            if let key = localizationKey { body["localizationKey"] = key }
            try? response.content.encode(body)
            return response
        })
}
