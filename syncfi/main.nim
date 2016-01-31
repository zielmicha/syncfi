import reactor/loop, reactor/async
import syncfi/blobstore, syncfi/blobstore_file, syncfi/server, syncfi/tools/storedir, syncfi/tools/fetchblocks
import docopt, tables, os, options, strutils

const doc = """
syncfi

Usage:
   syncfi [-p <path>] blobstore init
   syncfi [-p <path>] blobstore tag <labelname> <outerhash> [<innerhash>]
   syncfi [-p <path>] blobstore tag <labelname>
   syncfi [-p <path>] blobstore fetch <connectaddr> <outerhash>
   syncfi [-p <path>] blobstore storedir <path> <labelname>
   syncfi [-p <path>] serve <port>
   syncfi mount <connectaddr> <fspath> <mountpath>

Options:
  -h --help               Show this screen.
  -p --blobstore=<path>   Blobstore path [default: ~/.syncfi].
"""

let ns = docopt(doc)

var storePath = expandTilde($ns.getOrDefault("--blobstore"))
let storeDef = newFileBlobstore(storePath)

if ns["blobstore"]:
  if ns["init"]:
    createDir(storePath)
    createDir(storePath / "labels")
    createDir(storePath / "blobs")

  if ns["tag"]:
    if ns["<outerhash>"]:
      var label: Label
      label.outer = blockHashFromString($ns["<outerhash>"])
      if ns["<innerhash>"]:
        label.inner = some(blockHashFromString($ns["<innerhash>"]))

      storeDef.putLabel($ns["<labelname>"], label).runLoop()
    else:
      let label = storeDef.getLabel($ns["<labelname>"]).runLoop()
      echo $label
  elif ns["storedir"]:
    storedir.main(storePath=storePath, directory= $ns["<path>"], label= $ns["<labelname>"]).runLoop()
  elif ns["fetch"]:
    fetchblocks.main(storePath=storePath, connectAddr= $ns["<connectaddr>"], needBlob= $ns["<outerhash>"]).runLoop()
elif ns["serve"]:
  server.main(storePath=storePath, port=($ns["<port>"]).parseInt).runLoop()
