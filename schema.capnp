@0xd2400c8c76821c66;

using BlockRef = UInt32;

struct Block {
  innerHashes @0 :List(Data);

  union {
    directory @1 :Directory;
    link @2 :Link;
    blobIndex @3 :BlobIndex;
  }
}

struct Link {
  target @0 :Text;
  # Path of the target.
}

enum FileType {
  directory @0;
  link @1;
}

struct BlobIndex {
  struct Entry {
    offset @0 :UInt64;
    # The offset in file.

    length @1 :UInt64;
    # The length of this entry.

    body @2 :BlockRef;
    # The pointer to the blob/subindex.

    isIndex @3 :UInt8;
    # Is this entry subindex?
  }

  entries @0 :List(Entry);
}

struct DirectoryEntry {
  acl @0 :BlockRef;
  # Pointer to the ACL associated with this entry.

  name @1 :Text;
  # The name of this entry.

  executable @2 :UInt8;
  # Is this entry executable? This will be ANDed with the execution policy
  # in ACL to generate UNIX permissions.

  type @3 :FileType;
  # Type of entry.

  mtime @4 :UInt64;
  # Modification time, in milliseconds from Unix epoch.

  body @5 :BlockRef;
  # Entry body.
}

struct Directory {
  entries @0 :DirectoryEntry;
  # A list of directory entries.
}
