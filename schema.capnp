@0xd2400c8c76821c66;

using BlockRef = Int32;

using Hash = Data;

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
  regular @2;
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
  # in ACL to generate UNIX permissions, but only for files.

  type @3 :FileType;
  # Type of entry.

  mtime @4 :UInt64;
  # Modification time, in milliseconds from Unix epoch.

  body @5 :BlockRef;
  # Entry body.

  attributes @6 :BlockRef;
  # Additional attributes (for example xattrs).
}

struct Directory {
  entries @0 :List(DirectoryEntry);
  # A list of directory entries.
}

struct Message {
  # A message that is passed between peers (or client and server).

  union {
    getBlock :group {
      # Request peer to return block without outer hash `hash`.
      hash @0 :Hash;
    }

    putBlock :group {
      # Block with outer hash `hash` has data `data`.

      hash @1 :Hash;
      # Outer hash of `data`.

      data @2 :Data;
      # The encrypted data with outer hashes of child blocks prepended.
      # Null if peer doesn't have this block.
    }

    listDirectory :group {
      # Requests the server to return directory listing.

      path @3 :Text;
      # Path of the directory.
    }

    directoryListing :group {
      # A response to the listDirectory message

      path @4 :Text;
      # Path of the directory.

      outerHash @5 :Hash;
      # Outer hash of the original directory block.

      childrenOuterHashes @6 :Hash;
      # Outer hashes of the children of the directory block.

      directory @7 :Block;
      # The directory contest, with inner hashes of some entries
      # redacted (specifacally these of other directories and files
      # you don't have read permissions to).
    }
  }
}
