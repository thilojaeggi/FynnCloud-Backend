import Fluent
import Vapor

struct CreateMultipartUploadSessions: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(MultipartUploadSession.schema)
            .id()
            .field("file_id", .uuid, .required)
            .field("upload_id", .string, .required)
            .field("user_id", .uuid, .required)
            .field("filename", .string, .required)
            .field("content_type", .string, .required)
            .field("total_size", .int64, .required)
            .field("max_chunk_size", .int64, .required)
            .field("parent_id", .uuid)
            .field("last_modified", .int64)
            .field("total_parts", .int, .required)
            .field("completed_parts", .json, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(MultipartUploadSession.schema).delete()
    }
}
