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
    parse_crontab(crontabs_by_host, libexec_by_host)
  end

  private

  def parse_crontab(crontabs_by_host, libexec_by_host)
    crontabs_by_host.each do |host, crontab_by_user|
      libexec_contents = libexec_by_host[host] || {}

      crontab_by_user.keys.each do |user|
        crontab = crontab_by_user[user]

        parsed_crontab = Cronicle::CronParser.parse(
          crontab,
          libexec_contents,
          @options.fetch(:libexec)
        )

        crontab_by_user[user] = parsed_crontab
      end
    end

    crontabs_by_host
  end
end
