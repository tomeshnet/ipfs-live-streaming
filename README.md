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

| Date    | Time             |
|:--------|:-----------------|
| June 11 | 7:00 - 8:00 p.m. |
| June 25 | 7:00 - 8:00 p.m. |
| July 9  | 7:00 - 8:00 p.m. |

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
* [Yggdrasil](https://github.com/yggdrasil-network/yggdrasil-go) to authenticate the
  streaming device

You should compile yggdrasil at commit `b0acc19`, and when streaming, run it with the
configurations that we will download from the streaming server at a later step.

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
| ↳ yggdrasil       |<--(rtmp-pull)--| ↳ ipfs-http gateway |<--(ipfs)--| ↳ ipfs-http gateway |
|- - - - - - - - - -|                | ↳ ffmpeg            |           |- - - - - - - - - - -|
| Runs RTMP server  |                |- - - - - - - - - - -|           | Pins IPFS hashes    |
| publishable from  |                | Encodes HLS ts+m3u8 |           | learnt from IPNS id |
| yggdrasil IP      |                | pins on IPFS and    |           | of ipfs-server      |
+-------------------+                | publishes to IPNS   |           +---------------------+
          |                          +---------------------+
   (rtmp-pull/push)
          |
          v
Other Streaming Services
```

The on-premise laptop running OBS Studio pushes to the `rtmp-server`, which through
IP-pinning of the yggdrasil-generated IP address will allow only that device to publish.
The `ipfs-server` pulls that RTMP stream, encodes ts chunks in a live m3u8 file using
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

1. Obtain a read-write access token from your Digital Ocean account and store it in your local
    environment:

        echo YOUR_DIGITAL_OCEAN_ACCESS_TOKEN > .keys/do_token

1. Generate RSA keys to access your Digital Ocean VMs:

        ssh-keygen -t rsa -f .keys/id_rsa

    Add the SSH key to your Digital Ocean account, then copy the SSH fingerprint to local
    environment:

        echo YOUR_SSH_FINGERPRINT > .keys/ssh_fingerprint

1. [Install Terraform](https://www.terraform.io/intro/getting-started/install.html), add it to
    your path, then run initialization from our working directory:

        terraform init

1. Provision the streaming servers by running:

        terraform apply

    From your browser, login to your Digital Ocean dashboard and find your new VMs tagged
    with `ipfs-live-streaming`.

1. Download the yggdrasil configurations for the publishing device:

        vagrant scp rtmp-server:/root/publisher.conf ~/

1. Run yggdrasil with the downloaded configurations, you may need `sudo`:

        ./yggdrasil --useconf < ~/publisher.conf

1. Leave yggdrasil running in a window for as long as you are streaming. You should see the
    last line of output like this:

        2018/06/11 03:07:19 Connected: fd00:b280:f90d:5af1:3779:7030:5298:ebaa@159.203.19.222

    The IPv6 is where you will stream to with OBS Studio on your device, and the IPv4 is a
    publicly viewable stream. For example:

        Publish to: rtmp://[fd00:b280:f90d:5af1:3779:7030:5298:ebaa]:1935/live
        View from:  rtmp://159.203.19.222:1935/live

1. When your streaming session is done, you can stop yggdrasil and destroy the servers with:

        terraform destroy
