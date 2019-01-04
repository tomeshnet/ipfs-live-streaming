package main

import "encoding/hex"
import "fmt"
import "net"
import "github.com/yggdrasil-network/yggdrasil-go/src/address"
import "github.com/yggdrasil-network/yggdrasil-go/src/crypto"

func main() {
  bpub, bpriv := crypto.NewBoxKeys()
  id := crypto.GetNodeID(bpub)
  addr := net.IP(address.AddrForNodeID(id)[:])

  fmt.Println("EncryptionPublicKey:", hex.EncodeToString(bpub[:]))
  fmt.Println("EncryptionPrivateKey:", hex.EncodeToString(bpriv[:]))
  fmt.Println("Address:", addr)
}
