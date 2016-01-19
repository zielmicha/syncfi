import syncfi/blobstore, syncfi/blocks, syncfi/schema
import os, collections/iterate, future

proc storeFile(storeDef: StoreDef, path: string): BlockRef =
  echo "store ", path
  let blk: blobstore.Block = (hashes: @[], data: readFile(path))
  storeDef.storeBlock(blk)

proc storeDir(storeDef: StoreDef, path: string): BlockRef =
  let c = newBlockConstructor()
  c.blk.kind = BlockKind.directory
  c.blk.directory = Directory(entries: @[])

  let l1: Iterator[string] = iteratorToSeq(walkDir(path)).map(x => x.path)
  let listing = l1.sorted.toSeq

  for child in listing:
    let name = child.splitPath.tail
    let entry = DirectoryEntry(name: name, acl: -1, )
    let info = getFileInfo(path / name, followSymlink=false)

    case info.kind:
    of pcFile:
      entry.`type` = FileType.regular
      entry.body = c.addChild(storeDef.storeFile(path / name))
    of {pcLinkToFile, pcLinkToDir}:
      entry.`type` = FileType.link
    of pcDir:
      entry.`type` = FileType.directory
      entry.body = c.addChild(storeDef.storeDir(path / name))

    c.blk.directory.entries.add entry

  storeDef.storeBlock(c.make)

when isMainModule:
  let storeDef = StoreDef(path: paramStr(1))
  let directory = paramStr(2)

  let r = storeDef.storeDir(directory)
  echo "stored directory: ", r.inner, " ", r.outer
