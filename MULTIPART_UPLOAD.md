# Large File Uploads (Multipart)

This guide covers how FynnCloud handles large file uploads via a multipart strategy.

## Core Logic

Standard `POST` requests are brittle for large files. If the connection drops at 99%, the user has to start over. Furthermore, buffering gigabyte-scale files into memory is a recipe for server crashes.

Multipart uploads solve this by breaking files into smaller, independent chunks. This allows for:

* **Resilience:** Only failed chunks need to be re-sent.
* **Efficiency:** We stream data directly to storage rather than holding it in RAM.
* **Speed:** Clients can push multiple chunks in parallel.

---

## The Workflow

### 1. Initialization

The client kicks things off by telling the server what’s coming.

**Endpoint:** `POST /api/files/multipart/initiate`

The request includes the filename, size, and metadata. The server returns a `sessionID` and a **JWT token**.

> **Note on the Token:** This JWT is the "source of truth" for the session. It encodes the `fileID`, `uploadID`, and `userID`, expiring after 24 hours. We keep a minimal DB record of the session for audit trails, but the token handles the heavy lifting.

### 2. Pushing Chunks

The client uploads chunks individually.

**Endpoint:** `PUT /api/files/multipart/:sessionID/part/:partNumber`

* **Auth:** Include the JWT as a Bearer token.
* **Body:** Raw binary data (default max: 10MB).

**Server Behavior:** To keep things fast, the server streams the data directly to the storage provider with **zero database overhead**. The server returns an `etag`, which the client must store to finalize the upload later.

### 3. Finalizing (Completion)

Once every chunk is uploaded, the client sends a "manifest" of all parts.

**Endpoint:** `POST /api/files/multipart/:sessionID/complete`

The server runs a final validation check:

* Ensures no chunks are missing (sequential check).
* Verifies `etags` against the storage provider.
* Confirms the `fileID` is unique to prevent token reuse.

If everything looks good, the file is registered in the database, and the session record is purged.

### 4. Aborting

If a user cancels, hit `DELETE /api/files/multipart/:sessionID/abort`. This triggers an immediate cleanup of temporary storage and restores the user's quota.

---

## Security & Maintenance

* **Integrity:** Because the session metadata is signed within the JWT, clients can't spoof file sizes or IDs mid-stream.
* **Cleanup:** We find abandoned uploads by querying the database for expired session records and purging the associated temp files.
* **Single-use Tokens:** The server checks for existing `fileIDs` during the completion phase, effectively making each upload token a one-time-use credential.

---

## Storage Implementation Details

### Local Filesystem

Chunks live in `{storage}/_chunks/{fileID}/{uploadID}/part_{N}`. Upon completion, we concatenate these into the final destination and wipe the temp directory.

### S3 / Object Storage

We leverage the native S3 Multipart API. The `uploadID` we provide is the actual S3 ID. S3 handles the heavy lifting of assembling the chunks into a single object on completion.

### Concurrency

Clients should upload chunks in parallel to maximize throughput. Each file upload is isolated by its own session and JWT, so multiple file uploads can occur simultaneously without collision.

### Recovery

If the server bounces mid-upload, it doesn't matter. Since the session state is in the DB and the metadata is in the JWT, the client can pick up right where it left off as long as the 24-hour window hasn't closed.
