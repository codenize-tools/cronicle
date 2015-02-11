# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

def set_aws_config(aws, override)
  aws.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
  aws.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
  aws.keypair_name = ENV["EC2_KEYPAIR_NAME"]
  aws.instance_type = "t1.micro"
  aws.region = ENV["AWS_REGION"] || 'us-east-1'
  aws.terminate_on_shutdown = true

  override.ssh.private_key_path = ENV["EC2_PRIVATE_KEY_PATH"] || ENV["EC2_KEYPAIR_NAME"] + ".pem"
  override.ssh.pty = true
  override.vm.boot_timeout = 180
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "dummy"
  config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define :amazon_linux do |machine|
    machine.vm.provider :aws do |aws, override|
      set_aws_config(aws, override)

      aws.ami = ENV["AMAZON_LINUX_AMI"] || "ami-8e682ce6"
      override.ssh.username = "ec2-user"

      override.vm.provision "shell", inline: <<-SH
echo cronicle | passwd --stdin ec2-user
echo 'ec2-user ALL=(ALL) ALL' > /etc/sudoers.d/cloud-init
      SH
    end
  end

  config.vm.define :ubuntu do |machine|
    machine.vm.provider :aws do |aws, override|
      set_aws_config(aws, override)

      aws.ami = ENV['UBUNTU_AMI'] || "ami-84562dec"
      override.ssh.username = "ubuntu"

      override.vm.provision "shell", inline: <<-SH
echo ubuntu:cronicle | chpasswd
echo 'ubuntu ALL=(ALL) ALL' > /etc/sudoers.d/90-cloud-init-users
      SH
    end
  end
end
