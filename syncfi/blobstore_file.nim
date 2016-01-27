import reactor/async, reactor/util
import syncfi/blobstore
import future, strutils, os, commonnim, options

type FileStoreDef* = ref object of StoreDef
  path: string

proc labelPath(store: FileStoreDef, name: string): string =
  if '/' in name or '\\' in name:
    raise newException(Exception, "bad label name $1" % name)
  return store.path / "labels" / name

proc putLabel*(store: FileStoreDef, name: string, label: Label): Future[void] =
  var data = ""
  data &= encodeHex(label.outer.toBinaryString)
  data &= "\n"
  if label.inner.isSome:
    data &= encodeHex(label.inner.get.toBinaryString)
    data &= "\n"

  # TODO: rename, fsync
  writeFile(store.labelPath(name), data)

  return immediateFuture()

proc getLabel*(store: FileStoreDef, name: string): Future[Label] =
  let data = readFile(store.labelPath(name))
  let spl = data.split('\L')
  if spl.len == 0:
    raise newException(Exception, "invalid label")

  let outer = spl[0].decodeHex.byteArray(BlockHashBytes)
  var inner: Option[BlockHash]
  if spl.len >= 2 and spl[1].len != 0:
    inner = some(spl[1].decodeHex.byteArray(BlockHashBytes))

  return immediateFuture[tuple[outer: BlockHash, inner: Option[BlockHash]]]((outer, inner))

proc storeBlob*(store: FileStoreDef, data: string): Future[BlockHash] =
  let hash = sha256d(data)
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  # TODO: if not exists
  writeFile(path, data)
  return immediateFuture(hash)

proc loadBlob*(store: FileStoreDef, hash: BlockHash): Future[string] =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  let data = readFile(path)
  if sha256d(data) != hash:
    raise newException(Exception, "corrupted blob " & hashHex)
  return immediateFuture(data)

proc hasBlob*(store: FileStoreDef, hash: BlockHash): Future[bool] =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  if not fileExists(path):
    return immediateFuture(false)
  let data = readFile(path)
  if sha256d(data) != hash:
    return immediateFuture(false)
  return immediateFuture(true)

proc newFileBlobstore*(path: string): FileStoreDef =
  let self = FileStoreDef(
    path: path)
  self.putLabel = (name: string, label: Label) => putLabel(self, name, label)
  self.getLabel = (name: string) => getLabel(self, name)
  self.storeBlob = (data: string) => storeBlob(self, data)
  self.loadBlob = (hash: BlockHash) => loadBlob(self, hash)
  self.hasBlob = (hash: BlockHash) => hasBlob(self, hash)
  return self
