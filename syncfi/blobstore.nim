import sodium/sha2, sodium/common, sodium/chacha20
import endians, options, os, strutils, sequtils, future
import commonnim, reactor/util, snappy

export sha256d, byteArray, toBinaryString

type
  Block* = tuple[hashes: seq[Sha256Hash], data: string]

  BlockHash* = Sha256Hash

  BlockRef* = tuple[inner: BlockHash, outer: BlockHash]

  StoreDef* = object
    path*: string

const BlockHashBytes* = 32

proc makeBlock*(hashes: seq[BlockHash], data: string): tuple[inner: BlockHash, data: string] =
  result.inner = sha256d(data)
  result.data = pack(hashes.len.uint32)

  for hash in hashes:
    result.data &= hash.toBinaryString

  result.data &= chaCha20Xor(byteArray(toBinaryString(result.inner)[0..31], 32),
                             byteArray("\0\0\0\0\0\0\0\0", 8), snappy.compress(data))

proc makeBlock*(`block`: Block): auto =
  makeBlock(`block`.hashes, `block`.data)

proc parseBlock*(data: string, inner: Option[BlockHash]): Block =
  if data.len < 4:
    raise newException(ValueError, "truncated packet")

  let hashCount: uint32 = unpack(data[0..3], uint32)

  if hashCount > 1000000.uint32:
    raise newException(ValueError, "number of hashes is unreasonably big")

  if data.len < hashCount.int * sha256Bytes + 4:
    raise newException(ValueError, "truncated packet")

  result.hashes = @[]
  for i in 0..<(hashCount.int):
    let offset = 4 + sha256Bytes * i
    result.hashes.add(byteArray(data[offset..<offset + sha256Bytes], sha256Bytes))

  if inner.isSome:
    let ciphertext = data[4 + sha256Bytes * hashCount.int..^(-1)]
    result.data = chaCha20Xor(byteArray(toBinaryString(inner.get)[0..31], 32),
                              byteArray("\0\0\0\0\0\0\0\0", 8), ciphertext)
    result.data = snappy.uncompress(result.data)

proc labelPath(store: StoreDef, name: string): string =
  if '/' in name or '\\' in name:
    raise newException(Exception, "bad label name $1" % name)
  return store.path / "labels" / name

proc putLabel*(store: StoreDef, name: string, outer: BlockHash, inner: Option[BlockHash]) =
  var data = ""
  data &= encodeHex(outer.toBinaryString)
  data &= "\n"
  if inner.isSome:
    data &= encodeHex(inner.get.toBinaryString)
    data &= "\n"

  # TODO: rename, fsync
  writeFile(store.labelPath(name), data)

proc getLabel*(store: StoreDef, name: string): tuple[outer: BlockHash, inner: Option[BlockHash]] =
  let data = readFile(store.labelPath(name))
  let spl = data.split('\L')
  if spl.len == 0:
    raise newException(Exception, "invalid label")

  result.outer = spl[0].decodeHex.byteArray(BlockHashBytes)
  if spl.len >= 2 and spl[1].len != 0:
    result.inner = some(spl[1].decodeHex.byteArray(BlockHashBytes))

proc storeBlob*(store: StoreDef, data: string): BlockHash =
  let hash = sha256d(data)
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  # TODO: if not exists
  writeFile(path, data)
  return hash

proc storeBlock*(store: StoreDef, `block`: Block): BlockRef =
  let (inner, data) = makeBlock(`block`)
  result.inner = inner
  result.outer = store.storeBlob(data)

proc loadBlob*(store: StoreDef, hash: BlockHash): string =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  let data = readFile(path)
  if sha256d(data) != hash:
    raise newException(Exception, "corrupted blob " & hashHex)
  return data

proc verifyBlob*(store: StoreDef, hash: BlockHash): bool =
  let hashHex = hash.toBinaryString.encodeHex
  let path = store.path / "blobs" / hashHex
  if not fileExists(path):
    return false
  let data = readFile(path)
  if sha256d(data) != hash:
    return false
  return true

proc hasBlob*(store: StoreDef, hash: BlockHash): bool =
  let hashHex = hash.toBinaryString.encodeHex
  existsFile(store.path / "blobs" / hashHex)

proc loadBlock*(store: StoreDef, reference: BlockRef): Block =
  let data = store.loadBlob(reference.outer)
  parseBlock(data, some(reference.inner))

proc `$`*(h: BlockHash): string =
  h.toBinaryString.encodeHex

proc blockHash*(h: string): BlockHash =
  h.decodeHex.byteArray(BlockHashBytes)

when isMainModule:
  var store: string = paramStr(1)
  var command: string = paramStr(2)

  let storeDef = StoreDef(path: store)

  if command == "getlabel":
    let label = paramStr(3)
    echo label, ":"
    echo storeDef.getLabel(label)
  elif command == "storeblob":
    let params = commandLineParams()
    let refs = params[2..^1].map(x => x.blockHash)
    let data = readAll(stdin)
    echo "Storing refs: ", refs
    let reference = storeDef.storeBlock((hashes: refs, data: data))
    echo "Reference:", reference
  elif command == "loadblob":
    let inner = paramStr(3).blockHash
    let outer = paramStr(4).blockHash
    let b = storeDef.loadBlock((inner: inner, outer: outer))
    stderr.writeLine("Refs: " & $b.hashes & " length " & $b.data.len)
    stdout.write(b.data)
  else:
    echo "bad command: ", command
