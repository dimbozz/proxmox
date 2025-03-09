#!/bin/bash

# Make sure that you have download the cloud image already and edit
# the CLOUD_IMAGE_PATH below

export VM_ID=9000
export VM_NAME=ubuntu-cloud
export LV_STORAGE=local-lvm
export CLOUD_IMAGE_PATH=/mnt/pve/HDD2/template/iso/ubuntu-22.04-minimal-cloudimg-amd64.img
export VM_SIZE=32G
export CLOUD_INIT_USER=CLOUD_USER
export CLOUD_INIT_USER_PASSWORD=SUPER_STR0NG_P@SS

echo "Creating the VM"
qm create $VM_ID --name $VM_NAME --cpu cputype=host --socket 1 --core 1 --memory 2048 --net0 virtio,bridge=vmbr0 --ostype l26

echo "Importing the cloud image"
qm importdisk $VM_ID $CLOUD_IMAGE_PATH $LV_STORAGE

echo "Attaching the disk"
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $LV_STORAGE:vm-$VM_ID-disk-0,discard=on,ssd=1
qm set $VM_ID --ide2 $LV_STORAGE:cloudinit

echo "Creating the bootdisk"
qm set $VM_ID --boot c --bootdisk scsi0

echo "Adding serial vga socket"
qm set $VM_ID --serial0 socket --vga serial0

echo "Enabling qemu agent"
qm set $VM_ID --agent enabled=1

echo "Resizing the disk"
qm disk resize $VM_ID scsi0 $VM_SIZE

echo "Adding additional software packages to cloud-init via snippets"
cat << 'EOF' > /var/lib/vz/snippets/vendor.yaml
#cloud-config
runcmd:
    - apt update
    - apt install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
    - reboot
EOF

echo "Adding user information"
qm set $VM_ID --cicustom "vendor=local:snippets/vendor.yaml"
qm set $VM_ID --ciuser $CLOUD_INIT_USER
qm set $VM_ID --cipassword $(openssl passwd -6 $CLOUD_INIT_USER_PASSWORD)
#qm set $VM_ID --sshkey ~/.ssh/authorized_keys
qm set $VM_ID --sshkey ~/.ssh/id_ed25519_vm.pub
qm set $VM_ID --ipconfig0 "ip=dhcp,ip6=dhcp"

echo "Converting to template"
qm template $VM_ID

echo "Remove all environment variables"
unset $VM_ID
unset $VM_NAME
unset $LV_STORAGE
unset $CLOUD_IMAGE_PATH
unset $VM_SIZE
unset $CLOUD_INIT_USER
unset $CLOUD_INIT_USER_PASSWORD

echo "Finished crearing new template"
