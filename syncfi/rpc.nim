import reactor/tcp, reactor/async, syncfi/schema, capnp, future

proc makeMessagePipe*(pipe: BytePipe): Pipe[Message] =
  newPipe(
    input=pipe.input.readChunksPrefixed().map((x: string) => newUnpackerFlat(x).unpackStruct(0, Message)),
    output=pipe.output.writeChunksPrefixed().map((x: Message) => packStruct(x)))

proc rpcTest*(m: Message) =
  m.repr.echo
  let b = packStruct(m)
  writeFile("message.bin", b)
  let m1 = newUnpackerFlat(b).unpackStruct(0, Message)
  m1.repr.echo
