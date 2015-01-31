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
    driver = Cronicle::Driver.new(jobs_by_host.keys, @options)
    exported = Cronicle::Exporter.export(driver, @options)
    walk_hosts(driver, jobs_by_host, exported)
  end

  def walk_hosts(driver, jobs_by_host, exported)
    jobs_by_host.each do |host, jobs_by_user|
      exported_by_user = exported.delete(host) || {}
      walk_host(driver, host, jobs_by_user, exported_by_user)
    end

    exported.each do |host, exported_by_user|
      # XXX: Cleanup jobs
    end
  end

  def walk_host(driver, host, jobs_by_user, exported_by_user)
    jobs_by_user.each do |user, jobs|
      cron = exported_by_user.delete(user) || {:commands => {}}
      walk_jobs(driver, host, user, jobs, cron[:commands])
    end

    exported_by_user.each do |user, cron_cmds|
      # XXX: Cleanup jobs
    end
  end

  def walk_jobs(driver, host, user, jobs, cron_cmds)
    # XXX:
    p jobs
    p cron_cmds
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
