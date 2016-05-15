import reactor/tcp, reactor/async, syncfi/schema, capnp, future

proc makeMessagePipe*(pipe: BytePipe): Pipe[Message] =
  proc input(): Stream[Message] {.asynciterator.} =
    asyncFor chunk in pipe.input.readChunksPrefixed():
      let msg = await catchError(newUnpackerFlat(chunk).unpackStruct(0, Message))
      asyncYield msg

  newPipe(
    input=input(),
    output=pipe.output.writeChunksPrefixed().map((x: Message) => packStruct(x)))

proc rpcTest*(m: Message) =
  m.repr.echo
  let b = packStruct(m)
  writeFile("message.bin", b)
  let m1 = newUnpackerFlat(b).unpackStruct(0, Message)
  m1.repr.echo
