import reactor/async, reactor/util
import syncfi/blobstore, collections/iface
import future, strutils, os, commonnim, options

type FileBlobstore* = ref object
  path: string

proc labelPath(store: FileBlobstore, name: string): string =
  if '/' in name or '\\' in name:
    raise newException(Exception, "bad label name $1" % name)
  return store.path / "labels" / name

proc putLabel*(store: FileBlobstore, name: string, label: Label): Future[void] =
  var data = ""
  data &= encodeHex(label.outer.toBinaryString)
  data &= "\n"
  if label.inner.isSome:
    data &= encodeHex(label.inner.get.toBinaryString)
    data &= "\n"

  # TODO: rename, fsync
  writeFile(store.labelPath(name), data)

  return immediateFuture()

proc getLabel*(store: FileBlobstore, name: string): Future[Label] =
  let data = readFile(store.labelPath(name))
  let spl = data.split('\L')
  if spl.len == 0:
    raise newException(Exception, "invalid label")

  let outer = spl[0].decodeHex.byteArray(BlockHashBytes)
  var inner: Option[BlockHash]
  if spl.len >= 2 and spl[1].len != 0:
    inner = some(spl[1].decodeHex.byteArray(BlockHashBytes))

  return immediateFuture[tuple[outer: BlockHash, inner: Option[BlockHash]]]((outer, inner))

proc storeBlob*(store: FileBlobstore, data: string): Future[BlockHash] =
  let hash = blockHash(data)
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex

  if fileExists(path):
    return immediateFuture(hash)

  let tmpPath = store.path / (".tmp" & hexUrandom(8))
  writeFile(tmpPath, data)
  moveFile(tmpPath, path)
  return immediateFuture(hash)

proc loadBlob*(store: FileBlobstore, hash: BlockHash): Future[string] =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  let data = readFile(path)
  if blockHash(data) != hash:
    raise newException(Exception, "corrupted blob " & hashHex)
  return immediateFuture(data)

proc hasBlob*(store: FileBlobstore, hash: BlockHash): Future[bool] =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  return immediateFuture(fileExists(path))

proc hasTree*(store: FileBlobstore, hash: BlockHash): Future[bool] {.async.} =
  let hashHex = hash.toBinaryString.encodeHex
  let markPath = store.path / "blobs" / (hashHex & ".hastree")

  if fileExists(markPath): asyncReturn true

  if not (await store.hasBlob(hash)):
    asyncReturn false

  # TODO: read header only?
  let children = parseBlock(await store.loadBlob(hash), none(BlockHash)).hashes
  for child in children:
    if not (await store.hasTree(child)):
      asyncReturn false

  writeFile(markPath, "")
  asyncReturn true

#FileBlobstore.implements Blobstore

proc newFileBlobstore*(path: string): IBlobstore =
  return FileBlobstore(path: path).asIBlobstore
