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

| Date    | Time             | Notes |
|:--------|:-----------------|:------|
| June 11 | 7:00 - 8:00 p.m. |       |
| June 25 | 7:00 - 8:00 p.m. |       |
| July 9  | 7:00 - 8:00 p.m. |       |

Location: [appear.in/ournetworks](https://appear.in/ournetworks)

## Set Up Streaming Servers

We will be using the following tools and services:

* [Digital Ocean](https://www.digitalocean.com) as the virtual machine provider
* [OBS Studio](https://obsproject.com) locally to stream to our servers
* [Vagrant](https://www.vagrantup.com) to provision the cloud servers
* [Yggdrasil](https://github.com/yggdrasil-network/yggdrasil-go) to authenticate the streaming device

The following steps assume you have a Digital Ocean account and the above listed
software installed on your local machine that you will stream from using OBS Studio.

1. Install vagrant plugins:

        vagrant plugin install vagrant-digitalocean vagrant-scp

1. Generate RSA keys to access your Digital Ocean VMs:

        ssh-keygen -t rsa -f ~/.ssh/ipfs_live_streaming_rsa

1. Obtain a read-write access token from your Digital Ocean account and export it in your local environment:

        export DO_ACCESS_TOKEN=<YOUR_DIGITAL_OCEAN_ACCESS_TOKEN>

1. Clone this repository and from the `vagrant` directory, provision the streaming servers by running:

        vagrant up

    From your browser, login to your Digital Ocean dashboard and find your new VMs tagged with `ipfs-live-streaming`.

1. Download the yggdrasil configurations for the publishing device:

        vagrant scp rtmp-server:/root/publisher.conf ~/

1. Compile yggdrasil at commit `b0acc19` and run it with the downloaded configurations, you may need `sudo`:

        ./yggdrasil --useconf < ~/publisher.conf

1. Leave yggdrasil running in a window for as long as you are streaming. You should see the last line of output like this:

        2018/06/11 03:07:19 Connected: fd00:b280:f90d:5af1:3779:7030:5298:ebaa@159.203.19.222

    The IPv6 is where you will stream to with OBS Studio on your device, and the IPv4 is a publicly viewable stream. For example:

        Publish to: rtmp://[fd00:b280:f90d:5af1:3779:7030:5298:ebaa]:1935/live
        View from:  rtmp://159.203.19.222:1935/live

1. When your streaming session is done, you can stop yggdrasil and destroy the servers with:

        vagrant destroy
