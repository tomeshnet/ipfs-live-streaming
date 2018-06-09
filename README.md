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

We will use [Vagrant](https://www.vagrantup.com) to provision streaming servers on
[Digital Ocean](https://www.digitalocean.com). The following steps assume you have a
Digital Ocean account and Vagrant installed on your local machine.

1. Install the `vagrant-digitalocean` plugin:

        vagrant plugin install vagrant-digitalocean

1. Generate RSA keys to access your server on Digital Ocean:

        ssh-keygen -t rsa -f ~/.ssh/ipfs_live_streaming_rsa

1. Obtain a read-write access token from your Digital Ocean account and export it in your local environment:

        export DO_ACCESS_TOKEN=<YOUR_DIGITAL_OCEAN_ACCESS_TOKEN>

1. Clone this repository and from the `vagrant` directory, provision the streaming servers by running:

        vagrant up

    From your browser, login to your Digital Ocean dashboard and find your new servers tagged with `ipfs-live-streaming`.

1. From your local OBS machine, stream to `rtmp://<YOUR_RTMP_SERVER_IP>:1935/live`, where `YOUR_RTMP_SERVER_IP` is the IP address of your rtmp-server Droplet.

1. When your streaming session is done, you can destroy the servers with:

        vagrant destroy

