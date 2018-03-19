provider "azurerm" {
  subscription_id = "efe4f11e-82a6-4b53-9128-4cc8cbe7d9a4"
  client_id       = "acd13df7-7750-4c45-a83b-f111820e0b2a"
  client_secret   = "cck8bWwDWto9hxw1tdSKjT7t8KOT5ubVojQ31cF5by0="
  tenant_id       = "e4bc8d17-4d20-4b58-8eb5-ec06e4d91b3b"
}

resource "azurerm_resource_group" "RGtest1" {
  name     = "${var.resource_group}"
  location = "${var.location}"

  tags {
    environment = "Terraform Testing"
  }
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.resource_group}-vnet1"
  location            = "${var.location}"
  address_space       = ["10.188.0.0/18"]
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"
}

resource "azurerm_subnet" "SN1-vnet1" {
  name                 = "${var.resource_group}-SN1-vnet1"
  resource_group_name  = "${azurerm_resource_group.RGtest1.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet1.name}"
  address_prefix       = "10.188.1.0/24"
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "${var.resource_group}-vnet2"
  location            = "${var.location}"
  address_space       = ["10.188.64.0/18"]
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"
}

resource "azurerm_subnet" "SN2-vnet2" {
  name                 = "${var.resource_group}-SN2-vnet2"
  resource_group_name  = "${azurerm_resource_group.RGtest1.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet2.name}"
  address_prefix       = "10.188.64.0/24"
}

resource "azurerm_virtual_network_peering" "peer1" {
  name                         = "vNet1-to-vNet2"
  resource_group_name          = "${azurerm_resource_group.RGtest1.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnet1.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnet2.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "peer2" {
  name                         = "vNet2-to-vNet1"
  resource_group_name          = "${azurerm_resource_group.RGtest1.name}"
  virtual_network_name         = "${azurerm_virtual_network.vnet2.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.vnet1.id}"
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# create SA for VM diagnostics
resource "azurerm_storage_account" "SA1" {
  name                     = "ajjstorageaccount"
  resource_group_name      = "${azurerm_resource_group.RGtest1.name}"
  location                 = "${var.location}"
  account_tier             = "standard"
  account_replication_type = "LRS"

  tags {
    environment = "Terraform-test"
  }
}

# create Network Interface
resource "azurerm_network_interface" "NIC1" {
  name                = "${var.hostname}-NIC1"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"

  ip_configuration {
    name                          = "${var.hostname}-ipconfig"
    subnet_id                     = "${azurerm_subnet.SN1-vnet1.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.pip1.id}"
  }
}

# create Availability Set
resource "azurerm_availability_set" "AS-1" {
  name                         = "${var.hostname}-AS-1"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.RGtest1.name}"
  platform_update_domain_count = "7"
  platform_fault_domain_count  = "3"
  managed                      = true

  tags {
    environment = "Terraform-test"
  }
}

# create PIP
resource "azurerm_public_ip" "pip1" {
  name                         = "${var.hostname}-pip1"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.RGtest1.name}"
  public_ip_address_allocation = "dynamic"

  #  domain_name_label            = "${var.hostname}"
}

# create Managed Disk for Datadisk2
resource "azurerm_managed_disk" "datadisk2" {
  name                 = "${var.hostname}-Datadisk2"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.RGtest1.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "31"

  tags {
    environment = "Terraform-test"
  }
}

# Create Managed Disk for Datadisk1
resource "azurerm_managed_disk" "datadisk1" {
  name                 = "${var.hostname}-Datadisk1"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.RGtest1.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "512"

  tags {
    environment = "Terraform-test"
  }
}

# create VM1
resource "azurerm_virtual_machine" "VM1" {
  name                             = "${var.hostname}"
  location                         = "${var.location}"
  resource_group_name              = "${azurerm_resource_group.RGtest1.name}"
  vm_size                          = "standard_F2"
  availability_set_id              = "${azurerm_availability_set.AS-1.id}"
  network_interface_ids            = ["${azurerm_network_interface.NIC1.id}"]
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  tags {
    environment = "Terraform-test"
  }

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.hostname}-OSdisk"
    caching           = "none"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"

    # disk_size_gb = "1023"
    # os_type           = "windows"
  }

  storage_data_disk {
    name            = "${var.hostname}-datadisk1"
    managed_disk_id = "${azurerm_managed_disk.datadisk1.id}"
    create_option   = "attach"
    lun             = 1
    disk_size_gb    = "${azurerm_managed_disk.datadisk1.disk_size_gb}"
    caching         = "readwrite"
  }

  storage_data_disk {
    name            = "${var.hostname}-datadisk2"
    managed_disk_id = "${azurerm_managed_disk.datadisk2.id}"
    create_option   = "attach"
    lun             = 2
    disk_size_gb    = "${azurerm_managed_disk.datadisk2.disk_size_gb}"
    caching         = "readwrite"
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "${azurerm_storage_account.SA1.primary_blob_endpoint}"
  }

  os_profile {
    computer_name  = "${var.hostname}"
    admin_username = "${var.admin_user}"
    admin_password = "${var.admin_password}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

# create PIP for Load Balancer
resource "azurerm_public_ip" "pip2-LB" {
  name                         = "${var.hostname}-pip2-LB"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.RGtest1.name}"
  public_ip_address_allocation = "dynamic"
}

# Create LoadBalancer
resource "azurerm_lb" "LB1" {
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"
  name                = "${var.hostname}-LB1"
  location            = "${var.location}"

  frontend_ip_configuration = {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.pip2-LB.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"
  loadbalancer_id     = "${azurerm_lb.LB1.id}"
  name                = "BackendPool1"
}

resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = "${azurerm_resource_group.RGtest1.name}"
  loadbalancer_id                = "${azurerm_lb.LB1.id}"
  name                           = "RDP-VM-${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 3389
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  count                          = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.RGtest1.name}"
  loadbalancer_id                = "${azurerm_lb.LB1.id}"
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.LB_probe.id}"
  depends_on                     = ["azurerm_lb_probe.LB_probe"]
}

resource "azurerm_lb_probe" "LB_probe" {
  resource_group_name = "${azurerm_resource_group.RGtest1.name}"
  loadbalancer_id     = "${azurerm_lb.LB1.id}"
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}
