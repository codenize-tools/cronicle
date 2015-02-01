class Cronicle::CLI < Thor
  class_option 'file', :aliases => '-f', :default => 'Cronfile',
    :desc => 'Job definition file'
  class_option 'hosts', :aliases => '-h',
    :desc => 'Hosts definition file'
  class_option 'target-roles', :aliases => '-r', :type => :array,
    :desc => 'Target host role list'
  class_option 'sudo-password', :aliases => '-p',
    :desc => 'Sudo password'
  class_option 'libexec', :default => '/var/lib/cronicle/libexec',
    :desc => 'cronicle libexec path'

  desc 'exec JOB_NAME', 'Execute a job on remote hosts'
  def exec(job_name)
    client.exec(cronfile, job_name)
  end

  private

  def client
    Cronicle::Client.new(host_list, client_options)
  end

  def cronfile
    file = options['file']

    unless File.exist?(file)
      raise Thor::Error, "No Cronfile found (looking for: #{file})"
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
