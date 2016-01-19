import syncfi/blobstore, syncfi/rpc, syncfi/blobstore, syncfi/schema
import os, reactor/loop, reactor/async, reactor/tcp, strutils

type Server = ref object
  storeDef: StoreDef

proc handleClient(server: Server, client: TcpConnection) {.async.} =
  let messagePipe = rpc.makeMessagePipe(client)

  echo "new client"
  while true:
    let msg = await messagePipe.input.receive()
    msg.repr.echo

    case msg.kind:
    of MessageKind.getBlock:
      let hash = msg.getBlock_hash.byteArray(BlockHashBytes)
      let data = server.storeDef.loadBlob(hash)
      echo "responding to ", hash
      await messagePipe.output.provide(Message(kind: MessageKind.putBlock, putBlock_hash: hash.toBinaryString, data: data))
    else: discard

proc main() {.async.} =
  let server = new(Server)
  server.storeDef = StoreDef(path: paramStr(1))

  let tcpServer = await createTcpServer(paramStr(2).parseInt)

  discard await tcpServer.incomingConnections.forEach(proc(x: TcpConnection) = server.handleClient(x).ignore())

when isMainModule:
  main().runLoop()
