# packer-kubernetes-debian

packer-kubernetes-debian is a set of configuration files used to build an automated Debian 13 (trixie) virtual machine images using [Packer](https://www.packer.io/).

This repository was forked from https://github.com/eaksel/packer-Debian11 and heavily modified:
1. Uses Debian cloud images instead of an installation iso file
1. Uses cloud-init instead of ansible

The image is created with everything required to use the provided VM as a Kubernetes node. 

## Prerequisites

* [Packer](https://www.packer.io/downloads.html)
  * <https://www.packer.io/intro/getting-started/install.html>
* A working Qemu installation with the kvm accellerator.

## How to use Packer

Commands to create an automated VM image:

To create a Debian VM image use the following command:

```bash
packer build debian.pkr.hcl
```

## Customizing

By default the vm is based on daily cloud images from Debian. The latest daily image is configured. This can be changed in the variables section in `debian.pkr.hcl`.

The Kubernetes version installed for `kubectl`, `kubeadm`, and `kubelet` is also configurable in the variable section in `debian.pkr.hcl`.

The apt signing key for the Kubernetes package repository is specific to each Kubernetes minor version and is rotated periodically. It is downloaded from `pkgs.k8s.io` on every build, so the build machine needs internet access and no key needs to be maintained in this repository.


## Default credentials

There are no default credentials for the default `debian` user. Use cloud-init to provide an ssh authorized key to be able to log in.

# Use in Proxmox

Create a template VM that can be cloned to create actual VMs.

1. Create a VM without any storage
   ```bash
      qm create $VMID -name kubetemplate -agent enabled=1 \
                      -sockets 2 -cores 2 -cpu host -memory 4096 \
                      -net0 model=virtio,bridge=vmbr0 \
                      -scsihw virtio-scsi-single \
                      -ostype l26 -serial0 socket \
                      -rng0 source=/dev/urandom
   ```
1. Copy to built image (`$IMAGE`) to one of the Proxmox cluster nodes
1. Import the image into Proxmox and assign it as a disk to the target VM
   ```bash
      qm disk import $VMID $IMAGE $STORAGE_NAME
   ```
1. Update the VM to attach the newly imported disk to the correct hardware. Virtio works best, but SATA or SCSI are also fine.
   ```bash
      qm set $VMID -virtio0 $STORAGE_NAME:vm-$VMID-disk-0
   ```
1. Add cloud-init to the vm
   ```bash
      qm set $VMID --ide2 $STORAGE_NAME:cloudinit
   ```
1. Update the VM's boot order
   ```bash
      qm set $VMID -boot 'order=virtio0;net0'
   ```
1. Transform the new VM into a template VM
   ```bash
      qm template $VMID
   ```

This template can be cloned to create a runnable VM. Use `cloudinit` to set the new VM's network information and an SSH key for the default `debian` user.
