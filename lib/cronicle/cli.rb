class Cronicle::CLI < Thor
  class_option 'file', :aliases => '-f', :default => 'Jobfile',
    :desc => 'Job definition file'
  class_option 'hosts', :aliases => '-h',
    :desc => 'Hosts definition file'
  class_option 'target-roles', :aliases => '-r', :type => :array,
    :desc => 'Target host role list'
  class_option 'sudo-password', :aliases => '-p',
    :desc => 'Sudo password'
  class_option 'libexec', :default => '/var/lib/cronicle/libexec',
    :desc => 'Cronicle libexec path'
  class_option 'debug', :type => :boolean, :default => false,
    :desc => 'Debug mode'
  class_option 'color', :type => :boolean, :default => true,
    :desc => 'Colorize log'

  def initialize(*args)
    super
    @logger = Cronicle::Logger.instance

    if options['debug']
      @logger.set_debug(true)
    end

    if not $stdin.tty? or not options['color']
      String.disable_colorization = true
    end
  end

  desc 'exec JOB_NAME', 'Execute a job on remote hosts'
  def exec(job_name)
    with_logging do
      client.exec(jobfile, job_name)
    end
  end

  desc 'apply', 'Apply cron jobs to remote hosts'
  def apply
    with_logging do
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
        # XXX:
        $stderr.puts "[ERROR] #{e.message}"
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
      :libexec => options['libexec']
    }
  end

  def host_list_options
    {
      :roles => options['target-roles']
    }
  end
end
