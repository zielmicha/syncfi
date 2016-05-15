import reactor/async, sodium/sha2, collections, collections/iterate, capnp
import syncfi/blobstore, syncfi/blocks, syncfi/schema, syncfi/errors

proc getChild*(storeDef: StoreDef, dirRef: BlockRef, name: string): Future[BlockRef] {.async.} =
  let (blk, schemablk) = await storeDef.loadSerializedBlock(dirRef)
  if schemablk.kind != BlockKind.directory:
    asyncRaise newFilesystemError(ENOTDIR, "file not a directory")

  if schemablk.directory == nil or schemablk.directory.entries == nil:
    asyncRaise newFilesystemError(errors.EIO, "corrupted filesystem")

  let item = schemablk.directory.entries.findOne(e => e.name == name)
  if item.isNone:
    asyncRaise newFilesystemError(ENOENT, "no such file or directory")

  # TODO: verify ACL

  let reference = getRef(blk, schemablk, item.get.body).get
  #if reference.isNone:
  #  asyncRaise newFilesystemError(errors.EIO, "corrupted filesystem")

  asyncReturn reference

proc formatListing*(storeDef: StoreDef, dirRef: BlockRef): Future[Message] {.async.} =
  let (blk, schemablk) = await storeDef.loadSerializedBlock(dirRef)
  let msg = Message(kind: MessageKind.directoryListing)
  msg.outerHash = sha256d(dirRef.outer.toBinaryString).toBinaryString
  msg.childrenOuterHashes = blk.hashes.map(x => x.toBinaryString).toSeq
  msg.directory = schemablk
  asyncReturn msg
