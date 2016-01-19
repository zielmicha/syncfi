import syncfi/blobstore, syncfi/schema, capnp, tables

type
  BlockConstructor = ref object
    blk*: schema.Block
    children: Table[BlockRef, int32]
    outerHashes: seq[BlockHash]

proc make*(c: BlockConstructor): blobstore.Block =
  return (hashes: c.outerHashes, data: packStruct(c.blk))

proc addChild*(c: BlockConstructor, r: BlockRef): int32 =
  if r in c.children:
    return c.children[r]
  else:
    c.blk.innerHashes.add r.inner.toBinaryString
    c.outerHashes.add r.outer
    return (c.blk.innerHashes.len - 1).int32

proc newBlockConstructor*(): BlockConstructor =
  new(result)
  new(result.blk)
  result.blk.innerHashes = @[]
  result.children = initTable[BlockRef, int32]()
  result.outerHashes = @[]
