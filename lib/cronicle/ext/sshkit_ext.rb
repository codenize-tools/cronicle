SSHKit::Backend::Netssh.config.pty = true

class SSHKit::Backend::Netssh
  SUDO_PASSWORD_KEY = :'__cronicle_sudo_password__'
  SUDO_PROMPT = '__cronicle_sudo_prompt__'

  alias _execute_orig _execute

  def output
    @output ||= SSHKit.config.output
  end

  def _execute(*args)
    options = args.last.kind_of?(Hash) ? args.last : {}
    orig_output = output

    begin
      if options[:sniffer]
        @output = Cronicle::LogSniffer.new(orig_output) do |obj|
          options[:sniffer].call(obj)
        end
      end

      _execute_orig(*args)
    rescue => e
      log_for_cronicle(:error, args.join(' '), :color => :red)
      raise e
    ensure
      @output = orig_output
    end
  end

  def sudo(command, *args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}

    retval = with_sudo_password(host.options[:sudo_password] || '') do
      with_sudo = [:sudo, '-p', SUDO_PROMPT, '-S']
      with_sudo << :sudo << '-u' << opts[:user] if opts[:user]
      with_sudo.concat(args)
      send(command, *with_sudo, opts)
    end

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
    @crontab_list ||= sudo(:capture, :bash, '-c',
                        Shellwords.shellescape("find #{cron_dir} -type f 2> /dev/null"),
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
    sed_cmd = '/' + Cronicle::Utils.sed_escape(script_path(user, name)) + ' /d'
    sed_cmd = Shellwords.shellescape(sed_cmd)

    sudo(:execute, :sed, '-i', sed_cmd, user_crontab(user), :raise_on_non_zero_exit => false)
  end

  def add_cron_entry(user, name, schedule, temp_dir, bundle_gems = nil)
    script = script_path(user, name)
    temp_entry = [temp_dir, name + '.entry'].join('/')

    cron_entry = "#{schedule}\\t"

    if bundle_gems
      cron_entry << "cd #{gemfile_dir(user, name)} && #{bundler_path} exec "
    end

    cron_entry << "#{script} 2>&1 | logger -t cronicle/#{user}/#{name}"
    cron_entry = Shellwords.shellescape(cron_entry)
    sudo(:execute, :echo, '-e', cron_entry, '>', temp_entry)

    entry_cat = "cat #{temp_entry} >> #{user_crontab(user)}"
    entry_cat = Shellwords.shellescape(entry_cat)
    sudo(:execute, :bash, '-c', entry_cat)
  end

  def upload_script(temp_dir, name, content)
    temp_script = [temp_dir, name].join('/')
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
      sudo(:execute, :rm, '-rf', temp_dir, :raise_on_non_zero_exit => false) rescue nil
    end
  end

  def mkgemfile(user, name, bundle_gems, temp_dir = nil)
    sudo(:execute, :mkdir, '-p', gemfile_dir(user, name, temp_dir))
    sudo(:execute, :bash, '-c',
      Shellwords.shellescape(
        [:echo, Shellwords.shellescape("source 'https://rubygems.org'"), '>', gemfile(user, name, temp_dir)].join(' ')
      )
    )

    bundle_gems.each do |gem_name, version|
      line = "gem '#{gem_name}'"
      line << ", #{version.inspect}" if version
      sudo(:execute, :bash, '-c',
        Shellwords.shellescape(
          [:echo, Shellwords.shellescape(line), '>>', gemfile(user, name, temp_dir)].join(' ')
        )
      )
    end
  end

  def bundle(user, name, temp_dir = nil)
    with_bundle(user, name, temp_dir) do |bundler_opts|
      unless sudo(:execute, bundler_path, :check, *bundler_opts, :raise_on_non_zero_exit => false)
        sudo(:execute, bundler_path, :install, *bundler_opts)
      end
    end
  end

  def with_bundle(user, name, temp_dir = nil)
    within gemfile_dir(user, name, temp_dir) do
      bundler_opts = ['--no-color', '--gemfile', gemfile(user, name, temp_dir), '--path', bundle_dir]
      yield(bundler_opts)
    end
  end

  def libexec_dir
    host.options.fetch(:var_dir) + '/libexec'
  end

  def run_dir
    host.options.fetch(:var_dir) + '/run'
  end

  def bundle_dir
    host.options.fetch(:var_dir) + '/bundle'
  end

  BUNDLER_PATHS = %w(
    /usr/local/bin/bundle
    /usr/bin/bundle
  )

  def bundler_path
    @bundler_path ||= BUNDLER_PATHS.find {|path|
      execute(:test, '-f', path, :raise_on_non_zero_exit => false)
    }

    path = capture(:which, :bundle, '2>', '/dev/null', :raise_on_non_zero_exit => false) || ''
    path.strip!

    if path.empty?
      log_for_cronicle(:error, 'cannot find bundler', :color => :red, :host => host.hostname)
    else
      @bundler_path = path
    end

    @bundler_path
  end

  def user_libexec_dir(user)
    [libexec_dir, user].join('/')
  end

  def user_run_dir(user)
    [run_dir, user].join('/')
  end

  def gemfile_dir(user, name, temp_dir = nil)
    if temp_dir
      [temp_dir, user, name].join('/')
    else
      [user_run_dir(user), name].join('/')
    end
  end

  def gemfile(user, name, temp_dir = nil)
    [gemfile_dir(user, name, temp_dir), 'Gemfile'].join('/')
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

  def with_sudo_password(password)
    begin
      Thread.current[SUDO_PASSWORD_KEY] = password
      yield
    ensure
      Thread.current[SUDO_PASSWORD_KEY] = nil
    end
  end
end

class SSHKit::Host
  attr_reader :options
end
