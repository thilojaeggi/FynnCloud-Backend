import Vapor

struct ServerInfo: Content {
    let appName: String
    let version: String
    let maxFileSize: Int64
    let environment: String
    let primaryColor: String

}
struct MetaController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        let api = routes.grouped("api")
        api.get("info", use: info)
    }

    func info(req: Request) async throws -> ServerInfo {
        return ServerInfo(
            appName: req.application.config.appName,
            version: req.application.config.appVersion,
            maxFileSize: Int64(req.application.routes.defaultMaxBodySize.value),
            environment: req.application.environment.name,
            primaryColor: req.application.config.primaryColor.rawValue
        )
    }
}
