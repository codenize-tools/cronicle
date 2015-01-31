class Cronicle::Client
  def initialize(host_list, options = {})
    @host_list = host_list
    @options = options
  end

  def apply(file)
    walk(file)
  end

  def run(file, name)
    name = name.to_s
    jobs = load_file(file)
    jobs_by_host = select_host(jobs, name)

    # XXX: To parallelize
    jobs_by_host.each do |host, jobs_by_user|
      run_driver(host) do |driver|
        jobs_by_user.each do |user, jobs|
          run_jobs(driver, user, jobs)
        end
      end
    end
  end

  private

  def run_jobs(driver, user, jobs)
    driver.execute do |host|
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

  def walk(file)
    jobs = load_file(file)
    jobs_by_host = select_host(jobs)
    exported = export_cron
    walk_hosts(jobs_by_host, exported)
  end

  def export_cron
    driver = Cronicle::Driver.new(@host_list.all, @options)
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
        cmds_by_user = Hash.new {|hash, key| hash[key] = []}

        exported_by_user.each do |user, cron_cmds|
          cmds_by_user[user] = cron_cmds[:commands]
        end

        delete_job(driver, cmds_by_user)
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
        delete_job(driver, user => cron_cmds[:commands])
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
      delete_job(driver, user => {name => current_cmd})
    end
  end

  def create_job(driver, user, name, job)
    # XXX:
    p :create_job, user, name
    create_or_update_job(driver, user, name, job)
  end

  def update_job(driver, user, name, job, current_cmd)
    # XXX:
    p :update_job, user, name
    create_or_update_job(driver, user, name, job)
  end

  def create_or_update_job(driver, user, name, job)
    opts = @options

    driver.execute do |host|
      temp_dir = capture(:mktemp, '-d', '/var/tmp/cronicle.XXXXXXXXXX')

      begin
        cron_dir = driver.find_cron_dir {|cmd| capture(*cmd) }
        job_path = "#{opts[:libexec]}/#{name}"
        temp_job_path = "#{temp_dir}/#{name}"
        temp_entry_path = "#{temp_job_path}.entry"

        upload!(StringIO.new(job[:content]), temp_job_path)
        driver.sudo(:mkdir, '-p', opts[:libexec]) {|cmd| execute(*cmd) }

        delta = capture(:diff, '-u', job_path, temp_job_path, '||', true).gsub("\r\n", "\n")

        # XXX:
        puts delta

        unless delta.empty?
          driver.sudo(:cp, temp_job_path, job_path) {|cmd| execute(*cmd) }
          driver.sudo(:chmod, 755, job_path) {|cmd| execute(*cmd) }

          driver.sudo(:touch, "#{cron_dir}/#{user}") {|cmd| execute(*cmd) }
          driver.delete_cron_entry(job_path, "#{cron_dir}/#{user}") {|cmd| execute(*cmd) }
          driver.create_temp_entry(job_path, "#{cron_dir}/#{user}", temp_entry_path, name, job[:schedule]) {|cmd| execute(*cmd) }
          driver.add_cron_entry("#{cron_dir}/#{user}", temp_entry_path) {|cmd| execute(*cmd) }
        end
      ensure
        execute(:rm, '-rf', temp_dir) rescue nil
      end
    end
  end

  def delete_job(driver, cmds_by_user, name = nil)
    # XXX:
    p :delete_job

    opts = @options

    driver.execute do
      cmds_by_user.each do |user, commands|
        commands = commands.map {|name, c| c[:command] }

        unless commands.empty?
          cron_dir = driver.find_cron_dir {|cmd| capture(*cmd) }
          driver.delete_cron_entry("#{opts[:libexec]}/#{name}", "#{cron_dir}/#{user}") {|cmd| execute(*cmd) }
          driver.sudo(:rm, *commands, '||', true) {|cmd| execute(*cmd) }
        end
      end
    end
  end

  def run_driver(host)
    driver = Cronicle::Driver.new(Array(host), @options)
    yield(driver)
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
