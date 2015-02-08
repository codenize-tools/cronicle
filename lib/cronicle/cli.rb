class Cronicle::CLI < Thor
  include Cronicle::Logger::Helper

  class_option 'file',               :aliases => '-f', :desc => 'Job definition file',        :default => 'Jobfile'
  class_option 'hosts',              :aliases => '-h', :desc => 'Hosts definition file'
  class_option 'target-roles',       :aliases => '-r', :desc => 'Target host role list',      :type => :array
  class_option 'sudo-password',      :aliases => '-p', :desc => 'Sudo password'
  class_option 'ssh-config',                           :desc => 'OpenSSH configuration file', :default => nil
  class_option 'connection-timeout',                   :desc => 'SSH connection timeout',     :type => :numeric, :default => nil
  class_option 'concurrency',                          :desc => 'SSH concurrency',            :type => :numeric, :default => 10
  class_option 'libexec',                              :desc => 'Cronicle libexec path',      :default => '/var/lib/cronicle/libexec'
  class_option 'debug',                                :desc => 'Debug mode',                 :type => :boolean, :default => false
  class_option 'color',                                :desc => 'Colorize log',               :type => :boolean, :default => true

  def initialize(*args)
    super

    if options['debug']
      Cronicle::Logger.instance.set_debug(true)
    end

    if not $stdin.tty? or not options['color']
      String.disable_colorization = true
    end
  end

  desc 'exec JOB_NAME', 'Execute a job on remote hosts'
  def exec(job_name)
    with_logging do
      set_ssh_options
      client.exec(jobfile, job_name)
    end
  end

  desc 'apply', 'Apply cron jobs to remote hosts'
  option 'dry-run', :desc => 'Do not actually change', :type => :boolean, :default => false
  def apply
    with_logging do
      set_ssh_options
      client.apply(jobfile)
    end
  end

  private

  def with_logging
    begin
      yield
    rescue => e
      if options['debug']
        raise e
      else
        log(:error, e.message, :color => :red)
      end
    end
  end

  def client
    Cronicle::Client.new(host_list, client_options)
  end

  def jobfile
    file = options['file']

    unless File.exist?(file)
      raise Thor::Error, "No Jobfile found (looking for: #{file})"
    end

    file
  end

  def host_list
    Cronicle::HostList.new(
      options.fetch('hosts', ''),
      host_list_options
    )
  end

  def client_options
    {
      :sudo_password => options['sudo-password'],
      :concurrency => options['concurrency'],
      :libexec => options['libexec'],
      :dry_run => options['dry-run']
    }
  end

  def host_list_options
    {
      :roles => options['target-roles']
    }
  end

  def set_ssh_options
    conn_timeout = options['connection-timeout']
    ssh_config = options['ssh-config']

    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.connection_timeout = conn_timeout if conn_timeout
      ssh.ssh_options = {:config => ssh_config} if ssh_config
    end
  end
end
