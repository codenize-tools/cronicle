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
    libexec_dir = @options.fetch(:var_dir) + '/libexec'

    crontab.each_line.map(&:strip).each do |line|
      next if line =~ /\A#/

      md = line.match(/\A(@\w+|\S+(?:\s+\S+){4})\s+(?:cd\s+\S+\s+&&\s+\S*bundle\s+exec\s+)?(.\S+)(.*)\z/)
      schedule, path, extra = md.captures if md

      if %r|\A#{Regexp.escape(libexec_dir)}/(?:[^/]+)/(.+)| =~ path
        name = $1

        if libexec_contents[path]
          libexec_contents[path].force_encoding('utf-8')
        end

        scripts[name] = {
          :schedule => schedule,
          :path => path,
          :content => libexec_contents[path]
        }
      end
    end

    scripts
  end
end
