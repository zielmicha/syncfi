import reactor/async
import syncfi/blobstore, syncfi/schema, capnp, tables

type
  BlockConstructor* = ref object
    storeDef*: StoreDef
    blk*: schema.Block
    children: Table[BlockRef, int32]
    outerHashes: seq[BlockHash]

proc make*(c: BlockConstructor): blobstore.Block =
  return (hashes: c.outerHashes, data: packStruct(c.blk))

proc storeBlock*(c: BlockConstructor): Future[BlockRef] =
  c.storeDef.storeBlock(c.make)

proc addChild*(c: BlockConstructor, r: BlockRef): int32 =
  if r in c.children:
    return c.children[r]
  else:
    c.blk.innerHashes.add r.inner.toBinaryString
    c.outerHashes.add r.outer
    let id = (c.blk.innerHashes.len).int32
    c.children[r] = id
    return id

proc newBlockConstructor*(storeDef: StoreDef): BlockConstructor =
  new(result)
  new(result.blk)
  result.storeDef = storeDef
  result.blk.innerHashes = @[]
  result.children = initTable[BlockRef, int32]()
  result.outerHashes = @[]
