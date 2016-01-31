import syncfi/blobstore, syncfi/blocks, syncfi/schema
import os, collections/iterate, future

proc unpackFile(storeDef: StoreDef, path: string, r: BlockRef): BlockRef =
  let (innerHashes, data) = storeDef.loadBlock(r)
  writeFile(path, data)

proc unpackDir(storeDef: StoreDef, outputhDir: string, r: BlockRef): BlockRef =
  let (innerHashes, data) = storeDef.loadBlock(r)
  let

when isMainModule:
  let storeDef = StoreDef(path: paramStr(1))
  let outdir = paramStr(1)
  let inner = paramStr(3)
  let outer = paramStr(4)

  storeDef.storeDir(directory, outdir, (inner: inner, outer: outer))
