import syncfi/blobstore, syncfi/blobstore_file, syncfi/rpc, syncfi/schema
import os, reactor/loop, reactor/async, reactor/tcp, sets, options

proc main*(storePath: string, connectAddr: string, needBlob: string) {.async.} =
  let readyCompleter = newCompleter[void]()
  let storeDef = newFileBlobstore(storePath)

  let conn = await connectTcp(connectAddr)
  let messagePipe = rpc.makeMessagePipe(conn)

  var pending = 0
  var alreadyRequested = initSet[BlockHash]()

  proc ensureBlock(h: BlockHash) {.async.} =
    if h in alreadyRequested:
      asyncReturn

    alreadyRequested.incl h
    if (await storeDef.hasTree(h)):
      echo "block ", h, " already downloaded"
    else:
      echo "requesting ", h
      pending += 1
      let msg = Message(kind: MessageKind.getBlock, getBlock_hash: h.toBinaryString)
      await messagePipe.output.provide(msg)

  await ensureBlock(needBlob.blockHashFromString)

  proc checkPending() =
    if pending == 0:
      readyCompleter.complete()

  proc blockReceived(h: BlockHash, data: string) {.async.} =
    if data == nil:
      echo "server doesn't have block ", $h, "!"
      asyncRaise "missing block"

    if blockHash(data) != h:
      echo "server returned corrupt block ", $h, "! hash: ", blockHash(data), " length: ", data.len
      asyncRaise "bad block"

    let children = parseBlock(data, none(BlockHash)).hashes

    echo "storing block ", $h

    for child in children:
      await ensureBlock(child)

    discard (await storeBlob(storeDef, data))
    pending -= 1
    checkPending()

  proc readLoop() {.async.} =
    while true:
      let x = await messagePipe.input.receive()
      case x.kind:
      of MessageKind.putBlock:
        await blockReceived(x.putBlock_hash.byteArray(BlockHashBytes), x.data)
      else:
        echo "received unknown message ", x.kind

  readLoop().ignore
  checkPending()
  await readyCompleter.getFuture
  echo "done"
