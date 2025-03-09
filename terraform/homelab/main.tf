resource "proxmox_vm_qemu" "cloudinit-test" {

  count = 0 # set to 0 and apply to destroy

  # -- General settings

  name  = "terraform-test-vm"
  desc  = "A test for using terraform and cloudinit"
  agent = 1 # Activate QEMU agent for this VM

  # Node name has to be the same name as within the cluster
  # this might not include the FQDN
  target_node = "pve"
  tags        = "your-tag-1,your-tag-2"
  vmid        = "100"

  # The destination resource pool for the new VM
  # pool = "pool0"

  # -- Template settings

  clone      = "ubuntu-cloud" # The template name to clone this vm from
  full_clone = true           # <-- (Optional) Set to "false" to create a linked clone

  # -- Boot Process

  onboot           = true
  boot             = "order=scsi0"
  startup          = ""   # <-- (Optional) Change startup and shutdown behavior
  automatic_reboot = true # <-- Automatically reboot the VM after config change
  # vm_state         = "running"

  # -- Hardware Settings

  # qemu_os = "other"
  os_type  = "cloud-init"
  bios     = "seabios" # "seabios" "ovmf"
  cores    = 1
  sockets  = 1
  vcpus    = 0
  cpu_type = "host"
  memory   = 2048
  # balloon  = 2048 # <-- (Optional) Minimum memory of the balloon device, set to 0 to disable ballooning

  # -- Network Settings

  # Setup the network interface and assign a vlan tag: 256
  network {
    id     = 0 # <-- ! required since 3.x.x
    model  = "virtio"
    bridge = "vmbr0"
    # tag    = 256
  }

  network {
    id     = 1 # <-- ! required since 3.x.x
    model  = "virtio"
    bridge = "vmbr1"
    # tag    = 256
  }

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  # -- Disk Settings

  scsihw = "virtio-scsi-single" # "virtio-scsi-pci" "lsi"
  # scsihw = "virtio-scsi-single"  # <-- (Optional) Change the SCSI controller type, since Proxmox 7.3, virtio-scsi-single is the default one

  disks { # <-- ! changed in 3.x.x
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage  = "local-lvm"
          size     = "32G" # <-- Change the desired disk size, ! since 3.x.x size change will trigger a disk resize
          iothread = false # <-- (Optional) Enable IOThread for better disk performance in virtio-scsi-single
          # replicate = false # <-- (Optional) Enable for disk replication
        }
      }
    }
  }

  # -- Cloud Init Settings

  ciuser     = var.ci_user
  cipassword = var.ci_password
  ciupgrade  = true
  cicustom   = "vendor=HDD2:snippets/vendor.yaml"
  # Setup the ip address using cloud-init.
  # Keep in mind to use the CIDR notation for the ip.
  # ipconfig0 = "ip=192.168.235.55/24,gw=192.168.235.1"
  ipconfig0 = "ip=dhcp"
  ipconfig1 = "ip=10.0.1.3/24,gw=10.0.1.1"
  sshkeys   = var.public_ssh_key # <-- (Optional) Change to your public SSH key

  # sshkeys = <<EOF
  # ssh-rsa 9182739187293817293817293871== user@pc
  # EOF
}
