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

    runner_opts = @options[:runner_options] || {}
    runner = SSHKit::Runner::Group.new(hosts, runner_opts, &block)
    runner.group_size = @options[:concurrency]
    runner.execute
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

    execute do |host|
      mktemp do |temp_dir|
        jobs.each do |name, job|
          upload_script(temp_dir, name, job[:content]) do |temp_script|
            command = sudo(:_execute, temp_script, :raise_on_non_zero_exit => false)
            out = command.full_stdout
            Cronicle::Utils.remove_prompt!(out)

            put_log = proc do |level, opts|
              opts ||= {}

              out.each_line do |line|
                log_for_cronicle(:info, line.strip, opts.merge(:host => host.short_name))
              end
            end

            if command.exit_status.zero?
              put_log.call(:info)
            else
              put_log.call(:error, :color => :red)
            end
          end
        end
      end
    end
  end

  def create_job(user, name, job)
    create_or_update_job(user, name, job)
  end

  def update_job(user, name, job, script)
    job_content = job[:content].chomp
    script_content = script[:content].chomp

    if job_content != script_content
      create_or_update_job(user, name, job, script)
    end
  end

  def create_or_update_job(user, name, job, script = nil)
    execute do
      # XXX:
      log_msg = "Host `#{host.short_name}` > User `#{user}` > Job `#{name}`"

      if script
        log_for_cronicle(:info, "Update: #{log_msg}", :color => :green)
      else
        log_for_cronicle(:info, "Create: #{log_msg}", :color => :cyan)
      end

      mktemp(user) do |temp_dir, user_temp_dir|
        libexec_script = script_path(user, name)

        upload_script(temp_dir, name, job[:content]) do |temp_script|
          temp_entry = temp_script + '.entry'
          sudo(:execute, :mkdir, '-p', user_libexec_dir(user))
          sudo(:execute, :cp, temp_script, libexec_script)
          sudo(:execute, :touch, user_crontab(user))
          delete_cron_entry(user, name)
          add_cron_entry(user, name, job[:schedule], user_temp_dir)
        end
      end
    end
  end

  def delete_job(scripts_by_user, name = nil)
    execute do
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
end
