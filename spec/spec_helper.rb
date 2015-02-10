require 'serverspec'
require 'net/ssh'
require 'tempfile'

require 'cronicle'

String.disable_colorization = true

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

def get_crontabs
  cron_dir = get_cron_dir
  crontabs = Specinfra.backend.run_command("ls #{cron_dir}/*").stdout.strip.split(/\s+/)

  Hash[*crontabs.map {|crontab|
    content = Specinfra.backend.run_command("cat #{crontab}").stdout
    [crontab, content]
  }.flatten]
end

def get_file(path)
  Specinfra.backend.run_command("cat #{path}").stdout
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
    on :ubuntu do
      Specinfra.backend.run_command("apt-get -y install ruby")
      Specinfra.backend.run_command("gem install bundler")
    end

    on :amazon_linux do
      Specinfra.backend.run_command("gem install bundler")
    end
  end

  config.before(:each) do
    on TARGET_HOSTS do
      cron_dir = get_cron_dir
      Specinfra.backend.run_command("rm -f #{cron_dir}/*")
    end
  end
end

def cronicle(*args)
  command = args.shift
  options = args.last.kind_of?(Hash) ? args.pop : {}

  tempfile(`vagrant ssh-config`) do |ssh_config|
    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.ssh_options = {:config => ssh_config.path}
    end

    client = cronicle_client(options)

    tempfile(yield) do |f|
      args = [command, f.path, args].flatten
      client.send(*args)
    end
  end
end

def cronicle_client(options = {})
  options = {
    :sudo_password => 'cronicle'
  }.merge(options)

  hosts = SSH_OPTIONS_BY_HOST.keys
  host_list = Cronicle::HostList.new(hosts.join(','))

  if ENV['DEBUG'] == '1'
    options[:debug] = true
    Cronicle::Logger.instance.set_debug(true)
  else
    options[:logger] ||= Logger.new('/dev/null')
  end

  Cronicle::Client.new(host_list, options)
end

def tempfile(content, options = {})
  basename = "#{File.basename __FILE__}.#{$$}"
  basename = [basename, options[:ext]] if options[:ext]

  Tempfile.open(basename) do |f|
    f.puts(content)
    f.flush
    f.rewind
    yield(f)
  end
end
