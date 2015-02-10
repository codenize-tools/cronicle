class Cronicle::Client
  include Cronicle::Logger::Helper

  DEFAULTS = {
    :concurrency => 10,
    :var_dir => '/var/lib/cronicle'
  }

  def initialize(host_list, options = {})
    @host_list = host_list
    @options = DEFAULTS.merge(options)
  end

  def apply(file)
    walk(file)
  end

  def exec(file, name)
    name = name.to_s
    jobs = load_file(file)
    jobs_by_host = select_host(jobs, name)

    if jobs_by_host.empty?
      raise "Definition cannot be found: Job `#{name}`"
    end

    parallel_each(jobs_by_host) do |host, jobs_by_user|
      if @options[:ssh_user] and host !~ /@/
        host = @options[:ssh_user] + '@' + host
      end

      run_driver(host) do |driver|
        jobs_by_user.each do |user, jobs|
          driver.execute_job(user, jobs)
        end
      end
    end
  end

  private

  def walk(file)
    jobs = load_file(file)
    jobs_by_host = select_host(jobs)
    exported = export_cron(jobs_by_host.keys)
    walk_hosts(jobs_by_host, exported)
  end

  def export_cron(host_list)
    driver = Cronicle::Driver.new(host_list, @options)
    Cronicle::Exporter.export(driver, @options)
  end

  def walk_hosts(jobs_by_host, exported)
    parallel_each(jobs_by_host) do |host, jobs_by_user|
      exported_by_user = exported.delete(host) || {}
      walk_host(host, jobs_by_user, exported_by_user)
    end

    parallel_each(exported) do |host, exported_by_user|
      run_driver(host) do |driver|
        scripts_by_user = {}

        exported_by_user.each do |user, scripts|
          scripts_by_user[user] = scripts
        end

        driver.delete_job(scripts_by_user)
      end
    end
  end

  def walk_host(host, jobs_by_user, exported_by_user)
    run_driver(host) do |driver|
      jobs_by_user.each do |user, jobs|
        scripts = exported_by_user.delete(user) || {}
        walk_jobs(driver, user, jobs, scripts)
      end

      exported_by_user.each do |user, scripts|
        driver.delete_job(user => scripts)
      end
    end
  end

  def walk_jobs(driver, user, jobs, cron_cmds)
    jobs.each do |name, job|
      next unless job[:schedule]
      current_cmd = cron_cmds.delete(name)

      if current_cmd
        driver.update_job(user, name, job, current_cmd)
      else
        driver.create_job(user, name, job)
      end
    end

    cron_cmds.each do |name, current_cmd|
      driver.delete_job(user => {name => current_cmd})
    end
  end

  def run_driver(host)
    driver = Cronicle::Driver.new(Array(host), @options)

    if driver.test_sudo
      yield(driver)
    end
  end

  def select_host(jobs, target_name = nil)
    hosts = Hash.new do |jobs_by_host, host|
      jobs_by_host[host] = Hash.new do |jobs_by_user, user|
        jobs_by_user[user] = {}
      end
    end

    jobs.each do |job|
      job_hash = job[:job]
      job_user = job_hash[:user]
      job_name = job_hash[:name]
      servers = job[:servers]

      if target_name and job_name != target_name
        next
      end

      selected_hots = @host_list.select(
        :servers => servers,
        :roles => job[:roles]
      )

      # Add hosts that is defined in DSL
      dsl_hosts = servers.select {|srvr|
        srvr.kind_of?(String) or srvr.kind_of?(Symbol)
      }.map(&:to_s)

      (selected_hots + dsl_hosts).uniq.each do |h|
        if hosts[h][job_user][job_name]
          log(:warn, "Job is duplicated", :color => :yellow, :host => h, :user => job_user, :job => job_name)
        elsif job_name.nil?
          hosts[h] = {}
        else
          hosts[h][job_user][job_name] = job_hash
        end
      end
    end

    hosts
  end

  def load_file(file)
    if file.kind_of?(String)
      open(file) do |f|
        Cronicle::DSL.parse(f.read, file, @options)
      end
    elsif [File, Tempfile].any? {|i| file.kind_of?(i) }
      Cronicle::DSL.parse(file.read, file.path, @options)
    else
      raise TypeError, "Cannot convert #{file} into File"
    end
  end

  def parallel_each(enum, &block)
    Parallel.each(enum, :in_threads => @options[:concurrency], &block)
  end
end
