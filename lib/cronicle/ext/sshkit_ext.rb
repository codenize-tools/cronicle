SSHKit::Backend::Netssh.config.pty = true

class SSHKit::Backend::Netssh
  def sudo(command, *args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}

    password = host.options[:sudo_password] || ''
    password = Shellwords.shellescape(password)

    with_sudo = [:echo, password, '|', :sudo, '-S']
    with_sudo << '-u' << opts[:user] if opts[:user]
    with_sudo.concat(args)

    raise_on_non_zero_exit = opts.fetch(:raise_on_non_zero_exit, true)
    retval = send(command, *with_sudo, :raise_on_non_zero_exit => raise_on_non_zero_exit)
    Cronicle::Utils.remove_prompt!(retval) if retval.kind_of?(String)
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
    @crontab_list ||= sudo(:capture, :find, cron_dir, '-type', :f, '-maxdepth', 1, '2> /dev/null',
                        :raise_on_non_zero_exit => false).each_line.map(&:strip)
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
    @libexec_scripts ||= capture(:find, libexec_dir, '-type', :f, '2> /dev/null',
                           :raise_on_non_zero_exit => false).each_line.map(&:strip)
  end

  def fetch_libexec_scripts
    script_contents = {}

    list_libexec_scripts.each do |script|
      script_contents[script] = crlf_to_lf(capture(:cat, script))
    end

    script_contents
  end

  def delete_cron_entry(user, name = nil)
    sed_cmd = '/' + Cronicle::Utils.sed_escape(script_path(user, name)) + '/d'
    sed_cmd = Shellwords.shellescape(sed_cmd)

    sudo(:execute, :sed, '-i', sed_cmd, user_crontab(user), :raise_on_non_zero_exit => false)
  end

  def add_cron_entry(user, name, schedule, temp_dir)
    script = script_path(user, name)
    temp_entry = [temp_dir, name + '.entry'].join('/')

    cron_entry = "#{schedule}\\t#{script} 2>&1 | logger -t cronicle/#{user}/#{name}"
    cron_entry = Shellwords.shellescape(cron_entry)
    sudo(:execute, :echo, '-e', cron_entry, '>', temp_entry)

    entry_cat = "cat #{temp_entry} >> #{user_crontab(user)}"
    entry_cat = Shellwords.shellescape(entry_cat)
    sudo(:execute, :bash, '-c', entry_cat)
  end

  def upload_script(temp_dir, name, content)
    temp_script = [temp_dir, name].join
    upload!(StringIO.new(content), temp_script)
    execute(:chmod, 755, temp_script)
    yield(temp_script)
  end

  def mktemp(user = nil)
    temp_dir = capture(:mktemp, '-d', '/var/tmp/cronicle.XXXXXXXXXX')
    block_args = [temp_dir]

    begin
      execute(:chmod, 755, temp_dir)

      if user
        user_temp_dir = [temp_dir, user].join('/')
        execute(:mkdir, '-p', user_temp_dir)
        execute(:chmod, 755, user_temp_dir)
        block_args << user_temp_dir
      end

      yield(*block_args)
    ensure
      execute(:rm, '-rf', temp_dir, :raise_on_non_zero_exit => false) rescue nil
    end
  end

  def libexec_dir
    host.options.fetch(:libexec)
  end

  def user_libexec_dir(user)
    [libexec_dir, user].join('/')
  end

  def user_crontab(user)
    cron_dir = find_cron_dir
    [cron_dir, user].join('/')
  end

  def script_path(user, name)
    [libexec_dir, user, name].join('/')
  end

  def log_for_cronicle(level, message, opts = {})
    opts = host.options.merge(opts)
    Cronicle::Logger.log(level, message, opts)
  end

  private

  def crlf_to_lf(str)
    str.gsub("\r\n", "\n")
  end
end

class SSHKit::Host
  attr_reader :options
end
