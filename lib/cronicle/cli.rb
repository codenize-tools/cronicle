class Cronicle::CLI < Thor
  include Cronicle::Logger::Helper

  class_option 'file',               :aliases => '-f', :desc => 'Job definition file',        :default => 'Jobfile'
  class_option 'hosts',              :aliases => '-h', :desc => 'Hosts definition file'
  class_option 'target-roles',       :aliases => '-r', :desc => 'Target host role list',      :type => :array
  class_option 'sudo-password',      :aliases => '-p', :desc => 'Sudo password',              :default => ENV['CRONICLE_SUDO_PASSWORD']
  class_option 'ssh-user',                             :desc => 'SSH login user',             :default => ENV['CRONICLE_SSH_USER']
  class_option 'ask-pass',                             :desc => 'Ask sudo password',          :type => :boolean, :default => false
  class_option 'dry-run',                              :desc => 'Do not actually change',     :type => :boolean, :default => false
  class_option 'ssh-config',         :aliases => '-c', :desc => 'OpenSSH configuration file', :default => (ENV['CRONICLE_SSH_CONFIG'] || '~/.ssh/config')
  class_option 'ssh-options',                          :desc => 'SSH options (JSON)',         :default => ENV['CRONICLE_SSH_OPTIONS']
  class_option 'connection-timeout',                   :desc => 'SSH connection timeout',     :type => :numeric, :default => nil
  class_option 'concurrency',                          :desc => 'SSH concurrency',            :type => :numeric, :default => Cronicle::Client::DEFAULTS[:concurrency]
  class_option 'var-dir',                              :desc => 'Cronicle var dir path',      :default => Cronicle::Client::DEFAULTS[:var_dir]
  class_option 'verbose',            :aliases => '-v', :desc => 'Verbose mode',               :type => :boolean, :default => false
  class_option 'require',                              :desc => 'Load ruby libraries',        :type => :array,   :default => []
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

    options['require'].each {|lib| require(lib) }
  end

  desc 'exec JOB_NAME', 'Execute a job on remote hosts'
  def exec(job_name)
    with_logging do
      set_ssh_options
      client.exec(jobfile, job_name)
    end
  end

  desc 'apply', 'Apply cron jobs to remote hosts'
  def apply
    with_logging do
      set_ssh_options
      client.apply(jobfile)
    end
  end

  desc 'cleanup', 'Clean up cron jobs on remote hosts'
  def cleanup
    with_logging do
      set_ssh_options
      client.cleanup
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
    client_opts = {
      :sudo_password => options['sudo-password'],
      :ssh_user => options['ssh-user'],
      :concurrency => options['concurrency'],
      :var_dir => options['var-dir'],
      :dry_run => options['dry-run'],
      :verbose => options['verbose']
    }

    if options['ask-pass']
      hl = HighLine.new
      client_opts[:sudo_password] = hl.ask('Password: ') {|q| q.echo = '*' }
    end

    client_opts
  end

  def host_list_options
    {
      :roles => options['target-roles']
    }
  end

  def set_ssh_options
    conn_timeout = options['connection-timeout']
    ssh_options = {}

    if options['ssh-options']
      JSON.parse(options['ssh-options']).each do |key, value|
        ssh_options[key.to_sym] = value
      end
    end

    ssh_config = options['ssh-config']

    if ssh_config
      ssh_config = File.expand_path(ssh_config)
      ssh_options[:config] = ssh_config if File.exist?(ssh_config)
    end

    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.connection_timeout = conn_timeout if conn_timeout
      ssh.ssh_options = ssh_options unless ssh_options.empty?
    end
  end
end
