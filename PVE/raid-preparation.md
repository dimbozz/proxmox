### Install Proxmox

So, first thing to do - is get a fresh proxmox install.

After the install is done, we should have 1 drive with a proxmox install, and 1 unused disk.

The installer will create a proxmox default layout that looks something like this (I’m using 1TB Drives):

```bash
Device      Start        End    Sectors   Size Type
/dev/sda1    2048       4095       2048     1M BIOS boot
/dev/sda2    4096     528383     524288   256M EFI System
/dev/sda3  528384 1953525134 1952996751 931.3G Linux LVM
```

This looks good, so now we can begin moving this to a RAID array.

### Clone partition table from first drive to second drive.

In my examples, `sda` is the drive that we installed proxmox to, and `sdb` is the drive I want to use as a mirror.

To start with, let’s clone the partition table for `sda` to `sdb`, which is really easy on linux using `sfdisk`:

```bash
root@tirant:~# sfdisk -d /dev/sda | sfdisk /dev/sdb
Checking that no-one is using this disk right now ... OK

Disk /dev/sdb: 931.5 GiB, 1000204886016 bytes, 1953525168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xa0492137

Old situation:

>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Created a new GPT disklabel (GUID: 7755C404-FEA5-004A-998C-F85E217AE7B7).
/dev/sdb1: Created a new partition 1 of type 'BIOS boot' and of size 1 MiB.
/dev/sdb2: Created a new partition 2 of type 'EFI System' and of size 256 MiB.
/dev/sdb3: Created a new partition 3 of type 'Linux LVM' and of size 931.3 GiB.
/dev/sdb4: Done.

New situation:

Device      Start        End    Sectors   Size Type
/dev/sdb1    2048       4095       2048     1M BIOS boot
/dev/sdb2    4096     528383     524288   256M EFI System
/dev/sdb3  528384 1953525134 1952996751 931.3G Linux LVM

The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
root@tirant:~#
```

sdb now has the same partition table as `sda`. However we’re converting this to a raid1, so we’ll want to change the partition type, which we can also do easily with `sfdisk`:

```bash
root@tirant:~# sfdisk --part-type /dev/sdb 3 A19D880F-05FC-4D3B-A006-743F0F84911E

The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
root@tirant:~#
```

(for MBR, you would use something like: `sfdisk --part-type /dev/sdb 3 fd`)

### Set up mdadm

So now we need to setup a RAID1. `mdadm` isn’t installed by default so we’ll need to install it using: `apt-get install mdadm` (You may need to run `apt-get update` first).

Once mdadm is installed, lets create the raid1 (we’ll create an array with a “missing” disk to start with, we’ll add the first disk into the array in due course):

```bash
root@tirant:~# mdadm --create /dev/md0 --level=1 --raid-disks=2 missing /dev/sdb3
mdadm: Note: this array has metadata at the start and
    may not be suitable as a boot device.  If you plan to
    store '/boot' on this device please ensure that
    your boot-loader understands md/v1.x metadata, or use
    --metadata=0.90
Continue creating array?
Continue creating array? (y/n) y
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
root@tirant:~#
```

And now check that we have a working one-disk array:

```bash
root@tirant:~# cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sdb3[1]
      976367296 blocks super 1.2 [2/1] [_U]
      bitmap: 8/8 pages [32KB], 65536KB chunk

unused devices: <none>
root@tirant:~#
```

Fantastic.

### Move proxmox to the new array

Because proxmox uses lvm, this next step is quite straight forward.

Firstly, lets turn this new raid array into an lvm pv:

```bash
root@tirant:~# pvcreate /dev/md0
  Physical volume "/dev/md0" successfully created.
root@tirant:~#
```

And add it into the pve vg:

```bash
root@tirant:~# vgextend pve /dev/md0
  Volume group "pve" successfully extended
root@tirant:~#
```

Now we can move the proxmox install over to the new array using `pvmove`:

```bash
root@tirant:~# pvmove /dev/sda3 /dev/md0
  /dev/sda3: Moved: 0.00%
  /dev/sda3: Moved: 0.19%
  ...
  /dev/sda3: Moved: 99.85%
  /dev/sda3: Moved: 99.95%
  /dev/sda3: Moved: 100.00%
root@tirant:~#
```

(This will take some time depending on the size of your disks)

Once this is done, we can remove the non-raid disk from the vg:

```bash
root@tirant:~# vgreduce pve /dev/sda3
  Removed "/dev/sda3" from volume group "pve"
root@tirant:~#
```

And remove LVM from it:

```bash
root@tirant:~# pvremove /dev/sda3
  Labels on physical volume "/dev/sda3" successfully wiped.
root@tirant:~#
```

Now, we can add the new disk into the array.

We again change the partition type:

```bash
root@tirant:~# sfdisk --part-type /dev/sda 3 A19D880F-05FC-4D3B-A006-743F0F84911E

The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
root@tirant:~#
```

and then add it into the array:

```bash
root@tirant:~# mdadm --add /dev/md0 /dev/sda3
mdadm: added /dev/sda3
root@tirant:~#
```

We can watch as the array is synced:

```bash
root@tirant:~# cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sda3[2] sdb3[1]
      976367296 blocks super 1.2 [2/1] [_U]
      [>....................]  recovery =  0.1% (1056640/976367296) finish=123.0min speed=132080K/sec
      bitmap: 8/8 pages [32KB], 65536KB chunk

unused devices: <none>
root@tirant:~#
```

We need to wait for this to complete before continuing.

```bash
root@tirant:~# cat /proc/mdstat
Personalities : [raid1] [linear] [multipath] [raid0] [raid6] [raid5] [raid4] [raid10]
md0 : active raid1 sda3[2] sdb3[1]
      976367296 blocks super 1.2 [2/2] [UU]
      bitmap: 1/8 pages [4KB], 65536KB chunk

unused devices: <none>
root@tirant:~#
```

### Making the system bootable

Now we need to ensure we can boot this new system!

Add the required mdadm config to mdadm.conf

```bash
root@tirant:~# mdadm --examine --scan >> /etc/mdadm/mdadm.conf
root@tirant:~#
```

Add some required modules to grub:

```bash
echo '' >> /etc/default/grub
echo '# RAID' >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="part_gpt mdraid09 mdraid1x lvm"' >> /etc/default/grub
```

and update grub and the kernel initramfs

```bash
root@tirant:~# update-grub
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-4.15.17-1-pve
Found initrd image: /boot/initrd.img-4.15.17-1-pve
Found memtest86+ image: /boot/memtest86+.bin
Found memtest86+ multiboot image: /boot/memtest86+_multiboot.bin
done
root@tirant:~# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-4.15.17-1-pve
root@tirant:~#
```

And actually install grub to the disk.

```bash
root@tirant:~# grub-install /dev/sda
Installing for i386-pc platform.
Installation finished. No error reported.
root@tirant:~#
```

If the server is booting via EFI, the output will be slightly different. We can also force it to install for the alternative platform using `--target i386-pc` or `--target x86_64-efi`, eg:

```bash
root@tirant:~# grub-install --target x86_64-efi --efi-directory /mnt/efi
Installing for x86_64-efi platform.
File descriptor 4 (/dev/sda2) leaked on vgs invocation. Parent PID 29184: grub-install
File descriptor 4 (/dev/sda2) leaked on vgs invocation. Parent PID 29184: grub-install
EFI variables are not supported on this system.
EFI variables are not supported on this system.
grub-install: error: efibootmgr failed to register the boot entry: No such file or directory.
root@tirant:~#
```

(/mnt/efi is /dev/sda2 mounted)

Now, clone the BIOS and EFI partitions from the old disk to the new one:

```bash
root@tirant:~# dd if=/dev/sda1 of=/dev/sdb1
2048+0 records in
2048+0 records out
1048576 bytes (1.0 MB, 1.0 MiB) copied, 0.0263653 s, 39.8 MB/s
root@tirant:~# dd if=/dev/sda2 of=/dev/sdb2
524288+0 records in
524288+0 records out
268435456 bytes (268 MB, 256 MiB) copied, 5.48104 s, 49.0 MB/s
root@tirant:~#
```

Finally, reboot and test, if everything has worked, the server should boot up as normal.