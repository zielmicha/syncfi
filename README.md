# syncfi

**syncfi** is a single master mostly POSIX-compatibile distributed filesystem with ability to work offline, advanced permission support and convergent encryption.

## Building

Install `libsodium-dev` or similar and run `./build.sh`. *syncfi* uses [nimenv](https://github.com/zielmicha/nimenv) to download (checksummed) Nim compiler and dependencies and build them.

## Architecture

### Storage and encryption

*syncfi* keeps all its data in encrypted containers called **blobs**. Each blob is identified by two SHA256d hashes -- the **inner hash** of unencrypted content and the **outer hash** of encrypted content together with the header. The content is encrypted using ChaCha20 with the inner hash as a key ([convergent encryption](https://en.wikipedia.org/wiki/Convergent_encryption)).

Blobs contain an unencrypted header with references to other blobs' outer hashes and the encrypted content. This way all blobs form a [Merkle tree](https://en.wikipedia.org/wiki/Merkle_tree). The header is unencrypted which ensures that it is possible to perform garbage collection or deep blob copying without knowing blob's contents. The inner hashes of blob children are stored inside encrypted content.

### ACL

*syncfi* employs ACL model inspired by [RichACL](http://www.bestbits.at/richacl/) with hierarchical principals. Hierarchical principal is a list of symbols. `()` (empty list) represents superuser which has access to everything. `(zielmicha)` is a normal user, similar to pricipal used by POSIX. `(zielmicha, postgres)` may be a user in VM spawned by `(zielmicha)` (Linux user namespaces integration is planned). In general, principal `(a, b, c)` has no more permissions that principal `(a, b)`, `(a)` and `()`.

### Network protocol

Client accesses directories by issuing `listDirectory` request to the server. The response contains inner/outer hashes of files client has access to - so the client can directly read them using `getBlob` request. Subdirectories must be queried with `listDirectory`.

Writes can be performed by issuing `write` request with a list of `WriteOp`. The `WriteOp` may create/remove directory, remove or modify file. `WriteOp` contain hash of file content before it was modified, so server can detect conflicts. Depending on settings, conflicting `WriteOp` may be discarded, force applied or saved for later inspection.

### Offline access

Client may cache some blobs in its own blobstore. Files are stored directly and directories by reconstructing them from `listDirectory` responses. Cached Merkle tree may have some nodes missing (these of file that are not cached). Pending `WriteOp`s are stored and "virtually" applied to the cache contest.

Offline access will be implemented as an auxiliary proxy filesystem.

## What works now?

* Filesystem server (read only, ACLs not implemented)
* FUSE filesystem (read only)
* Syncing blocks from remote hosts
