import reactor/async, reactorfuse/raw, collections, posix, strutils
import syncfi/blobstore, syncfi/schema, syncfi/mapacl

proc makeAttributes*(entry: DirectoryEntry, inode: uint64): Attributes =
  var mode: int = 0

  case entry.type:
  of FileType.directory:
    mode = S_IFDIR
  of FileType.regular:
    mode = S_IFREG
  of FileType.link:
    mode = S_IFLNK

  mode = mode or 0o700 # TODO: use mapacl

  Attributes(ino: inode, mode: mode.uint32)

proc splitDirPath*(path: string): tuple[head: string, tail: string] =
  var path = path.strip(chars={'/'})
  let pos = path.rfind('/')
  if pos == -1:
    raise newException(ValueError, "invalid path")

  return (path[0..<pos], path[pos+1..^1])
