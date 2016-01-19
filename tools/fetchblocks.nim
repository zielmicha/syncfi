import syncfi/blobstore, syncfi/rpc, syncfi/schema
import os, reactor/loop, reactor/async, reactor/tcp, sets, options

proc main() {.async.} =
  let storeDef = StoreDef(path: paramStr(1))
  let connectAddr = paramStr(2)

  let conn = await connectTcp(connectAddr)
  let messagePipe = rpc.makeMessagePipe(conn)

  var alreadyRequested = initSet[BlockHash]()

  proc ensureBlock(h: BlockHash) {.async.} =
    if h in alreadyRequested:
      return

    alreadyRequested.incl h
    if storeDef.verifyBlob(h):
      echo "block ", h, " already downloaded"
      return
    else:
      echo "requesting ", h
      let msg = Message(kind: MessageKind.getBlock, getBlock_hash: h.toBinaryString)
      await messagePipe.output.provide(msg)

  await ensureBlock(paramStr(3).blockHash)

  proc blockReceived(h: BlockHash, data: string) {.async.} =
    if data == nil:
      echo "server doesn't have block ", $h, "!"
      asyncRaise "missing block"

    if sha256d(data) != h:
      echo "server returned corrupt block ", $h, "!"
      asyncRaise "bad block"

    let children = parseBlock(data, none(BlockHash)).hashes

    for child in children:
      await ensureBlock(child)

    echo "storing block ", $h
    discard storeBlob(storeDef, data)

  while true:
    let x = await messagePipe.input.receive()
    case x.kind:
    of MessageKind.putBlock:
      await blockReceived(x.putBlock_hash.byteArray(BlockHashBytes), x.data)
    else:
      echo "received unknown message ", x.kind


when isMainModule:
  main().ignore()
  runLoop()
