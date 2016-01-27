import capnp/util, capnp/unpack, capnp/pack, capnp/gensupport
type
  Link* = ref object
    target*: string

  AclEntry_Kind* {.pure.} = enum
    allow = 0, deny = 1

  Directory* = ref object
    entries*: seq[DirectoryEntry]

  Principal* = ref object
    chain*: seq[PrincipalSubId]

  BlobIndex* = ref object
    entries*: seq[BlobIndex_Entry]

  Acl* = ref object
    access*: seq[AclEntry]
    inherit*: seq[AclEntry]
    mininherit*: seq[AclEntry]
    owner*: Principal
    posixCompat*: PosixCompat

  BlobIndex_Entry* = ref object
    offset*: uint64
    length*: uint64
    body*: int32

  FileType* {.pure.} = enum
    directory = 0, link = 1, regular = 2

  DirectoryEntry* = ref object
    acl*: int32
    name*: string
    executable*: bool
    `type`*: FileType
    mtime*: uint64
    body*: int32
    attributes*: int32

  PrincipalSubIdKind* {.pure.} = enum
    random = 0, unixGroup = 1, unixUser = 2

  PrincipalSubId* = ref object
    case kind*: PrincipalSubIdKind:
    of PrincipalSubIdKind.random:
      random*: uint64
    of PrincipalSubIdKind.unixGroup:
      unixGroup*: uint32
    of PrincipalSubIdKind.unixUser:
      unixUser*: uint32

  AclEntry* = ref object
    actions*: seq[AclEntry_Action]
    kind*: AclEntry_Kind
    principal*: Principal
    anyone*: bool

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

  PosixCompat* = ref object
    groupOwner*: Principal
    inheritGroup*: bool
    setGid*: bool
    setUid*: bool

  BlockKind* {.pure.} = enum
    directory = 0, link = 1, blobIndex = 2, blob = 3, acl = 4

  Block* = ref object
    innerHashes*: seq[string]
    case kind*: BlockKind:
    of BlockKind.directory:
      directory*: Directory
    of BlockKind.link:
      link*: Link
    of BlockKind.blobIndex:
      blobIndex*: BlobIndex
    of BlockKind.blob:
      blob*: string
    of BlockKind.acl:
      acl*: Acl

  AclEntry_Action* {.pure.} = enum
    readData = 0, writeData = 1, listDirectory = 2, addFile = 3, addSubdirectory = 4, execute = 5, enterDirectory = 6, deleteChild = 7, allowDeleteChild = 8, delete = 9, writeOwner = 10, writeAcl = 11



makeStructCoders(Link, [], [
  (target, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Directory, [], [
  (entries, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Principal, [], [
  (chain, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(BlobIndex, [], [
  (entries, 0, PointerFlag.none, true)
  ], [])

makeStructCoders(Acl, [], [
  (access, 0, PointerFlag.none, true),
  (inherit, 1, PointerFlag.none, true),
  (mininherit, 2, PointerFlag.none, true),
  (owner, 3, PointerFlag.none, true),
  (posixCompat, 4, PointerFlag.none, true)
  ], [])

makeStructCoders(BlobIndex_Entry, [
  (offset, 0, 0, true),
  (length, 8, 0, true),
  (body, 16, 0, true)
  ], [], [])

makeStructCoders(DirectoryEntry, [
  (acl, 0, 0, true),
  (`type`, 6, FileType(0), true),
  (mtime, 8, 0, true),
  (body, 16, 0, true),
  (attributes, 20, 0, true)
  ], [
  (name, 0, PointerFlag.text, true)
  ], [
  (executable, 32, false, true)
  ])

makeStructCoders(PrincipalSubId, [
  (kind, 8, low(PrincipalSubIdKind), true),
  (random, 0, 0, PrincipalSubIdKind.random),
  (unixGroup, 0, 0, PrincipalSubIdKind.unixGroup),
  (unixUser, 0, 0, PrincipalSubIdKind.unixUser)
  ], [], [])

makeStructCoders(AclEntry, [
  (kind, 0, AclEntry_Kind(0), true)
  ], [
  (actions, 0, PointerFlag.none, true),
  (principal, 1, PointerFlag.none, true)
  ], [
  (anyone, 16, false, true)
  ])

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

makeStructCoders(PosixCompat, [], [
  (groupOwner, 0, PointerFlag.none, true)
  ], [
  (inheritGroup, 0, false, true),
  (setGid, 1, false, true),
  (setUid, 2, false, true)
  ])

makeStructCoders(Block, [
  (kind, 0, low(BlockKind), true)
  ], [
  (innerHashes, 0, PointerFlag.none, true),
  (directory, 1, PointerFlag.none, BlockKind.directory),
  (link, 1, PointerFlag.none, BlockKind.link),
  (blobIndex, 1, PointerFlag.none, BlockKind.blobIndex),
  (blob, 1, PointerFlag.none, BlockKind.blob),
  (acl, 1, PointerFlag.none, BlockKind.acl)
  ], [])


