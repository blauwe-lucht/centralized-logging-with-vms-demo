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

  config.vm.define "opensearch" do |opensearch|
    opensearch.vm.box = "gusztavvargadr/docker-linux"
    opensearch.vm.network "private_network", ip: "192.168.6.33"
    opensearch.vm.synced_folder ".", "/vagrant"

    opensearch.vm.provision "shell", inline: <<-SHELL
      echo Installing docker-compose...
      apt-get install -y docker-compose

      echo Fixing DNS issue...
      cat << EOF > /etc/systemd/resolved.conf
[Resolve]
DNS=8.8.8.8
EOF
      systemctl restart systemd-resolved

      docker compose -f /vagrant/opensearch/docker-compose.yml up -d
      echo Done!
SHELL
  end
end
