#!/bin/bash
cd terraform

echo "--------Domain Name--------"
read -p "What is your domain name: " -r
echo -n $REPLY > .keys/domain_name

echo Make sure you point your domain dns servers to
echo ns1.digitalocean.com
echo ns2.digitalocean.com
echo ns3.digitalocean.com


echo "--------Digital Oceans API Token--------"
read -p "What is your API Token form DigitalOcean: "  -r
echo -n $REPLY > .keys/do_token

echo "--------Digital Oceans RSA--------"
echo "Press enter when prompted for password "
ssh-keygen -t rsa -f .keys/id_rsa
echo Add the SSH key to your Digital Ocean account under Settings > Security
echo "------------------"
cat  .keys/id_rsa.pub
echo "------------------"
fingerprint=$(ssh-keygen -l -E md5 -f .keys/id_rsa.pub | awk '{print $2}' | sed 's/MD5://')
echo -n $fingerprint> .keys/ssh_fingerprint
echo Once added the finger print will be $fingerprint

echo "--------Lets Encrypt--------"
read -p "What is your e-mail (for lets encrypt): "  -r
echo -n $REPLY > .keys/email_address

echo "----Installing terraform-----"
wget https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip
unzip terraform_0.11.7_linux_amd64.zip
sudo mv terraform /usr/bin

terraform init
# terraform apply
