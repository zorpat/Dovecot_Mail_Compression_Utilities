Dovecot mail compression utilities
==================================

Use this utilities to "bzip" you existing messages in maildir-format after you have enabled "ZLIB" in dovecot configuration.
This utilities are safe to use, since they don't "doublezip" existing compressed files!

For informations and comments please feedback!

Install steps (preferred for latest stable release):
----------------------------------------------
 - wget https://github.com/zorpat/Dovecot_Mail_Compression_Utilities/archive/v0.2-stable.tar.gz
 - tar -zxvf V0.2-stable.tar.gz
 - cd Dovecot_Mail_Compression_Utilities/
 - change variables on the top of dovecot-maildir-compress.sh file to meet your requirements
 - chmod +x dovecot-maildir-compress.sh
 - ./dovecot-maildir-compress.sh /var/vmail/domain/user
