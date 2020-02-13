resource "azurerm_resource_group" "AppRG" {
    name     = "${var.appName}RG"
    location = var.location

    tags = {
        environment = "poc"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "AppVNet" {
    name                = "${var.appName}VNet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.AppRG.name

    tags = {
        environment = "poc"
    }
}

# Create subnet
resource "azurerm_subnet" "AppSubnet" {
    name                 = "${var.appName}Subnet"
    resource_group_name  = azurerm_resource_group.AppRG.name
    virtual_network_name = azurerm_virtual_network.AppVNet.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "AppPublicIP" {
    name                         = "${var.appName}PublicIP"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.AppRG.name
    allocation_method = "Dynamic"

    tags = {
        environment = "poc"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "AppNSG" {
    name                = "${var.appName}NSG"
    location            = var.location
    resource_group_name = azurerm_resource_group.AppRG.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "poc"
    }
}

# Create network interface
resource "azurerm_network_interface" "AppNIC" {
    count                     = var.VMCount
    name                      = "${var.appName}NIC-${count.index}"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.AppRG.name
    network_security_group_id = azurerm_network_security_group.AppNSG.id

    ip_configuration {
        name                          = "${var.appName}NICConfig"
        subnet_id                     = azurerm_subnet.AppSubnet.id
        private_ip_address_allocation = "dynamic"
        // public_ip_address_id          = azurerm_public_ip.AppPublicIP.id
    }

    tags = {
        environment = "poc"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        resource_group = azurerm_resource_group.AppRG.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "AppSA" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.AppRG.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "poc"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "AppVM" {
    count                 = var.VMCount
    name                  = "${var.appName}VM-${count.index}"
    location              = var.location
    resource_group_name   = azurerm_resource_group.AppRG.name
    network_interface_ids = ["${element(azurerm_network_interface.AppNIC.*.id, count.index)}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk-${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.6"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.appName}VM-${count.index}"
        admin_username = "ec2-user"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/ec2-user/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoPz/yQPz/ZVliu0MAG5m/dJkM7je95B5fEHeJe2VZKjBjlS0YcWMqb5vhhsiUSUsNbE2bOqj3hyi12BEqg2sjkzgOqvJrE948uFYEHFUR0ocAwfFtGqWjVB137kCcNugR2y36hsrhnwk+1dxplRmFJPjGGghQbVtn2+lhmxl/SnLx/DO0jiyyJnANFij9icRcX7UFgBEViS/m43LOpXbuDRlY1QOqbQEPo9JVgJWlLau1C+lG4JgOFQXLpOjeYAZ7DiXUSvjo72wYtw2ep7bCAR+6plLjk3wMsN7bpxdnVJDuhtpCIm2wac7urP0VkyZ31qbmI9vq4sZc0/Acv/GN nexus_id_rsa"
        }
    }

    boot_diagnostics {
        enabled = "false"
        storage_uri = azurerm_storage_account.AppSA.primary_blob_endpoint
    }

    tags = {
        environment = "poc"
        id = count.index
    }
}
