# Proxmox Provider
# ---
# Initial Provider Configuration for Proxmox

terraform {
  required_version = ">= 1.1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

# variable "proxmox_api_token_id" {
#   type = string
# }

# variable "proxmox_api_token_secret" {
#   type = string
# }

variable "public_ssh_key" {

  # -- Public SSH Key, you want to upload to VMs and LXC containers.

  type      = string
  sensitive = true
}

variable "ci_user" {
  type      = string
  sensitive = true
}

variable "ci_password" {
  type      = string
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "proxmox_user" {
  type      = string
  sensitive = true
}

variable "proxmox_otp" {
  type      = string
  sensitive = true
}

provider "proxmox" {
  pm_api_url  = var.proxmox_api_url
  pm_password = var.proxmox_password
  pm_user     = var.proxmox_user
  pm_otp      = var.proxmox_otp
  #   pm_api_token_id     = var.proxmox_api_token_id
  #   pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure = true # <-- (Optional) Change to true if you are using self-signed certificates
}