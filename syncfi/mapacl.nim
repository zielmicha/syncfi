# Maps UNIX permissions to SyncFi ACLs and vice versa
import syncfi/schema, syncfi/misc
import posix

proc simplePrincipal*(id: PrincipalSubId): Principal =
  return Principal(chain: @[id])

proc bitminus(a: int, b: int): int =
  a and (not b)

proc makeAcl*(owner: uint32, group: uint32, mode: int): tuple[acl: Acl, executable: bool] =
  let acl = Acl(access: @[], inherit: @[], posixCompat: PosixCompat())

  let fileType = mode and 0o170000

  var otherBits = (mode shr 0) and 7
  var groupBits = (mode shr 3) and 7
  var userBits = (mode shr 6) and 7

  const readMask = 4
  const writeMask = 2
  const executeMask = 1

  result.executable = true
  result.acl = acl

  proc notExecutable(m: int): bool =
    return 0 == (m and executeMask) or 0 == (m and readMask)

  if fileType == S_IFREG and notExecutable(otherBits) and notExecutable(groupBits) and notExecutable(userBits):
    userBits = userBits and executeMask
    groupBits = groupBits and executeMask
    otherBits = otherBits and executeMask
    result.executable = false
  else:
    result.executable = true

  let optionBits = (mode shr 9) and 7
  let setSid = (optionBits and 4) != 0
  let setGid = (optionBits and 2) != 0
  let isStickyDir = ((optionBits and 1) != 0) and (fileType == S_IFDIR)

  if fileType == S_IFREG:
    acl.posixCompat.setGid = setSid
    acl.posixCompat.setGid = setGid
  elif fileType == S_IFDIR:
    acl.posixCompat.inheritGroup = setGid

  let deleteActions = if isStickyDir: @[AclEntry_Action.allowDeleteChild] else: @[AclEntry_Action.deleteChild]

  var writeActions: seq[AclEntry_Action] = @[]
  if fileType == S_IFDIR:
    writeActions = writeActions & @[AclEntry_Action.writeData, AclEntry_Action.addFile, AclEntry_Action.addSubdirectory] & deleteActions
  else:
    writeActions.add(AclEntry_Action.writeData)

  var executeActions: seq[AclEntry_Action] = @[]
  if fileType == S_IFDIR:
    executeActions.add AclEntry_Action.enterDirectory
  else:
    executeActions.add AclEntry_Action.execute

  var readActions: seq[AclEntry_Action] = @[]
  if fileType == S_IFDIR:
    readActions.add AclEntry_Action.listDirectory
  else:
    readActions.add AclEntry_Action.readData

  let ownerPrincipal = simplePrincipal(PrincipalSubId(kind: PrincipalSubIdKind.unixUser, unixUser: owner))
  let groupPrincipal = simplePrincipal(PrincipalSubId(kind: PrincipalSubIdKind.unixGroup, unixGroup: group))

  acl.posixCompat.groupOwner = groupPrincipal
  acl.access.add AclEntry(kind: AclEntry_Kind.allow,
                          actions: @[AclEntry_Action.delete],
                          principal: ownerPrincipal)

  proc addEntry(bits: int, kind: AclEntry_Kind, principal: Principal, anyone=false) =
    var actions: seq[AclEntry_Action] = @[]
    if (bits and readMask) != 0:
      actions.add readActions
    if (bits and writeMask) != 0:
      actions.add writeActions
    if (bits and executeMask) != 0:
      actions.add executeActions

    if actions.len > 0:
      acl.access.add AclEntry(actions: actions, kind: kind, principal: principal, anyone: anyone)

  addEntry(userBits, AclEntry_Kind.allow, ownerPrincipal)
  addEntry(groupBits.bitminus(userBits), AclEntry_Kind.deny, ownerPrincipal)

  addEntry(groupBits, AclEntry_Kind.allow, groupPrincipal)
  addEntry(otherBits.bitminus(groupBits), AclEntry_Kind.deny, groupPrincipal)
  addEntry(otherBits.bitminus(userBits), AclEntry_Kind.deny, ownerPrincipal)

  addEntry(otherBits, AclEntry_Kind.allow, Principal(chain: @[]), anyone=true)

proc makeMode*(fileType: FileType, acl: Acl, executable: bool): tuple[mode: int, isExact: bool] =
  nil
