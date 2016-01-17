
## blob format

[number of children (4 bytes)]
[hash of child 1]
[hash of child 2]
...
[self encrypted data]

hashes are double SHA256
data is encrypted using ChaCha20 with key=hash and nonce=0.
