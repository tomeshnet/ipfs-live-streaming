IPFS Live Streaming
===================

This project is started by [@ASoTNetworks](https://github.com/ASoTNetworks) and
[@darkdrgn2k](https://github.com/darkdrgn2k) to stream videos over IPFS, which
overlapped with the need to live stream the [Our Networks 2018](https://ournetworks.ca)
conference in Toronto. We will document here the components and processes necessary
to run live streams throughout the conference and archive the video assets on the
IPFS network, that is suitable for a small conference with an audience size of less
than 100 people.

## Planning Calls

| Date    | Time              |
|:--------|:------------------|
| June 11 | 7:00  -  8:00 p.m.|
| June 25 | 10:00 - 11:00 p.m.|
| July 9  | 7:00  -  8:00 p.m.|

Location: [appear.in/ournetworks](https://appear.in/ournetworks)

## Set Up

We will record live streams in 720p (3 Mbps) and archive mp4 of each talk in 1080p.

### Equipment List

* [HD Video camera](https://video.ibm.com/blog/streaming-video-tips/live-streaming-cameras-select-the-best-for-you/)
  that supports HDMI live feed (e.g. Panasonic HC V500)
* Tripod for video camera
* Wireless microphones (e.g. presenter, handheld, audience, room tone, etc.)
* Microphone mixer (e.g. Shure M67)
* On-premise [laptop or desktop](https://obsproject.com/wiki/System-Requirements)
  running OBS Studio and other software
* Two _different_ USB HDMI capture cards with HDMI pass-through and 3.5 mm audio input
  (e.g. one Elgato HD60 and one AVerMedia LGP Lite)
* 1 TB external hard disk drive
* HDMI, XLR, 3.5 mm audio, USB, ethernet, power cables

### On-Premise Setup

```
    Microphones
         |
  (xlr / wireless)
         |
         v
+------------------+
| Audio Mixer      | --(3.5 mm audio)----+
+------------------+                     |
                                         v
+------------------+             +---------------+            +---------------------------+
| HD Video Camera  | --(hdmi)--> | Elgato HD60   | --(usb)--> | Laptop running OBS Studio |
+------------------+             +---------------+            | ↳ Streams to RTMP server  |
                                                              |   for HTTP & IPFS streams |
+------------------+             +---------------+            | ↳ Records mp4 files       |
| Presenter Laptop | --(hdmi)--> | AVerMedia LGP | --(usb)--> |   for local archiving     |
+------------------+             +---------------+            +---------------------------+
                                         |                        |               |
                                (hdmi pass-through)             (usb)         (ethernet)
                                         |                        |               |
                                         v                        v               v
                                     Projector                 1 TB HDD    Gigabit Internet
```

The laptop is the control centre. It has two USB capture cards, connected to separate USB
buses (e.g. if it has a USB2 and USB3 interface) if possible to avoid bandwidth issues. These
will be the video and audio inputs. The capture cards are of two different brands because
cards like the Elgato have problems when running two in parallel. At least one card should
take a 3.5 mm audio input so we can mix the audio into the stream via the audio mixer.

The laptop runs the following software:

* [OBS Studio](https://obsproject.com) locally to stream to our servers
* [OpenVPN](https://openvpn.net) or
  [Yggdrasil](https://github.com/yggdrasil-network/yggdrasil-go) to authenticate the
  streaming device

For Yggdrasil, you should compile at tag `v0.2`, and when streaming, run it with the
configurations that will be downloaded from the streaming server at a later step.

OBS Studio is used throughout the conference to toggle between the two video feeds (i.e. 
the slides and the presenter video). Using the `Start Streaming` function in OBS Studio,
the stream is published at 720p to a RTMP server we will set up in the next step. Using
the `Start Recording` function in OBS Studio, the operator will also record each talk as
a separate 1080p mp4 file to the external hard disk to be published after the event.

### Remote Server Architecture

```
      OBS Studio              Website Embedded     Viewer with
        Source                    Video Player     IPFS Client
          |                              ^             ^                   ^             ^
    (rtmp-publish)                       |             |                   |             |
          |                            (http)        (ipfs)              (http)        (ipfs)
          v                              |             |                   |             |
+-------------------+                +---------------------+           +---------------------+
| rtmp-server       |                | ipfs-server         |           | ipfs-mirror         |
| ↳ nginx-rtmp      |                | ↳ ipfs with pubsub  |           | ↳ ipfs with pubsub  |
| ↳ openvpn         |<--(rtmp-pull)--| ↳ ipfs-http gateway |<--(ipfs)--| ↳ ipfs-http gateway |
| ↳ yggdrasil       |                | ↳ ffmpeg            |           |- - - - - - - - - - -|
|- - - - - - - - - -|                |- - - - - - - - - - -|           | Pins IPFS hashes    |
| Runs RTMP server  |                | Encodes HLS ts+m3u8 |           | learnt from IPNS id |
| publishable from  |                | pins on IPFS and    |           | of ipfs-server      |
| authenticated IPs |                | publishes to IPNS   |           +---------------------+
+-------------------+                +---------------------+
          |
   (rtmp-pull/push)
          |
          v
Other Streaming Services
```

The on-premise laptop running OBS Studio pushes to the `rtmp-server`, which through
IP-pinning of the OpenVPN or Yggdrasil-generated IP address will allow only that device to
publish. The `ipfs-server` pulls that RTMP stream, encodes ts chunks in a live m3u8 file using
ffmpeg, then IPFS adds and pins those files and uses IPNS to publish the m3u8 to its node
ID. The built-in ipfs-http gateway allow those content to be accessed via HTTP, which is
what the embedded player on the website will use. However, viewers running a IPFS client
(with pubsub enabled) can directly view the streams over IPFS. Optionally, we can run
one or more `ipfs-mirror` servers that pin the live streaming content and run additional
gateways.

All the servers described above are provisioned using Terraform on Digital Ocean. In addition,
the RTMP stream can be consumed by other services to provide a parallel stream that does not
involve IPFS.

#### Provision Streaming Servers

We will be using the following tools and services:

* [Digital Ocean](https://www.digitalocean.com) as the virtual machine provider
* [Terraform](https://www.terraform.io) to provision the cloud servers

The following steps assume you have a Digital Ocean account and the above listed software
installed on your local machine, which can be the same device running OBS Studio.

1. Clone this repository and work from the `terraform` directory:

        git clone https://github.com/tomeshnet/ipfs-live-streaming.git
        cd ipfs-live-streaming/terraform

1. From your domain name registrar, point name servers to Digital Ocean's name servers:

        ns1.digitalocean.com
        ns2.digitalocean.com
        ns3.digitalocean.com

    Then store the domain name in your local environment:

        echo -n YOUR_DOMAIN_NAME > .keys/domain_name

1. Obtain a read-write access token from your Digital Ocean account's `API` tab, then store
    it in your local environment:

        echo -n YOUR_DIGITAL_OCEAN_ACCESS_TOKEN > .keys/do_token

1. Generate RSA keys to access your Digital Ocean VMs:

        ssh-keygen -t rsa -f .keys/id_rsa

    Add the SSH key to your Digital Ocean account under `Settings > Security`, then copy the
    SSH fingerprint to your local environment:

        echo -n YOUR_SSH_FINGERPRINT > .keys/ssh_fingerprint

1. [Download Terraform](https://www.terraform.io/intro/getting-started/install.html), add it to
    your path. On Linux it would look something like this:

        https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip
        unzip terraform_0.11.7_linux_amd64.zip
        mv terraform /usr/bin

    Then run initialization from our `terraform` working directory:

        terraform init

1. Provision the streaming servers by running:

        terraform apply

    By default, this will create one instance of each server type. You may choose to create
    multiple instances of `ipfs-mirror` by overriding the `mirror` variable. For example:

        terraform apply -var "mirror=2"

    From your browser, login to your Digital Ocean dashboard and find your new VMs tagged
    with `ipfs-live-streaming`.

1. You will find a couple new files in your `.keys` folder:

        client.conf    (for OpenVPN on Linux)
        client.ovpn    (for OpenVPN on MacOS and Windows)
        yggdrasil.conf (for Yggdrasil)

    To authenticate using OpenVPN, connect with your OpenVPN client using `client.conf` or
    `client.ovpn`, then publish your OBS Studio stream to:

        rtmp://10.10.10.1:1935/live

    To authenticate using Yggdrasil, start it with `yggdrasil.conf` and note the last line of
    output like this:

        sudo yggdrasil --useconf < ./keys/yggdrasil.conf
        ...
        2018/06/11 03:07:19 Connected: fd00:b280:f90d:5af1:3779:7030:5298:ebaa@159.203.19.222

    Then publish your OBS Studio stream to the IPv6:

        rtmp://[fd00:b280:f90d:5af1:3779:7030:5298:ebaa]:1935/live

1. When your streaming session is done, you can stop OpenVPN or Yggdrasil and destroy the
    servers with:

        terraform destroy

## Attribution

The video player uses code from [Video.js](https://videojs.com) and graphics from [ipfs/artwork](https://github.com/ipfs/artwork).
