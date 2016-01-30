import options

proc getRef*(): Option[int] =
  # Retrieve reference from deserialized block.
  return none(int)

proc getChild*() =
  let iter = iterator (): int {.closure.} =
    let reference = getRef()
