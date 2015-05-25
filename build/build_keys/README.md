# SIMP GPG Keys

## Using This Directory

If you're performing a development build, you don't have to worry about any of
this as the Rake tasks will take care of it for you.

Otherwise, you should follow the steps below under [Creating a GPG Key](#creating-a-gpg-key)
to create your own distribution keys.

You will provide your key directory name as the 'key' argument to any rake
tasks that may ask for it.

## Signing RPMs

To sign an RPM, you will need to:

  1. Create a GPG key if you do not already have one
  1. Sign the RPM using the rpm command

### Creating a GPG key

To create a GPG key with all of the options given from stdin, all you need to
do is call 'gpg --gen-key'. It will prompt you through the various details
necessary to create your key. If you wish to be able to make the key more
autonomously, then you will need to utilize the --batch option. A successful
key creation results in a pubring.gpg (the public key) file and a secring.gpg
(the private key) file.

#### The --batch option

Create a file (the name is arbitrary, so I'll call mine gengpgkey) and inside
declare the various options you wish to set for the GPG key. (See
[the manual for unattended GPG key generation](http://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html#Unattended-GPG-key-generation)
for more details.)

For example, I could use:

```bash
%echo Generating Demo RPM Signature Key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 2048
Name-Real: I B Fake
Name-Comment: Demo Key
Name-Email: ibfake@foo.bar
Expire-Date: 0
Passphrase: Password123!
%pubring pubring.gpg
%secring secring.gpg
# The following creates the key, so we can print "Done!" afterwards
%commit
%echo Done!
```

I can then create the GPG key by calling 'gpg --batch --gen-key gengpgkey'
without needing any further input from the keyboard.

#### A notable issue: entropy

GPG uses entropy to create its randomness, and sometimes it runs out of entropy
before completing the making of the key. In this case, you will need to open
another terminal and run some commands on the same machine as the gpg call in
order to generate more entropy. A reasonable idea is to call 'ls -R /' or 'cat
/var/log/*'. These types of commands tend to generate quite a bit of entropy
for gpg to continue making the key.

### Signing the RPM

Once you have an RPM to sign and a GPG key to sign it with, what you will need
to do next is to define several macros instructing the rpm command about how
you want to sign the rpm. The relevent macros are:

```bash
%_signature
%_gpg_name
%_gpg_path
%__gpg
```

The %_signature macro identifies the type of key to sign with, the options
being pgp or gpg. We want gpg. The %_gpg_name macro identifies which GPG key to
use. It is required by the rpm command. The argument can be the full name given
for the GPG key (full name (comment) <email@address>) or just one of the pieces
of the name, as long as it is unique. The %_gpg_path identifies the directory
containing the GPG key. The default is ~/.gnupg. You cannot specify the name of
the key files themselves to rpm, so they must be the default names of
pubring.gpg and secring.gpg. The %__gpg macro identifies the gpg command to
call for the signing. This is only necessary if it is not installed at
/usr/bin/gpg or if you wish to alias it.

These macros are recommended to be written to a macro file stored at
~/.rpmmacros. However, they can be passed in on the command line using the
--define option. For instance, you could sign a package like so:

```bash
rpm --define '%_signature gpg' --define '%_gpg_name I B Fake' --define \
'%_gpg_path /home/ibfake/gpgkeys/' --resign mypackage.rpm
```

## Exporting Your Public Key

To export your public key, simply run the following command substituting your
values as appropriate:

```bash
gpg --armor --export ibfake@foo.bar --homedir /home/ibfake/gpgkeys > RPM-GPG-KEY-IBFake
```
