# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "dummy"
  config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define :amazon_linux do |machine|
    machine.vm.provider :aws do |aws, override|
      aws.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
      aws.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
      aws.keypair_name = ENV["EC2_KEYPAIR_NAME"]
      aws.instance_type = "t1.micro"
      aws.region = "ap-northeast-1"
      aws.terminate_on_shutdown = true
      aws.ami = "ami-3c87993d"

      override.ssh.username = "ec2-user"
      override.ssh.private_key_path = ENV["EC2_PRIVATE_KEY_PATH"]
      override.ssh.pty = true

      override.vm.provision "shell", inline: <<-SH
echo cronicle | passwd --stdin ec2-user
echo 'ec2-user ALL=(ALL) ALL' > /etc/sudoers.d/cloud-init
      SH

      override.vm.boot_timeout = 180
    end
  end

  config.vm.define :ubuntu do |machine|
    machine.vm.provider :aws do |aws, override|
      aws.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
      aws.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
      aws.keypair_name = ENV["EC2_KEYPAIR_NAME"]
      aws.instance_type = "t1.micro"
      aws.region = "ap-northeast-1"
      aws.terminate_on_shutdown = true
      aws.ami = "ami-18b6aa19"

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = ENV["EC2_PRIVATE_KEY_PATH"]
      override.ssh.pty = true

      override.vm.provision "shell", inline: <<-SH
echo ubuntu:cronicle | chpasswd
echo 'ubuntu ALL=(ALL) ALL' > /etc/sudoers.d/90-cloud-init-users
      SH

      override.vm.boot_timeout = 180
    end
  end
end
