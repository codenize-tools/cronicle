require 'serverspec'
require 'net/ssh'
require 'tempfile'

def get_ssh_config(host)
  Tempfile.open('', Dir.tmpdir) do |config|
    config.write(`vagrant ssh-config #{host}`)
    config.close
    Net::SSH::Config.for(host, [config.path])
  end
end

set :backend, :ssh
set :sudo_password, 'cronicle'

TARGET_HOSTS = %w(amazon_linux ubuntu)

SSH_OPTIONS_BY_HOST = Hash[*TARGET_HOSTS.map {|host|
  options = Tempfile.open('', Dir.tmpdir) do |config|
    config.write(`vagrant ssh-config #{host}`)
    config.close
    Net::SSH::Config.for(host, [config.path])
  end

  [host, options]
}.flatten]

def describe_host(host)
  host = host.to_s
  Specinfra.configuration.host = host
  Specinfra.configuration.ssh_options = SSH_OPTIONS_BY_HOST[host]
  yield
end
