import reactor/async, reactor/tcp, os
import syncfi/blobstore, syncfi/rpc, syncfi/schema

proc main() {.async.} =
  let connectAddr = paramStr(1)
  let path = paramStr(2)
  let conn = await connectTcp(connectAddr)
  let messagePipe = rpc.makeMessagePipe(conn)

  let responses = newCompleterTable[uint64, Message]()
  messagePipe.input.forEach(proc(msg: Message) =
    if msg.responseTo != 0:
      responses.complete(msg.responseTo, msg)).ignore()

  let resp = responses.waitFor(1)
  await messagePipe.output.provide(
    Message(id: 1, kind: MessageKind.listDirectory, path: path))

  let d = await resp
  d.repr.echo

when isMainModule:
  main().runLoop()
