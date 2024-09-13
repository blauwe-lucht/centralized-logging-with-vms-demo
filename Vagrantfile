Vagrant.configure("2") do |config|
  config.vm.define "frontend" do |frontend|
    frontend.vm.box = "generic/alma8"
    frontend.vm.network "private_network", ip: "192.168.6.31"
    frontend.vm.hostname = "frontend"
    frontend.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 2
    end
    frontend.vm.provision "shell", path: "configure-frontend.sh"
    frontend.vm.synced_folder ".", "/vagrant"
  end

  config.vm.define "microservice" do |microservice|
    microservice.vm.box = "generic/alma8"
    microservice.vm.network "private_network", ip: "192.168.6.32"
    microservice.vm.hostname = "microservice"
    microservice.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 2
    end
    # microservice.vm.provision "shell", path: "configure-microservice.sh"
    microservice.vm.synced_folder ".", "/vagrant"
  end

  # VM for Catalogue and Carts Service
#   config.vm.define "sockshop-catalogue-carts" do |catalogue_vm|
#     catalogue_vm.vm.box = "generic/almalinux8"
#     catalogue_vm.vm.network "private_network", ip: "192.168.6.32"
#     catalogue_vm.vm.hostname = "sockshop-catalogue-carts"
#     catalogue_vm.vm.provider "virtualbox" do |v|
#       v.memory = 1024
#       v.cpus = 2
#     end
#   end

#   # VM for Orders, Payment, and Shipping Service
#   config.vm.define "sockshop-orders-payment-shipping" do |orders_vm|
#     orders_vm.vm.box = "generic/almalinux8"
#     orders_vm.vm.network "private_network", ip: "192.168.6.33"
#     orders_vm.vm.hostname = "sockshop-orders-payment-shipping"
#     orders_vm.vm.provider "virtualbox" do |v|
#       v.memory = 1024
#       v.cpus = 2
#     end
#   end

#   # VM for Database and Queue-master Service
#   config.vm.define "sockshop-db-queue" do |db_vm|
#     db_vm.vm.box = "generic/almalinux8"
#     db_vm.vm.network "private_network", ip: "192.168.6.34"
#     db_vm.vm.hostname = "sockshop-db-queue"
#     db_vm.vm.provider "virtualbox" do |v|
#       v.memory = 1024
#       v.cpus = 2
#     end
#   end
end
