
variable "kubernetes_major" {
  type = string
  default = "1"
}

variable "kubernetes_minor" {
   type = string
   default = "37"
}

variable "boot_wait" {
  type    = string
  default = "5s"
}

variable "disk_size" {
  type    = string
  default = "4G"
}

variable "headless" {
  type    = string
  default = "true"
}

variable "image_name" {
  type   = string
  default = "debian-13-genericcloud-amd64-daily.qcow2"
}

variable "iso_base_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/cloud/trixie/daily/latest"
}

variable "numvcpus" {
  type    = string
  default = "1"
}

# The Kubernetes package repositories are signed with a key that is specific to each
# minor version, and that key is rotated periodically. Fetch it on every build instead
# of embedding a copy that would eventually expire.
data "http" "kubernetes_key" {
  url = "https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_major}.${var.kubernetes_minor}/deb/Release.key"
}

source "qemu" "debian" {
  accelerator      = "kvm"
  boot_wait        = "${var.boot_wait}"
  disk_compression = true
  disk_image       = true
  disk_interface   = "virtio"
  disk_size        = "${var.disk_size}"
  format           = "qcow2"
  headless         = "${var.headless}"
  http_content     = {
     "/cloud-init/user-data" = templatefile("${path.root}/http/cloud-init/user-data", { kubernetes_major = "${var.kubernetes_major}", kubernetes_minor = "${var.kubernetes_minor}", kubernetes_key_b64 = base64encode(data.http.kubernetes_key.body) } )
     "/cloud-init/meta-data" = file("http/cloud-init/meta-data")
  }
  iso_checksum     = "file:${var.iso_base_url}/SHA512SUMS"
  iso_url          = "${var.iso_base_url}/${var.image_name}"
  net_device       = "virtio-net"
  qemuargs         = [["-smbios", "type=1,serial=ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/cloud-init/"]]
  shutdown_command = "echo 'packer'|sudo systemctl poweroff "
  ssh_password     = "packer"
  ssh_port         = 22
  ssh_timeout      = "5m"
  ssh_username     = "debian"
  vm_name          = "proxmox-k8s-${var.kubernetes_major}.${var.kubernetes_minor}.qcow2"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    execute_command = "echo 'packer'|{{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = ["scripts/cleanup.sh"]
  }

}
