provider "azurerm" {
  features {}
  use_msi         = true                      # or use service principal
  subscription_id = "c3fe1760-2291-4cbe-8c5a-6980e01baccb"  # replace with your actual sub ID
}

resource "azurerm_resource_group" "rg" {
  name     = "aks-rg"
  location = "West US 3"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "aks-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}



resource "azurerm_network_security_group" "aks_nsg" {
  name                = "aks-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-All-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_subnet_network_security_group_association" "aks_subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}


resource "azurerm_kubernetes_cluster" "aks" {
  name                = "myakscluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myaks"

  default_node_pool {
    name           = "worker"
    node_count     = 2
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.subnet.id
    zones  = ["2", "3"]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "azure"
  }
}

resource "null_resource" "get_kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_kubernetes_cluster.aks.resource_group_name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
  }
}


provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

  
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }

  
}


resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "default"
  version    = "4.10.0"

  values = [<<EOF
controller:
  service:
    type: LoadBalancer
EOF
  ]

  depends_on = [null_resource.get_kubeconfig]
}
resource "helm_release" "mysql" {
  name       = "mysql"
  chart      = "${path.module}/helm-mysql"
  namespace  = "default"
  create_namespace = false
  depends_on = [helm_release.nginx_ingress]
}

resource "helm_release" "backend" {
  name       = "backend"
  chart      = "${path.module}/helm-backend"
  namespace  = "default"
  create_namespace = false
  depends_on = [helm_release.mysql]
}

resource "helm_release" "frontend" {
  name       = "frontend"
  chart      = "${path.module}/helm-frontend"
  namespace  = "default"
  create_namespace = false
  depends_on = [helm_release.backend]
}



