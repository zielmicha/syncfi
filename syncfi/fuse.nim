import reactor/async, reactor/tcp, reactorfuse/raw, collections, tables, posix, os
import syncfi/blobstore, syncfi/rpc, syncfi/schema, syncfi/errors, syncfi/fuse_misc, syncfi/client

type
  Fs = ref object of Client
    fuseConn: FuseConnection

    rootPath: string
    rootParentPath: string
    rootName: string

    nodeIdCounter: uint64
    handleCounter: uint64

    nodes: Table[NodeId, tuple[parent: WatchedNode, node: WatchedNode]]
    watchedDirs: Table[string, WatchedNode]

    handles: Table[uint64, Handle]

  WatchedNode = ref object
    entryMessage: Message
    entry: DirectoryEntry

    case isDir: bool
    of true:
      path: string
      children: Table[string, WatchedNode]
      dirBody: Message
    of false:
      discard

  Handle = ref object
    nodeId: uint64

    case isDir: bool
    of true:
      data: string
    of false:
      discard

proc processNewListing(node: WatchedNode) =
  let bodyBlock = node.dirBody.directory
  if bodyBlock == nil or bodyBlock.directory == nil or bodyBlock.directory.entries == nil:
    node.dirBody = nil
    return

  # TODO: handle removed entries
  for entry in bodyBlock.directory.entries:
    if entry.name in node.children:
      let child = node.children[entry.name]
      child.entry = entry
      child.entryMessage = node.dirBody

proc listDirInfo(fs: Fs, node: WatchedNode) {.async.} =
  let resp = await fs.remoteCall(Message(kind: MessageKind.listDirectory, path: node.path))
  await checkType(resp, {MessageKind.directoryListing})
  node.dirBody = resp
  node.processNewListing()

proc initRoot(fs: Fs) {.async.} =
  (fs.rootParentPath, fs.rootName) = fs.rootPath.splitDirPath
  let rootNode = WatchedNode(isDir: true, path: fs.rootPath)
  let rootParentNode = WatchedNode(isDir: true, path: fs.rootParentPath)
  initTable(rootParentNode.children)
  initTable(rootNode.children)
  rootParentNode.children[fs.rootName] = rootNode
  fs.nodes[0] = (nil, rootParentNode)
  fs.nodes[1] = (rootParentNode, rootNode)

  await fs.listDirInfo(rootParentNode)

proc getNode(fs: Fs, req: Request): Future[WatchedNode] {.async.} =
  if req.nodeId notin fs.nodes:
    asyncRaise newFilesystemError(ESTALE, "stale file handle")
  asyncReturn fs.nodes[req.nodeId].node

proc getHandle(fs: Fs, req: Request): Future[Handle] {.async.} =
  if req.fileHandle notin fs.handles:
    asyncRaise newFilesystemError(ESTALE, "stale file handle")
  asyncReturn fs.handles[req.fileHandle]

proc getAttr(fs: Fs, req: Request) {.async.} =
  let node = await fs.getNode(req)

  if node.entry == nil:
    await fs.fuseConn.respondError(req, ESTALE)
  else:
    await fs.fuseConn.respondToGetAttr(req, makeAttributes(node.entry, inode=req.nodeId))

proc typeToDt(`type`: FileType): DirEntryKind =
  case `type`:
  of FileType.regular: return dtFile
  of FileType.link: return dtLink
  of FileType.directory: return dtDir
  else: return dtUnknown

proc openDir(fs: Fs, req: Request) {.async.} =
  let node = await fs.getNode(req)

  if not node.isDir:
    await fs.fuseConn.respondError(req, EISDIR)
    asyncReturn

  var dirData = ""

  if node.dirBody == nil:
    await fs.listDirInfo(node)
    if node.dirBody == nil:
      await fs.fuseConn.respondError(req, errors.EIO)
      asyncReturn

  for i, entry in node.dirBody.directory.directory.entries:
    dirData.appendDirent(kind=typeToDt(entry.`type`), inode=uint64(1 + i), name=entry.name)

  let handleId = fs.handleCounter
  fs.handleCounter += 1
  fs.handles[handleId] = Handle(nodeId: req.nodeId, isDir: true, data: dirData)

  await fs.fuseConn.respondToOpen(req, handleId)

proc readDir(fs: Fs, req: Request) {.async.} =
  let handle = await fs.getHandle(req)

  if not handle.isDir:
    await fs.fuseConn.respondError(req, EISDIR)
    asyncReturn

  await fs.fuseConn.respondToReadAll(req, handle.data)

proc handleFuseRequest(fs: Fs, req: Request) {.async.} =
  if req.kind == fuseGetAttr:
    await fs.getAttr(req)
  elif req.kind == fuseOpen:
    if req.isDir:
      await fs.openDir(req)
    else:
      await fs.fuseConn.respondError(req, ENOSYS)
  elif req.kind == fuseRead:
    if req.isDir:
      await fs.readDir(req)
    else:
      await fs.fuseConn.respondError(req, ENOSYS)
  elif req.kind == fuseLookup:
    await fs.fuseConn.respondError(req, ENOSYS)
  elif req.kind == fuseForget:
    discard
  else:
    await fs.fuseConn.respondError(req, ENOSYS)

proc serve(fs: Fs) {.async.} =
  proc handleReq(req: Request) =
    fs.handleFuseRequest(req).onError(proc(err: ref Exception) =
                           if err of FilesystemError:
                             fs.fuseConn.respondError(req, (ref FilesystemError)(err).errorno).ignore()
                           else:
                             stderr.writeLine "Error in fs call: ", err.msg
                             fs.fuseConn.respondError(req, EFAULT).ignore())

  fs.serverConn.input.forEach(proc(msg: Message) =
    if msg.responseTo != 0:
      fs.serverResponses.complete(msg.responseTo, msg)).ignore()

  await fs.initRoot
  echo "filesystem ready"

  asyncFor req in fs.fuseConn.requests:
    # TODO: limit maximum concurrency?
    handleReq(req)

proc newFs(): Fs =
  let fs = Fs()
  initClient(fs)
  fs.nodeIdCounter = 2
  fs.handleCounter = 2
  initTable(fs.nodes)
  initTable(fs.watchedDirs)
  initTable(fs.handles)
  return fs

proc main(connectAddr: string, mountPath: string, rootPath: string) {.async.} =
  let fs = newFs()
  fs.rootPath = rootPath
  fs.serverConn = (await connectTcp(connectAddr)).makeMessagePipe
  fs.fuseConn = await mount(mountPath, ())
  echo "filesystem mounted"
  await fs.serve

when isMainModule:
  main(connectAddr=paramStr(1), rootPath=paramStr(2), mountPath=paramStr(3)).runLoop()
