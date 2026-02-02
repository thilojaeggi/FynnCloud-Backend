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
            appName: Environment.process.APP_NAME ?? "FynnCloud",
            version: "1.0.0",
            maxFileSize: Int64(req.application.routes.defaultMaxBodySize.value),
            environment: req.application.environment.name,
            primaryColor: Self.getColor(),
        )
    }

    private static func getColor() -> String {
        let allowedColors = [
            "slate",
            "gray",
            "zinc",
            "neutral",
            "stone",
            "red",
            "orange",
            "amber",
            "yellow",
            "lime",
            "green",
            "emerald",
            "teal",
            "cyan",
            "sky",
            "blue",
            "indigo",
            "violet",
            "purple",
            "fuchsia",
            "pink",
            "rose",
        ]

        if let envColor = Environment.process.PRIMARY_COLOR, allowedColors.contains(envColor) {
            return envColor
        }

        return "blue"
    }
}
