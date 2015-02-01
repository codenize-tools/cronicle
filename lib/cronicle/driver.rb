SSHKit::Backend::Netssh.config.pty = true

class Cronicle::Driver
  CRON_DIRS = %w(/var/spool/cron/crontabs /var/spool/cron)

  def initialize(hosts, options = nil)
    @hosts = hosts
    @options = options
  end

  def execute(opts = {}, &block)
    coordinator = SSHKit::Coordinator.new(@hosts)
    hosts = coordinator.hosts
    # XXX: To parallelize
    SSHKit::Runner::Sequential.new(hosts, opts, &block).execute
  end

  # command helper ##################################################

  def sudo(*args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}
    sudo_password = @options[:sudo_password] || ''
    sudo_cmd = [:echo, sudo_password, '|', :sudo, '-S']
    sudo_cmd.concat ['-u', opts[:user]] if opts[:user]
    retval = yield(sudo_cmd + args)

    if retval.kind_of?(String)
      retval.sub!(/\A[^:]*:\s*/, '')
    end

    retval
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

  def delete_cron_entry(job_path, crontab)
    sed_cmd = '/' + Cronicle::Utils.sed_escape(job_path) + '/d'
    sed_cmd = Cronicle::Utils.sh_quote(sed_cmd)
    sudo(:sed, '-i', sed_cmd, crontab, :raise_on_non_zero_exit => false) {|cmd| yield(cmd) }
  end

  def create_temp_entry(job_path, crontab, temp_entry_path, name, schedule)
    cron_entry = "#{schedule}\\t#{job_path} 2>&1 | logger -t cronicle/#{name}"
    cron_entry = Cronicle::Utils.sh_quote(cron_entry)
    sudo(:echo, '-e', cron_entry, '>', temp_entry_path) {|cmd| yield(cmd) }
  end

  def add_cron_entry(crontab, temp_entry_path)
    entry_cat = "cat #{temp_entry_path} >> #{crontab}"
    entry_cat = Cronicle::Utils.sh_quote(entry_cat)
    sudo(:bash, '-c', entry_cat) {|cmd| yield(cmd) }
  end
end
