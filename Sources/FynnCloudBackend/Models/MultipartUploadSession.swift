import Fluent
import Vapor

// Database model to track multipart upload sessions
// This stores ALL metadata during upload - we only create FileMetadata on completion
final class MultipartUploadSession: Model, Content, @unchecked Sendable {
    static let schema = "multipart_upload_sessions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "file_id")
    var fileID: UUID

    @Field(key: "upload_id")
    var uploadID: String

    @Field(key: "user_id")
    var userID: UUID

    // Store file metadata here during upload
    @Field(key: "filename")
    var filename: String

    @Field(key: "content_type")
    var contentType: String

    @Field(key: "total_size")
    var totalSize: Int64

    @Field(key: "max_chunk_size")
    var maxChunkSize: Int64

    @OptionalField(key: "parent_id")
    var parentID: UUID?

    @OptionalField(key: "last_modified")
    var lastModified: Int64?

    @Field(key: "total_parts")
    var totalParts: Int

    @Field(key: "completed_parts")
    var completedParts: [CompletedPart]  // Now includes actual sizes

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        fileID: UUID,
        uploadID: String,
        userID: UUID,
        filename: String,
        contentType: String,
        totalSize: Int64,
        maxChunkSize: Int64,
        parentID: UUID? = nil,
        lastModified: Int64? = nil,
        totalParts: Int,
        completedParts: [CompletedPart] = []
    ) {
        self.id = id
        self.fileID = fileID
        self.uploadID = uploadID
        self.userID = userID
        self.filename = filename
        self.contentType = contentType
        self.totalSize = totalSize
        self.maxChunkSize = maxChunkSize
        self.parentID = parentID
        self.lastModified = lastModified
        self.totalParts = totalParts
        self.completedParts = completedParts
    }

    // Computed property: get actual uploaded size from completed parts
    var actualUploadedSize: Int64 {
        completedParts.reduce(0) { $0 + $1.size }
    }
}
