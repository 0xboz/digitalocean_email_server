# DigitalOcean Email Server
A simple email server over a DigitalOcean $5/month droplet (Debian 9)
![mail-tester](https://imgur.com/JDTDAu5)
## Features
* [x]  DKIM enabled verification
* [x]  SPF enabled verification
* [x]  TLS enabled in Postfix
* [x]  'Catch All' forwarding

## Prerequisite
* A top-level domain. Get one at [namecheap.com](https://www.namecheap.com/)
* Name server pointing to ([Instructions](https://www.namecheap.com/support/knowledgebase/article.aspx/767/10/how-to-change-dns-for-a-domain))
> ns1.digitalocean.com  
> ns2.digitalocean.com  
> ns3.digitalocean.com  

## How-to
* Log into DigtialOcean and add a new domain
* DNS configuration

* SSH into the droplet and install git
```
apt install -y git
```
* Clone this repo
```
git clone https://github.com/0xboz/digitalocean_email_server.git
chmod +x -R digitalocean_email_server
cd digitalocean_email_server
```
* Optional: initial setup
```
./set_up_server.sh
```
* Installation
```
./install_email_server.sh
```
