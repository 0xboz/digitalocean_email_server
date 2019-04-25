#!/usr/bin/env bash
# Use only one set of DNS in DigitalOcean
echo "************************** IMPORTANT ****************************"
echo "Add DNS Records"
echo "1. A Record for {root domain} pointing to server IP"
echo "2. A Record for WWW {root domain} pointing to primary server"
echo "3. MX record (hostname: {root domain}; value: FQDN or root DOMAIN);"
echo '4. SPF (hostname: {root domain}; value: "v=spf1 a mx ~all");'
echo '5. DMARC (hostname: _dmarc.{root domain}; value: "v=DMARC1; p=none");'
echo "*****************************************************************"

# Warning
read -p "Have you read the instructions above yet? (Y/N): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # DOMAIN, FQDN and HOSTNAME
    # Since this is a primary ROOT DOMAIN server. Use 'hostname -f' instead of 'hostname -d'
    DOMAIN="$(hostname -f)"
    FQDN="$(hostname -f)"
    HOSTNAME="$(hostname -a)"

    # Obtain IP
    IP="$(ifconfig eth0 | grep inet | awk '/[0-9]\./{print $2}')"

    # Change hostname
    sed -i -e 's/manage_etc_hosts/#manage_etc_hosts/' /etc/cloud/cloud.cfg
    sed -i -e "s/.*/$FQDN/" /etc/hostname
    sed -i -e 's/127\.0\.0\.1.*/127.0.0.1 localhost.localdomain localhost/' /etc/hosts
    sed -i -e "s/127\.0\.1\.1.*/$IP $FQDN $HOSTNAME/" /etc/hosts

    # Pip install required packages
    pip install -r /root/SendEmail/requirements.txt

    # Install bsd-mailx
    apt install -y bsd-mailx

    # Install postfix
    debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    apt-get install -y postfix

    # opendkim
    apt-get install -y opendkim opendkim-tools
    # Configure OpenDKIM
    # /etc/opendkim.conf
    echo "AutoRestart             Yes" >> /etc/opendkim.conf
    echo "AutoRestartRate         10/1h" >> /etc/opendkim.conf
    echo "UMask                   002" >> /etc/opendkim.conf
    echo "Syslog                  yes" >> /etc/opendkim.conf
    echo "SyslogSuccess           Yes" >> /etc/opendkim.conf
    echo "LogWhy                  Yes" >> /etc/opendkim.conf
    echo "Canonicalization        relaxed/simple" >> /etc/opendkim.conf
    echo "ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts" >> /etc/opendkim.conf
    echo "InternalHosts           refile:/etc/opendkim/TrustedHosts" >> /etc/opendkim.conf
    echo "KeyTable                refile:/etc/opendkim/KeyTable" >> /etc/opendkim.conf
    echo "SigningTable            refile:/etc/opendkim/SigningTable" >> /etc/opendkim.conf
    echo "Mode                    sv" >> /etc/opendkim.conf
    echo "PidFile                 /var/run/opendkim/opendkim.pid" >> /etc/opendkim.conf
    echo "SignatureAlgorithm      rsa-sha256" >> /etc/opendkim.conf
    echo "UserID                  opendkim:opendkim" >> /etc/opendkim.conf
    echo "Socket                  inet:12301@localhost" >> /etc/opendkim.conf
    # /etc/default/opendkim
    echo 'SOCKET="inet:12301@localhost"' >> /etc/default/opendkim
    # /etc/postfix/main.cf
    echo "" >> /etc/postfix/main.cf
    echo "# Added by opendkim installation" >> /etc/postfix/main.cf
    echo "milter_protocol = 2" >> /etc/postfix/main.cf
    echo "milter_default_action = accept" >> /etc/postfix/main.cf
    echo "smtpd_milters = inet:localhost:12301" >> /etc/postfix/main.cf
    echo "non_smtpd_milters = inet:localhost:12301" >> /etc/postfix/main.cf
    # Create more configuration files/folders
    mkdir /etc/opendkim && mkdir /etc/opendkim/keys && touch /etc/opendkim/TrustedHosts && touch /etc/opendkim/KeyTable && touch /etc/opendkim/SigningTable
    echo "127.0.0.1" >> /etc/opendkim/TrustedHosts
    echo "localhost" >> /etc/opendkim/TrustedHosts
    echo "192.168.0.1/24" >> /etc/opendkim/TrustedHosts
    echo "*.$DOMAIN" >> /etc/opendkim/TrustedHosts
    echo "mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN/mail.private" >> /etc/opendkim/KeyTable
    echo "*@$DOMAIN mail._domainkey.$DOMAIN" >> /etc/opendkim/SigningTable
    # Generate Keys
    cd /etc/opendkim/keys
    mkdir $DOMAIN
    cd $DOMAIN
    opendkim-genkey -s mail -d $DOMAIN
    chown opendkim:opendkim mail.private
    # Export opendkim public key
    mkdir -p /root/opendkim/$DOMAIN
    openssl rsa -in mail.private -pubout -out /root/opendkim/$DOMAIN/opendkim-public-key.pem
    # Backup opendkim keys
    cd /root/opendkim/$DOMAIN
    tar -czvf opendkim.tar.gz /etc/opendkim/keys
    # Create TXT record for DKIM
    /usr/bin/python3 /root/SendEmail/bin/public-key-to-one-line.py /root/opendkim/$DOMAIN/opendkim-public-key.pem
    PUBLICKEY=`cat /root/opendkim/$DOMAIN/opendkim-public-key.txt`

    # Firewall ufw
    ufw allow 'WWW Full'
    ufw allow 'Postfix'
    ufw allow 'Postfix SMTPS'
    ufw allow 'Postfix Submission'

    # TLS
    apt install -y certbot
    certbot certonly --non-interactive --agree-tos --standalone --email letsencrypt@$DOMAIN -d $FQDN

    # Enable TLS in Postfix
    sed -i -e 's/smtpd_tls_cert_file/#smtpd_tls_cert_file/' /etc/postfix/main.cf
    sed -i -e 's/smtpd_tls_key_file/#smtpd_tls_key_file/' /etc/postfix/main.cf
    echo "" >> /etc/postfix/main.cf
    echo "# TLS certificate by Let's Encrypt" >> /etc/postfix/main.cf
    echo "smtpd_tls_cert_file = /etc/letsencrypt/live/$FQDN/fullchain.pem" >> /etc/postfix/main.cf
    echo "smtpd_tls_key_file = /etc/letsencrypt/live/$FQDN/privkey.pem" >> /etc/postfix/main.cf
    echo "# Allow use of TLS but make it optional" >> /etc/postfix/main.cf
    echo "smtp_tls_security_level = may" >> /etc/postfix/main.cf
    echo "smtp_tls_note_starttls_offer = yes" >> /etc/postfix/main.cf
    echo "smtpd_tls_security_level = may" >> /etc/postfix/main.cf

    # Restart services
    service postfix restart
    service opendkim restart

    # 'Catch All' forwarding
    echo "@$DOMAIN $DOMAIN@yopmail.com" >> /etc/postfix/virtual
    echo "" >> /etc/postfix/main.cf
    echo "# Catch All Forwarding" >> /etc/postfix/main.cf
    echo "virtual_alias_domains = $DOMAIN" >> /etc/postfix/main.cf
    echo "virtual_alias_maps = hash:/etc/postfix/virtual" >> /etc/postfix/main.cf
    postmap /etc/postfix/virtual
    service postfix reload

    # Back up letsencrypt keys
    mkdir /root/letsencrypt
    cd /root/letsencrypt
    tar -czvf letsencrypt.tar.gz /etc/letsencrypt/

    # Instructions
    echo "DNS Setup Instructions"
    echo "DNS Setup Instructions" >> /root/DNS.conf
    echo "************************************************************"
    echo "************************************************************" >> /root/DNS.conf
    # A Record for DOMAIN
    echo "" >> /root/DNS.conf
    echo "A record for $DOMAIN"
    echo "A record for $DOMAIN" >> /root/DNS.conf
    echo "Hostname: $DOMAIN"
    echo "Hostname: $DOMAIN" >> /root/DNS.conf
    echo "Value: $IP"
    echo "Value: $IP" >> /root/DNS.conf
    # A Record for FQDN
    echo "" >> /root/DNS.conf
    echo "A record for mail server FQDN"
    echo "A record for mail server FQDN" >> /root/DNS.conf
    echo "Hostname: $FQDN"
    echo "Hostname: $FQDN" >> /root/DNS.conf
    echo "Value: $IP"
    echo "Value: $IP" >> /root/DNS.conf
    # MX Record
    echo "" >> /root/DNS.conf
    echo "MX record"
    echo "MX record" >> /root/DNS.conf
    echo "Hostname: $DOMAIN"
    echo "Hostname: $DOMAIN" >> /root/DNS.conf
    echo "Value: $FQDN"
    echo "Value: $FQDN" >> /root/DNS.conf
    # SPF
    echo "" >> /root/DNS.conf
    echo "SPF - TXT records"
    echo "SPF - TXT records" >> /root/DNS.conf
    echo "Hostname: $DOMAIN"
    echo "Hostname: $DOMAIN" >> /root/DNS.conf
    echo 'Value: "v=spf1 a mx ~all"'
    echo 'Value: "v=spf1 a mx ~all"' >> /root/DNS.conf
    # DMARC
    echo "" >> /root/DNS.conf
    echo "DMARC - TXT records"
    echo "DMARC - TXT records" >> /root/DNS.conf
    echo "Hostname: _dmarc.$DOMAIN"
    echo "Hostname: _dmarc.$DOMAIN" >> /root/DNS.conf
    echo 'Value: "v=DMARC1; p=none"'
    echo 'Value: "v=DMARC1; p=none"' >> /root/DNS.conf
    # DKIM
    echo "" >> /root/DNS.conf
    echo "DKIM - TXT records"
    echo "DKIM - TXT records" >> /root/DNS.conf
    echo "Hostname: mail._domainkey.$DOMAIN"
    echo "Hostname: mail._domainkey.$DOMAIN" >> /root/DNS.conf
    echo 'Value: "v=DKIM1; k=rsa; p='$PUBLICKEY'"'
    echo 'Value: "v=DKIM1; k=rsa; p='$PUBLICKEY'"' >> /root/DNS.conf
    echo "" >> /root/DNS.conf
    echo "************************************************************"
    echo "************************************************************" >> /root/DNS.conf
fi
