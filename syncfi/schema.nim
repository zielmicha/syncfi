import capnp/util, capnp/unpack, capnp/pack, capnp/gensupport
type
  Link* = ref object
    target*: string

  Directory* = ref object
    entries*: seq[DirectoryEntry]

  BlobIndex* = ref object
    entries*: seq[BlobIndex_Entry]

  BlobIndex_Entry* = ref object
    offset*: uint64
    length*: uint64
    body*: int32
    isIndex*: uint8

  FileType* {.pure.} = enum
    directory = 0, link = 1, regular = 2

  DirectoryEntry* = ref object
    acl*: int32
    name*: string
    executable*: uint8
    `type`*: FileType
    mtime*: uint64
    body*: int32
    attributes*: int32

  MessageKind* {.pure.} = enum
    getBlock = 0, putBlock = 1, listDirectory = 2, directoryListing = 3

  Message* = ref object
    case kind*: MessageKind:
    of MessageKind.getBlock:
      getBlock_hash*: string
    of MessageKind.putBlock:
      putBlock_hash*: string
      data*: string
    of MessageKind.listDirectory:
      listDirectory_path*: string
    of MessageKind.directoryListing:
      directoryListing_path*: string
      outerHash*: string
      childrenOuterHashes*: string
      directory*: Block

  BlockKind* {.pure.} = enum
    directory = 0, link = 1, blobIndex = 2

  Block* = ref object
    innerHashes*: seq[string]
    case kind*: BlockKind:
    of BlockKind.directory:
      directory*: Directory
    of BlockKind.link:
      link*: Link
    of BlockKind.blobIndex:
      blobIndex*: BlobIndex



makeStructCoders(Link, [], [
  (target, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Directory, [], [
  (entries, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(BlobIndex, [], [
  (entries, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(BlobIndex_Entry, [
  (offset, 0, 0, true),
  (length, 8, 0, true),
  (body, 16, 0, true),
  (isIndex, 20, 0, true)
  ], [], [])

makeStructCoders(DirectoryEntry, [
  (acl, 0, 0, true),
  (executable, 4, 0, true),
  (`type`, 6, FileType(0), true),
  (mtime, 8, 0, true),
  (body, 16, 0, true),
  (attributes, 20, 0, true)
  ], [
  (name, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Message, [
  (kind, 0, low(MessageKind), true)
  ], [
  (getBlock_hash, 0, PointerFlag.none, MessageKind.getBlock),
  (putBlock_hash, 0, PointerFlag.none, MessageKind.putBlock),
  (data, 1, PointerFlag.none, MessageKind.putBlock),
  (listDirectory_path, 0, PointerFlag.text, MessageKind.listDirectory),
  (directoryListing_path, 0, PointerFlag.text, MessageKind.directoryListing),
  (outerHash, 1, PointerFlag.none, MessageKind.directoryListing),
  (childrenOuterHashes, 2, PointerFlag.none, MessageKind.directoryListing),
  (directory, 3, PointerFlag.none, MessageKind.directoryListing)
  ], [])

makeStructCoders(Block, [
  (kind, 0, low(BlockKind), true)
  ], [
  (innerHashes, 0, PointerFlag.none, true),
  (directory, 1, PointerFlag.none, BlockKind.directory),
  (link, 1, PointerFlag.none, BlockKind.link),
  (blobIndex, 1, PointerFlag.none, BlockKind.blobIndex)
  ], [])


