import posix

export posix.ENOTDIR
export posix.EIO
export posix.ENOENT

type
  FilesystemError* = object of Exception
    errorno*: cint

proc newFilesystemError*(errno: cint, msg: string): ref FilesystemError =
  result = newException(FilesystemError, msg)
  result.errorno = errno
