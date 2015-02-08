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
    execute do
      mktemp do |temp_dir|
        jobs.each do |name, job|
          host_user_job = {:host => host.hostname, :user => user, :job => name}
          log_msg = 'Execute job'

          if host.options[:dry_run]
            content = job[:content].each_line.map {|l| ' ' + l }.join
            log_msg << "\n" << content.chomp << "\n"
            log_for_cronicle(:info, log_msg, host_user_job.merge(:color => :cyan))
            next
          else
            log_for_cronicle(:info, log_msg, host_user_job.merge(:color => :cyan))
          end

          upload_script(temp_dir, name, job[:content]) do |temp_script|
            command = sudo(:_execute, temp_script, :raise_on_non_zero_exit => false)
            out = command.full_stdout
            Cronicle::Utils.remove_prompt!(out)
            host_user_job = {:host => host.hostname, :user => user, :job => name}

            put_log = proc do |level, opts|
              opts ||= {}

              out.each_line do |line|
                log_for_cronicle(:info, line.strip, opts.merge(host_user_job))
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

    if [:schedule, :content].any? {|k| job[k].chomp != script[k].chomp }
      create_or_update_job(user, name, job, script)
    end
  end

  def create_or_update_job(user, name, job, script = nil)
    execute do
      host_user_job = {:host => host.hostname, :user => user, :job => name}
      content_orig = script ? script[:content] : ''
      delta = Cronicle::Utils.diff(content_orig, job[:content])

      if script
        log_for_cronicle(:info, "Update job: schedule=#{job[:schedule]}\n#{delta}", host_user_job.merge(:color => :green))
      else
        log_for_cronicle(:info, "Create job: schedule=#{job[:schedule]}\n#{delta}", host_user_job.merge(:color => :cyan))
      end

      unless host.options[:dry_run]
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
  end

  def delete_job(scripts_by_user, target_name = nil)
    execute do
      scripts_by_user.each do |user, scripts|
        scripts.each do |name, script|
          next if target_name && target_name != name

          host_user_job = {:host => host.hostname, :user => user, :job => name}
          log_msg = "Delete job: schedule=#{script[:schedule]}\n" + Cronicle::Utils.diff(script[:content], '')
          log_for_cronicle(:info, log_msg, host_user_job.merge(:color => :red))

          unless host.options[:dry_run]
            delete_cron_entry(user, name)
            sudo(:execute, :rm, '-f', script[:path], :raise_on_non_zero_exit => false)
          end
        end
      end
    end
  end

  def test_sudo
    ok = false

    execute do
      ok = sudo(:execute, :echo, :raise_on_non_zero_exit => false)

      unless ok
        log_for_cronicle(:error, 'incorrect sudo password', :color => :red, :host => host.hostname)
      end
    end

    ok
  end
end
