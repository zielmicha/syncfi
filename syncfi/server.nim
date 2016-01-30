import syncfi/blobstore, syncfi/rpc, syncfi/blobstore, syncfi/schema, syncfi/server_files, syncfi/blocks, syncfi/blobstore_file
import conf/ast, conf/defs, conf/parse, conf/exceptions
import os, reactor/loop, reactor/async, reactor/tcp, strutils, options

type
  Server = ref object
    storeDef: StoreDef

  ClientInfo = object

proc makeListing(server: Server, path: string): Future[Message] {.async.} =
  let fragments = path.split("/")
  if fragments.len < 1:
    asyncReturn Message(kind: MessageKind.error)
  let fsName = fragments[0]
  let rootBlockLabel = await server.storeDef.getLabel("fs_" & fsName)
  let rootBlock: BlockRef = (inner: rootBlockLabel.inner.get, outer: rootBlockLabel.outer)
  var current = rootBlock
  for name in fragments[1..^1]:
    current = await server.storeDef.getChild(current, name)

  asyncReturn (await server.storeDef.formatListing(current))

proc handleClient(server: Server, client: TcpConnection) {.async.} =
  let messagePipe = rpc.makeMessagePipe(client)
  echo "client connected"

  let clientInfo = ClientInfo()

  proc verifyAuth(msg: Message): bool =
    return true

  proc getBlock(msg: Message) {.async.} =
    let hash = msg.getBlock_hash.byteArray(BlockHashBytes)
    let data = await server.storeDef.loadBlob(hash)
    await messagePipe.output.provide(Message(
      responseTo: msg.id,
      kind: MessageKind.putBlock,
      putBlock_hash: hash.toBinaryString,
      data: data))

  proc listDirectory(msg: Message) {.async.} =
    if not msg.verifyAuth():
      await messagePipe.output.provide(Message(kind: MessageKind.error, message: "bad auth"))
    else:
      echo "list ", msg.path
      let listing = await server.makeListing(msg.path)
      # echo "  ->", listing.repr
      listing.responseTo = msg.id
      await messagePipe.output.provide(listing)

  while true:
    let msg = await messagePipe.input.receive()

    case msg.kind:
    of MessageKind.getBlock:
      getBlock(msg).ignore()
    of MessageKind.listDirectory:
      listDirectory(msg).ignore()
    else: discard

proc main() {.async.} =
  let server = new(Server)
  server.storeDef = newFileBlobstore(path=paramStr(1))

  let port = paramStr(2).parseInt
  let tcpServer = await createTcpServer(port)

  echo "serving on port ", port
  await tcpServer.incomingConnections.forEach(proc(x: TcpConnection) = server.handleClient(x).ignore())

when isMainModule:
  let mainCommands = SuiteDef(commands: @[])
  main().runLoop()
