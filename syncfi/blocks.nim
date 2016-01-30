import reactor/async, capnp, tables, options
import syncfi/blobstore, syncfi/schema

type
  BlockConstructor* = ref object
    storeDef*: StoreDef
    blk*: schema.Block
    children: Table[BlockRef, uint32]
    outerHashes: seq[BlockHash]

proc make*(c: BlockConstructor): blobstore.Block =
  return (hashes: c.outerHashes, data: packStruct(c.blk))

proc storeBlock*(c: BlockConstructor): Future[BlockRef] =
  c.storeDef.storeBlock(c.make)

proc addChild*(c: BlockConstructor, r: BlockRef): uint32 =
  if r in c.children:
    return c.children[r]
  else:
    c.blk.innerHashes.add r.inner.toBinaryString
    c.outerHashes.add r.outer
    let id = (c.blk.innerHashes.len).uint32
    c.children[r] = id
    return id

proc newBlockConstructor*(storeDef: StoreDef): BlockConstructor =
  new(result)
  new(result.blk)
  result.storeDef = storeDef
  result.blk.innerHashes = @[]
  result.children = initTable[BlockRef, uint32]()
  result.outerHashes = @[]

proc loadSerializedBlock*(storeDef: StoreDef, blockRef: BlockRef): Future[tuple[blk: blobstore.Block, schemablk: schema.Block]] {.async.} =
  let blk = await storeDef.loadBlock(blockRef)
  let schemablk = newUnpackerFlat(blk.data).unpackStruct(0, schema.Block)
  asyncReturn ((blk, schemablk))

proc getRef*(blk: blobstore.Block, schemablk: schema.Block, i: uint32): Option[BlockRef] =
  # Retrieve reference from deserialized block.
  if i == 0 or i > uint32(1024 * 1024):
    return none(BlockRef)
  let index = (i - 1).int

  if index >= blk.hashes.len or index >= schemablk.innerHashes.len:
    return none(BlockRef)
  let outer = blk.hashes[index]
  let innerString = schemablk.innerHashes[index]
  if innerString == nil or innerString.len != BlockHashBytes:
    return none(BlockRef)

  return some((inner: byteArray(innerString, BlockHashBytes), outer: outer))
