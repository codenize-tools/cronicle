require 'serverspec'
require 'net/ssh'
require 'tempfile'

require 'cronicle'

def get_ssh_config(host)
  Tempfile.open('', Dir.tmpdir) do |config|
    config.write(`vagrant ssh-config #{host}`)
    config.close
    Net::SSH::Config.for(host, [config.path])
  end
end

def specinfra_config_set_nil(key)
  Specinfra.configuration.instance_variable_set("@#{key}", nil)
  RSpec.configuration.send("#{key}=", nil)
end

CRON_DIRS = %w(
  /var/spool/cron/crontabs
  /var/spool/cron
)

def get_cron_dir
  CRON_DIRS.find do |dir|
    Specinfra.backend.run_command("test -d #{dir}").exit_status.zero?
  end
end

def set_crontab(user, content)
  cron_dir = get_cron_dir

  Tempfile.open('', Dir.tmpdir) do |fp|
    fp << content
    fp.flush
    Specinfra.backend.send_file(fp.path, [cron_dir, user].join('/'))
  end
end

def get_crontab(user)
  cron_dir = get_cron_dir
  crontab = [cron_dir, user].join('/')
  Specinfra.backend.run_command("cat #{crontab}").stdout
end

def get_uname
  Specinfra.backend.run_command('uname -a').stdout.strip
end

set :backend, :ssh
set :sudo_password, 'cronicle'

TARGET_HOSTS = %w(amazon_linux ubuntu)

SSH_OPTIONS_BY_HOST = Hash[*TARGET_HOSTS.map {|host|
  options = Tempfile.open('', Dir.tmpdir) do |config|
    config.write(`vagrant ssh-config #{host}`)
    config.flush
    Net::SSH::Config.for(host, [config.path])
  end

  [host, options]
}.flatten]

def on(*hosts)
  hosts.flatten.map(&:to_s).each do |host|
    specinfra_config_set_nil(:ssh)
    specinfra_config_set_nil(:scp)

    Specinfra.configuration.host = host
    ssh_options = SSH_OPTIONS_BY_HOST[host]
    Specinfra.configuration.ssh_options = ssh_options

    yield(ssh_options)
  end
end

RSpec.configure do |config|
  config.before(:each) do
    on TARGET_HOSTS do
      cron_dir = get_cron_dir
      Specinfra.backend.run_command("rm -f #{cron_dir}/*")
    end
  end
end
