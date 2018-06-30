provider "digitalocean" {
  token = "${file(var.do_token)}"
}