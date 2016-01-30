@0xd2400c8c76821c66;

### On-disk format

using BlockRef = UInt32;

using Hash = Data;

struct Block {
  innerHashes @0 :List(Data);

  union {
    directory @1 :Directory;
    link @2 :Link;
    blobIndex @3 :BlobIndex;
    blob @4 :Data;
    acl @5 :Acl;
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
    # The offset in the file.

    length @1 :UInt64;
    # The length of this entry.

    body @2 :BlockRef;
    # The pointer to the blob/subindex.
  }

  entries @0 :List(Entry);
}

struct DirectoryEntry {
  acl @0 :BlockRef;
  # Pointer to the ACL associated with this entry.

  name @1 :Text;
  # The name of this entry.

  executable @2 :Bool;
  # Is this entry executable? This will be ANDed with the execution policy
  # in ACL to generate UNIX permissions, but only for regular files.

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

### ACLs
#
# The AclEntry is roughly based on RickACLs (https://lwn.net/Articles/661357/)
#
# Definitions:
# - superuser - principal that is prefix of another pricipal. "/" is the origin superuser.

struct PrincipalSubId {
  union {
    random @0 :UInt64;
    # randomly generated identifier that has meaning assigned via some OOB mean

    unixGroup @1 :UInt32;
    # unix group ID

    unixUser @2 :UInt32;
    # unix user ID
  }
}

struct Principal {
  chain @0 :List(PrincipalSubId);
  # Each filesystem object has a chain of owners.
}

struct AclEntry {
  enum Action {
    readData @0;
    # principal may read from this file

    writeData @1;
    # principal may write to this file

    listDirectory @2;
    # principal may list this directory (only meaningful on client side)

    addFile @3;
    # principal may create files that are not directories

    addSubdirectory @4;
    # principal may create subdirectories

    execute @5;
    # principal may execute this object (only meaningful on client side)

    enterDirectory @6;
    # principal may access files inside this directory

    deleteChild @7;
    # principal may delete any child

    allowDeleteChild @8;
    # principal may delete child if he has `delete` access on it

    delete @9;
    # principal may delete this object if he has `allowDeleteChild` access on the parent

    writeOwner @10;
    # principal may change owner to any principal he has authorized as

    writeAcl @11;
    # principal may modify ACL list (restricted by mininherit)
  }

  enum Kind {
    allow @0;
    deny @1;
  }

  actions @0 :List(Action);

  kind @1 :Kind;

  principal @2 :Principal;
  # to whom the permission is granted

  anyone @3 :Bool;
  # if this flag is set, the permission applies to any direct subprincipal of `principal`
}

struct PosixCompat {
  groupOwner @0 :Principal;
  # Group of this object

  inheritGroup @1 :Bool;
  # Should children inherit group from this directory?

  setGid @2 :Bool;
  # Is this (executable) file setgid?

  setUid @3 :Bool;
  # Is this (executable) file setuid?
}

struct Acl {
  access @0 :List(AclEntry);
  # Permissions for this object.

  inherit @1 :List(AclEntry);
  # Permissions inherited for new objects in this folder.

  mininherit @2 :List(AclEntry);
  # Permissions that can be only unset by superuser (for this objects and also inherited).

  owner @3 :Principal;
  # Object owner.

  posixCompat @4 :PosixCompat;
  # POSIX compatibility attributes
}

### Peer-to-peer protocol

struct Message {
  # A message that is passed between peers (or client and server).

  id @0 :UInt64;
  # ID of this message (>0)

  responseTo @5 :UInt64;
  # This message is response to other message

  union {
    getBlock :group {
      # Request peer to return block without outer hash `hash`.
      hash @1 :Hash;
    }

    putBlock :group {
      # Block with outer hash `hash` has data `data`.

      hash @2 :Hash;
      # Outer hash of `data`.

      data @3 :Data;
      # The encrypted data with outer hashes of child blocks prepended.
      # Null if peer doesn't have this block.
    }

    listDirectory :group {
      # Requests the server to return directory listing.

      path @4 :Text;
      # Path of the directory.
    }

    error :group {
      errorNumber @9 :UInt32;
      # Optional errno (or 0).

      message @10 :Text;
      # Error message.
    }

    directoryListing :group {
      # A response to the listDirectory message

      outerHash @6 :Hash;
      # sha256d of the outer hash of the original directory block.
      # This can be used by the clients to quickly check if a tree has changed.

      childrenOuterHashes @7 :List(Hash);
      # Outer hashes of the children of the directory block.

      directory @8 :Block;
      # The directory contest, with inner hashes of some entries
      # redacted (specifically these of other directories and files
      # you don't have read permissions to).
    }
  }
}
