Since this is a bug in the Ubuntu packaging for server it needs to be fixed there but in the meantime a work-around without having to uninstall docker-compose temporarily or having to switch to the docker repos instead you can make it use pass instead. This is what I did:

```bash
sudo apt install gnupg2 pass 
gpg2 --full-generate-key
```

This generates a you a gpg2 key, After that's done you can list it with

```bash
gpg2 -k
```

Copy the key id (from the line labelled [uid]) and do

```bash
pass init "whatever key id you have"
```

After that docker login worked fine since it defaults to use pass and only tries to fallback to secretservice if it can't find it. secretservice seems to have an X11 dependency which isn't present on a basic server install.

Side effect is that you get a somewhat more secure credentials store or on your server instead of a base64 encoded json file.