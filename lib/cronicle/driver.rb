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

  def update_job(user, name, job, script)
    job_content = job[:content].chomp
    script_content = script[:content].chomp

    if job_content != script_content
      create_or_update_job(user, name, job, script)
    end
  end

  def create_or_update_job(user, name, job, script = nil)
    driver = self
    opts = @options

    execute do |host|
      mktemp(user) do |temp_dir, user_temp_dir|
        libexec_script = script_path(user, name)

        upload_script(temp_dir, name, job[:content]) do |temp_script|
          temp_entry = temp_script + '.entry'
          sudo(:execute, :mkdir, '-p', user_libexec_dir(user))

          # XXX:
          log_msg = "Host `#{host.short_name}` > User `#{user}` > Job `#{name}`"

          if script
            log_for_cronicle(:info, "Update: #{log_msg}", :color => :green)
          else
            log_for_cronicle(:info, "Create: #{log_msg}", :color => :cyan)
          end

          sudo(:execute, :cp, temp_script, libexec_script)
          sudo(:execute, :chmod, 755, libexec_script)
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
