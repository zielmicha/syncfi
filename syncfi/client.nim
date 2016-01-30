import reactor/async
import syncfi/blobstore, syncfi/schema, syncfi/errors

type
  Client* = ref object of RootObj
    serverConn*: Pipe[Message]
    serverResponses*: CompleterTable[uint64, Message]
    msgIdCounter: uint64

proc initClient*(self: Client) =
  self.msgIdCounter = 2
  self.serverResponses = newCompleterTable[uint64, Message]()

proc remoteCall*(self: Client, msg: Message): Future[Message] =
  msg.id = self.msgIdCounter
  self.msgIdCounter += 1

  let res = self.serverResponses.waitFor(msg.id)
  self.serverConn.output.provide(msg).then(() => res)

proc checkType*(msg: Message, expected: set[MessageKind]) {.async.} =
  if msg.kind notin expected:
    if msg.kind == MessageKind.error:
      asyncRaise newFilesystemError(msg.errorNumber.cint, msg.message)
    else:
      asyncRaise newFilesystemError(errors.EIO, "bad return type")
