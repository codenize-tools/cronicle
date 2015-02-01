class Cronicle::Exporter
  class << self
    def export(driver, opts = {})
      self.new(driver, opts).export
    end
  end # of class methods

  def initialize(driver, options = {})
    @driver = driver
    @options = options
  end

  def export
    crontabs_by_host, libexec_by_host = @driver.export_crontab
    parse(crontabs_by_host, libexec_by_host)
  end

  private

  def parse(crontabs_by_host, libexec_by_host)
    crontabs_by_host.each do |host, crontab_by_user|
      libexec_contents = libexec_by_host[host] || {}

      crontab_by_user.keys.each do |user|
        crontab = crontab_by_user[user]
        crontab_by_user[user] = parse_crontab(crontab, libexec_contents)
      end
    end

    crontabs_by_host
  end

  def parse_crontab(crontab, libexec_contents)
    scripts = {}
    libexec_dir = @options.fetch(:libexec)

    crontab.each_line.map(&:strip).each do |line|
      next if line =~ /\A#/

      md = line.match(/\A(@\w+|\S+(?:\s+\S+){4})\s+(.\S+)(.*)\z/)
      schedule, command, extra = md.captures if md

      if %r|\A#{Regexp.escape(libexec_dir)}/(?:[^/]+)/(.+)| =~ command
        name = $1

        scripts[name] = {
          :schedule => schedule,
          :path => command,
          :content => libexec_contents[command]
        }
      end
    end

    scripts
  end
end
