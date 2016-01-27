import sodium/sha2, sodium/common, sodium/chacha20
import endians, options, os, strutils, sequtils, future
import commonnim, reactor/util, reactor/async, snappy

export sha256d, byteArray, toBinaryString

type
  Block* = tuple[hashes: seq[Sha256Hash], data: string]

  BlockHash* = Sha256Hash

  BlockRef* = tuple[inner: BlockHash, outer: BlockHash]

  StoreDef* = ref object of RootObj
    putLabel*: (proc(name: string, label: Label): Future[void])
    getLabel*: (proc(name: string): Future[Label])
    storeBlob*: (proc(data: string): Future[BlockHash])
    loadBlob*: (proc(hash: BlockHash): Future[string])
    hasBlob*: (proc(hash: BlockHash): Future[bool])

  Label* = tuple[outer: BlockHash, inner: Option[BlockHash]]

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

proc putLabel*(store: StoreDef, name: string, outer: BlockHash, inner: Option[BlockHash]=none(BlockHash)): Future[void] =
  store.putLabel(name, (outer, inner))

proc storeBlock*(store: StoreDef, `block`: Block): Future[BlockRef] =
  let (inner, data) = makeBlock(`block`)
  store.storeBlob(data).then proc(outerHash: BlockHash): BlockRef =
    result.inner = inner
    result.outer = outerHash

proc loadBlock*(store: StoreDef, reference: BlockRef): Future[Block] =
  store.loadBlob(reference.outer).then(data => parseBlock(data, some(reference.inner)))

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
