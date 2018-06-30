variable "domain_name" {
  default = ".keys/domain_name"
}
variable "do_token" {
  default = ".keys/do_token"
}
variable "pub_key" {
  default = ".keys/id_rsa.pub"
}
variable "pvt_key" {
  default = ".keys/id_rsa"
}
variable "ssh_fingerprint" {
  default = ".keys/ssh_fingerprint"
}
variable "mirror" {
  description = "Number of ipfs-mirror instances to create"
  default = 1
}