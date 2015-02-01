SSHKit::Backend::Netssh.config.pty = true

class SSHKit::Backend::Netssh
  def sudo(command, *args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}

    password = host.options[:sudo_password] || ''
    password = Cronicle::Utils.sh_quote(password)

    with_sudo = [:echo, password, '|', :sudo, '-S']
    with_sudo << '-u' << opts[:user] if opts[:user]
    with_sudo.concat(args)

    raise_on_non_zero_exit = opts.fetch(:raise_on_non_zero_exit, true)
    retval = send(command, *with_sudo, :raise_on_non_zero_exit => raise_on_non_zero_exit)
    retval.sub!(/\A[^:]*:\s*/, '') if retval.kind_of?(String)
    retval
  end

  CRON_DIRS = %w(/var/spool/cron/crontabs /var/spool/cron)

  def find_cron_dir
    @cron_dir ||= CRON_DIRS.find do |path|
      execute(:test, '-d', path, :raise_on_non_zero_exit => false)
    end

    unless @cron_dir
      raise "Cannot find cron directory: #{CRON_DIRS.join(', ')}"
    end

    @cron_dir
  end

  def list_crontabs
    cron_dir = find_cron_dir
    @crontab_list ||= sudo(:capture, :find, cron_dir, '-type', :f, '-maxdepth', 1).each_line.map(&:strip)
  end

  def fetch_crontabs
    return @crontabs if @crontabs

    @crontabs = {}

    list_crontabs.each do |path|
      user = File.basename(path)
      crontab = sudo(:capture, :cat, path)
      @crontabs[user] = crontab
    end

    @crontabs
  end

  def list_libexec_scripts
    @libexec_scripts ||= capture(:find, libexec_dir, '-type', :f).each_line.map(&:strip)
  end

  def fetch_libexec_scripts
    script_contents = {}

    list_libexec_scripts.each do |script|
      script_contents[script] = capture(:cat, script)
    end

    script_contents
  end

  def delete_cron_entry(user, name = nil)
    cron_dir = find_cron_dir
    crontab = [cron_dir, user].join('/')
    script_path = [libexec_dir, user, name].join('/')

    sed_cmd = '/' + Cronicle::Utils.sed_escape(script_path) + '/d'
    sed_cmd = Cronicle::Utils.sh_quote(sed_cmd)

    sudo(:execute, :sed, '-i', sed_cmd, crontab, :raise_on_non_zero_exit => false)
  end

  def libexec_dir
    host.options.fetch(:libexec)
  end

  def log_for_cronicle(level, message, opts = {})
    opts = host.options.merge(opts)
    Cronicle::Logger.log(level, message, opts)
  end
end

class SSHKit::Host
  attr_reader :options

  IPADDR_REGEXP = /\A\d+(?:\.\d+){3}\z/

  def short_name
    if hostname =~ IPADDR_REGEXP
      hostname
    else
      hostname.split('.').first
    end
  end
end
