class Cronicle::Client
  def initialize(host_list, options = {})
    @host_list = host_list
    @options = options
  end

  def apply(file, options = {})
    walk(file)
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
    # XXX: To parallelize
    jobs_by_host.each do |host, jobs_by_user|
      exported_by_user = exported.delete(host) || {}
      walk_host(host, jobs_by_user, exported_by_user)
    end

    # XXX: To parallelize
    exported.each do |host, exported_by_user|
      run_driver(host) do |driver|
        delete_job(driver)
      end
    end
  end

  def walk_host(host, jobs_by_user, exported_by_user)
    run_driver(host) do |driver|
      jobs_by_user.each do |user, jobs|
        cron = exported_by_user.delete(user) || {:commands => {}}
        walk_jobs(driver, user, jobs, cron[:commands])
      end

      exported_by_user.each do |user, cron|
        cron_cmds = cron[:commands]
        delete_job(driver, user)
      end
    end
  end

  def walk_jobs(driver, user, jobs, cron_cmds)
    jobs.each do |name, job|
      next unless job[:schedule]
      current_cmd = cron_cmds.delete(name)

      if current_cmd
        update_job(driver, user, name, job, current_cmd)
      else
        create_job(driver, user, name, job)
      end
    end

    cron_cmds.each do |name, current_cmd|
      delete_job(driver, user, name)
    end
  end

  def create_job(driver, user, name, job)
    # XXX:
    p :create_job, name
  end

  def update_job(driver, user, name, job, current_cmd)
    # XXX:
    p :update_job, name
  end

  def delete_job(driver, user = nil, name = nil)
    # XXX:
    p :delete_job, name
  end

  def run_driver(host)
    driver = Cronicle::Driver.new([host], @options)
    yield(driver)
  end

  def select_host(jobs)
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
          raise "`Host #{h}` > User `#{user}` > Job `#{job_name}`: already defined"
        end

        hosts[h][job_user][job_name] = job_hash
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
      raise TypeError, "Can not convert #{file} into File"
    end
  end
end
