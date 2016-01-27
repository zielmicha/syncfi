import reactor/async, reactor/loop
import syncfi/blobstore, syncfi/blobstore_file, syncfi/blocks, syncfi/misc, syncfi/schema, syncfi/mapacl
import os, collections/iterate, future, options, posix

proc storeFileContent(storeDef: StoreDef, path: string): Future[BlockRef] =
  echo "store ", path
  let c = storeDef.newBlockConstructor()
  c.blk.kind = BlockKind.blob
  c.blk.blob = readFile(path)

  return storeDef.storeBlock(c.make)

proc storeDir(storeDef: StoreDef, path: string): Future[BlockRef] {.async.} =
  let c = newBlockConstructor(storeDef)
  c.blk.kind = BlockKind.directory
  c.blk.directory = Directory(entries: @[])

  let l1: Iterator[string] = iteratorToSeq(walkDir(path)).map(x => x.path)
  let listing = l1.sorted.toSeq

  for child in listing:
    let name = child.splitPath.tail
    let entry = DirectoryEntry(name: name)

    var stat: Stat
    if lstat(child, stat) < 0:
      raiseOSError(osLastError())

    let (acl, executable) = makeAcl(mode=stat.st_mode.int,
                                    owner=stat.st_uid.uint32,
                                    group=stat.st_gid.uint32)
    entry.acl = await c.storeAcl(acl)
    entry.executable = executable

    entry.mtime = stat.st_mtime.uint64 * 1000

    let fileType = stat.st_mode and 0o170000

    if fileType == S_IFREG:
      entry.`type` = FileType.regular
      entry.body = c.addChild(await storeDef.storeFileContent(child))
    elif fileType == S_IFDIR:
      entry.`type` = FileType.directory
      entry.body = c.addChild(await storeDef.storeDir(child))
    else:
      echo "unknown file type ", child
      continue

    c.blk.directory.entries.add entry

  asyncReturn (await c.storeBlock)

proc main() {.async.} =
  let storeDef = newFileBlobstore(paramStr(1))
  let directory = paramStr(2)

  let r = await storeDef.storeDir(directory)
  echo "stored file: ", r.inner, " ", r.outer
  await storeDef.putLabel("storedir", (r.outer, r.inner.some))

when isMainModule:
  main().runLoop()
