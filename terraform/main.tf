resource "digitalocean_tag" "ipfs-live-streaming" {
  name = "ipfs-live-streaming"
}

resource "digitalocean_droplet" "rtmp-server" {
  image = "debian-9-x64"
  name = "rtmp-server"
  region = "tor1"
  size = "1gb"
  tags = ["${digitalocean_tag.ipfs-live-streaming.id}"]
  private_networking = true
  ipv6 = true
  monitoring = true
  ssh_keys = [
    "${file(var.ssh_fingerprint)}"
  ]
  connection {
    user = "root"
    type = "ssh"
    private_key = "${file(var.pvt_key)}"
    timeout = "2m"
  }
  provisioner "file" {
    source      = "rtmp-server"
    destination = "/tmp"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/rtmp-server/bootstrap.sh",
      "/tmp/rtmp-server/bootstrap.sh",
    ]
  }
}

resource "digitalocean_droplet" "ipfs-server" {
  image = "debian-9-x64"
  name = "ipfs-server"
  region = "tor1"
  size = "1gb"
  tags = ["${digitalocean_tag.ipfs-live-streaming.id}"]
  private_networking = true
  ipv6 = true
  monitoring = true
  ssh_keys = [
    "${file(var.ssh_fingerprint)}"
  ]
  connection {
    user = "root"
    type = "ssh"
    private_key = "${file(var.pvt_key)}"
    timeout = "2m"
  }
  provisioner "file" {
    source      = "ipfs-server"
    destination = "/tmp"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ipfs-server/bootstrap.sh",
      "chmod +x /tmp/ipfs-server/process-stream.sh",
      "/tmp/ipfs-server/bootstrap.sh",
    ]
  }
}