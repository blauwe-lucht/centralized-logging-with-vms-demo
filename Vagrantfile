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

  config.vm.define "backend" do |backend|
    backend.vm.box = "generic/alma8"
    backend.vm.network "private_network", ip: "192.168.6.32"
    backend.vm.hostname = "backend"
    backend.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 2
    end
    backend.vm.provision "shell", path: "configure-backend.sh"
    backend.vm.synced_folder ".", "/vagrant"
  end
end
