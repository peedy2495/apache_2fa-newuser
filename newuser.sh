#!/bin/bash
#Script for adding users an their tokens for apache_2fa
#written by Peedy

[[ -f "apache_credentials" ]] || { echo >&2 "File apache_credentials not found! Wrong current directory?"; exit 1; }
[[ -f "tokens.json" ]] || { echo >&2 "File tokens.json not found! Wrong current directory?"; exit 1; }

echo -n "Username for a new user: "
read NUSER
echo -n "FQDN of your host (realm): "
read FQDN
echo -n "Issuer: "
read ISSUER
echo -n "New Password: "
read -s PWD
echo -ne "\nRe-type new Password:"
read -s RPWD
echo -e "\n"

[[ "$PWD" == "$RPWD" ]] || { echo >&2 "They don't match, sorry."; exit 1; }

HASH=$(echo -n "$NUSER:$FQDN:$PWD"|md5sum|cut -d " " -f 1)
echo "$NUSER:$FQDN:$HASH" >> apache_credentials

HEX_SECRET=$(head -10 /dev/urandom | md5sum | cut -b 1-30)
BASE32=$(oathtool --verbose --totp $HEX_SECRET|sed -n 2p|cut -d " " -f 3)

while read l; do
 if [ "${l: -1}" == '{' ]; then echo "$l" >tokens.new
 elif [ "${l: -1}" == ',' ]; then echo "$l" >>tokens.new
 elif [ "${l: -1}" == '"' ]; then echo "$l," >>tokens.new
 elif [ "${l: -1}" == '}' ]; then echo -e "\"$NUSER\": \"$BASE32\"\n}" >>tokens.new; fi
done <tokens.json

yes | cp -rf tokens.new tokens.json #needed for cp-aliases to ensure overwriting
rm -f tokens.new

qrencode -t UTF8 "otpauth://totp/$ISSUER:$NUSER@$FQDN?secret=$BASE32&issuer=$ISSUER&algorithm=SHA1&digits=6&period=30"
echo -e "\nhex-Key: $HEX_SECRET"
echo -e "base32-Key: $BASE32\n"
