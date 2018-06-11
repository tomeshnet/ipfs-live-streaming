package main

import "encoding/hex"
import "fmt"
import "yggdrasil"

func main() {
  var core yggdrasil.Core

  bpub, bpriv := core.NewEncryptionKeys()
  id := core.DEBUG_getNodeID(bpub)
  addr := core.DEBUG_addrForNodeID(id)

  fmt.Println("EncryptionPublicKey:", hex.EncodeToString(bpub[:]))
  fmt.Println("EncryptionPrivateKey:", hex.EncodeToString(bpriv[:]))
  fmt.Println("Address:", addr)
}
