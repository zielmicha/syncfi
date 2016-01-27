import syncfi/blobstore, syncfi/rpc, syncfi/blobstore, syncfi/schema
import conf/ast, conf/defs, conf/parse, conf/exceptions
import os, reactor/loop, reactor/async, reactor/tcp, strutils

type
  Server = ref object
    storeDef: StoreDef

  ClientInfo = object

proc handleClient(server: Server, client: TcpConnection) {.async.} =
  let messagePipe = rpc.makeMessagePipe(client)
  echo "client connected"

  let clientInfo = ClientInfo()

  proc getBlock(msg: Message) {.async.} =
    let hash = msg.getBlock_hash.byteArray(BlockHashBytes)
    let data = server.storeDef.loadBlob(hash)
    echo "responding to ", hash
    await messagePipe.output.provide(Message(kind: MessageKind.putBlock, putBlock_hash: hash.toBinaryString, data: data))

  proc listDirectory(msg: Message) {.async.} =
    nil

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
  server.storeDef = StoreDef(path: paramStr(1))

  let tcpServer = await createTcpServer(paramStr(2).parseInt)

  discard await tcpServer.incomingConnections.forEach(proc(x: TcpConnection) = server.handleClient(x).ignore())

when isMainModule:
  let mainCommands = SuiteDef(commands: @[])
  main().runLoop()
