ssh-keygen -R 20.124.130.98
ssh -i "$HOME\.ssh\asterisk_azure_ed25519" azureuser@20.124.130.98

sudo asterisk -vvvvvr

pjsip set logger on
core set verbose 5
core set debug 5

rtp set debug on


cloud-init status --long