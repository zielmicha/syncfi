import reactor/async
import syncfi/schema, syncfi/blobstore, syncfi/blocks

proc storeAcl*(c: BlockConstructor, acl: Acl): Future[int32] =
  let ic = newBlockConstructor(c.storeDef)
  ic.blk.kind = BlockKind.acl
  ic.blk.acl = acl
  ic.storeBlock().then(blockRef => c.addChild(blockRef))
