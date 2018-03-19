variable "resource_group" {
  description = "RG test 1 for VNET peering"
  default     = "RGtest1"
}

variable "location" {
  description = "West Europe"
  default     = "Westeurope"
}

variable "hostname" {
  description = "name of VM1"
  default     = "VM1"
}

variable "admin_user" {
  default = "admin_admin"
}

variable "admin_password" {
  default = "Passw0rd1234"
}
