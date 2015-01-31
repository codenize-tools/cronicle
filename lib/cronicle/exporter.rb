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
    crontabs_by_host = {}
    drvr = @driver

    @driver.execute do |host|
      cron_dir = drvr.find_cron_dir {|cmd| capture(*cmd) }
      crontabs = drvr.list_crontabs(cron_dir) {|cmd| capture(*cmd) }
      crontab_by_user = drvr.fetch_crontabs(cron_dir, crontabs) {|cmd| capture(*cmd).gsub("\r\n", "\n") }
      crontabs_by_host[host.hostname] = crontab_by_user
    end

    parse_crontab(crontabs_by_host)
  end

  private

  def parse_crontab(crontabs_by_host)
    crontabs_by_host.each do |host, crontab_by_user|
      crontab_by_user.keys.each do |user|
        crontab_by_user[user] = Cronicle::CronParser.parse(
          crontab_by_user[user],
          @options.fetch(:libexec)
        )
      end
    end

    crontabs_by_host
  end
end
