SSHKit::Backend::Netssh.config.pty = true

class Cronicle::Driver
  CRON_DIRS = %w(/var/spool/cron/crontabs /var/spool/cron)

  def initialize(hosts, options = nil)
    @coordinator = SSHKit::Coordinator.new(hosts)
    @options = options
  end

  def execute(opts = {}, &block)
    hosts = @coordinator.hosts
    # XXX: To parallelize
    SSHKit::Runner::Sequential.new(hosts, opts, &block).execute
  end

  # command helper ##################################################

  def sudo(*args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}

    if @options[:sudo_password]
      sudo_cmd = [:echo, @options[:sudo_password], '|', :sudo, '-S']
      sudo_cmd.concat ['-u', opts[:user]] if opts[:user]
      retval = yield(sudo_cmd + args)

      if retval.kind_of?(String)
        retval.sub!(/\A[^:]*:\s*/, '')
      end

      retval
    else
      yield(args)
    end
  end

  def find_cron_dir
    cron_dir = CRON_DIRS.find do |path|
      cmd = [:test, '-d', path, ';', :echo, '$?']
      yield(cmd) == '0'
    end

    unless cron_dir
      raise "Can not find cron directory: #{CRON_DIRS.join(', ')}"
    end

    cron_dir
  end

  def list_crontabs(cron_dir)
    sudo(:ls, cron_dir) {|cmd|
      yield(cmd)
    }.split(/\s+/)
  end

  def fetch_crontabs(cron_dir, crontabs)
    crontab_by_user = {}

    crontabs.each do |user|
      crontab_by_user[user] = sudo(:cat, File.join(cron_dir, user)) do |cmd|
        yield(cmd)
      end
    end

    crontab_by_user
  end
end
