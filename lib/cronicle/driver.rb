SSHKit::Backend::Netssh.config.pty = true

class Cronicle::Driver
  CRON_DIRS = %w(/var/spool/cron/crontabs /var/spool/cron)

  attr_reader :hosts

  def initialize(hosts, options = nil)
    @hosts = hosts
    @options = options
  end

  def execute(&block)
    coordinator = SSHKit::Coordinator.new(@hosts)
    hosts = coordinator.hosts

    hosts.each do |host|
      host.instance_variable_set(:@options, @options)
    end

    # XXX: To parallelize
    runner_opts = @options[:runner_options] || {}
    SSHKit::Runner::Sequential.new(hosts, runner_opts, &block).execute
  end

  def export_crontab
    crontabs_by_host = {}
    libexec_by_host = {}

    execute do
      crontabs_by_host[host.hostname] = fetch_crontabs
      libexec_by_host[host.hostname] = fetch_libexec_scripts
    end

    [crontabs_by_host, libexec_by_host]
  end

  def execute_job(user, jobs)
    driver = self

    self.execute do |host|
      temp_dir = capture(:mktemp, '-d', '/var/tmp/cronicle.XXXXXXXXXX')

      begin
        execute(:chmod, 755, temp_dir)

        jobs.each do |name, job|
          job_path = "#{temp_dir}/#{name}"
          upload!(StringIO.new(job[:content]), job_path)
          execute(:chmod, 755, job_path)
          # XXX:
          out = driver.sudo(job_path) {|cmd| capture(*cmd).gsub("\r\n", "\n") }
          puts out
        end
      ensure
        execute(:rm, '-rf', temp_dir) rescue nil
      end
    end
  end

  def create_job(user, name, job)
    create_or_update_job(user, name, job)
  end

  def update_job(user, name, job, current_cmd)
    create_or_update_job(user, name, job, current_cmd)
  end

  def create_or_update_job(user, name, job, current_cmd = nil)
    driver = self
    opts = @options

    self.execute do |host|
      temp_dir = capture(:mktemp, '-d', '/var/tmp/cronicle.XXXXXXXXXX')

      begin
        user_temp_dir = "#{temp_dir}/#{user}"
        execute(:mkdir, '-p', user_temp_dir)
        cron_dir = driver.find_cron_dir {|cmd| capture(*cmd) }
        crontab = "#{cron_dir}/#{user}"
        user_libexec = "#{opts[:libexec]}/#{user}"
        job_path = "#{user_libexec}/#{name}"
        temp_job_path = "#{user_temp_dir}/#{name}"
        temp_entry_path = "#{temp_job_path}.entry"

        upload!(StringIO.new(job[:content]), temp_job_path)
        driver.sudo(:mkdir, '-p', user_libexec) {|cmd| execute(*cmd) }

        cron_entry_exist = driver.find_cron_entry(job_path, crontab) {|cmd| execute(*cmd, :raise_on_non_zero_exit => false) }
        job_file_exist = execute(:test, '-e', job_path, :raise_on_non_zero_exit => false)

        if job_file_exist
          delta = capture(:diff, '-u', job_path, temp_job_path, :raise_on_non_zero_exit => false).gsub("\r\n", "\n")
          delta.strip!
        end

        if not cron_entry_exist or not job_file_exist or not delta.empty?
          # XXX:
          if current_cmd
            Cronicle::Logger.log(:info, "Update", opts.merge(:color => :green))
          else
            Cronicle::Logger.log(:info, "Create", opts.merge(:color => :cyan))
          end

          driver.sudo(:cp, temp_job_path, job_path) {|cmd| execute(*cmd) }
          driver.sudo(:chmod, 755, job_path) {|cmd| execute(*cmd) }

          driver.sudo(:touch, crontab) {|cmd| execute(*cmd) }
          driver.delete_cron_entry(job_path, crontab) {|cmd| execute(*cmd, :raise_on_non_zero_exit => false) }
          driver.create_temp_entry(job_path, crontab, temp_entry_path, name, job[:schedule]) {|cmd| execute(*cmd) }
          driver.add_cron_entry(crontab, temp_entry_path) {|cmd| execute(*cmd) }
        end
      ensure
        execute(:rm, '-rf', temp_dir) rescue nil
      end
    end
  end

  def delete_job(scripts_by_user, name = nil)
    driver = self
    opts = @options

    self.execute do
      scripts_by_user.each do |user, scripts|
        scripts = scripts.map {|name, script| script[:path] }

        unless scripts.empty?
          # XXX:
          log_msg = "Delete: Host `#{host.short_name}` > User `#{user}`"
          log_msg << " > Job `#{name}`" if name
          log_for_cronicle(:info, log_msg, :color => :red)

          delete_cron_entry(user, name)
          sudo(:execute, :rm, '-f', *scripts, :raise_on_non_zero_exit => false)
        end
      end
    end
  end

  # command helper ##################################################

  def sudo(*args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}
    sudo_password = @options[:sudo_password] || ''
    sudo_password = Cronicle::Utils.sh_quote(sudo_password)
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
      crontab = sudo(:cat, File.join(cron_dir, user)) do |cmd|
        yield(cmd)
      end

      crontab_by_user[user] =crontab
    end

    crontab_by_user
  end

  def fetch_libexec(scripts)
    contents = {}

    scripts.each do |script|
      contents[script] = yield([:cat, script])
    end

    contents
  end

  def find_cron_entry(job_path, crontab)
    job_path = Cronicle::Utils.sh_quote(job_path)
    sudo(:fgrep, '-q', job_path, crontab) {|cmd| yield(cmd) }
  end

  def delete_cron_entry(job_path, crontab)
    sed_cmd = '/' + Cronicle::Utils.sed_escape(job_path) + '/d'
    sed_cmd = Cronicle::Utils.sh_quote(sed_cmd)
    sudo(:sed, '-i', sed_cmd, crontab) {|cmd| yield(cmd) }
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
