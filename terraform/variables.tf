variable "domain_name" {
  default = ".keys/domain_name"
}
variable "email_address" {
  default = ".keys/email_address"
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
variable "m3u8_http_urls" {
  description = "Optional comma-separated list of URLs to m3u8 over HTTP '<url_1>','<url_2>'"
  default = ""
}
variable "dryrun" {
  default = ".keys/dryrun"
}
