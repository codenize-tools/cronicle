class Cronicle::Logger < ::Logger
  include Singleton

  def initialize
    super($stdout)

    self.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    self.level = INFO
  end

  def set_debug(value)
    if value
      self.level = DEBUG
      SSHKit.config.output_verbosity = :debug
    else
      self.level = INFO
      SSHKit.config.output_verbosity = :warn
    end
  end

  class << self
    def log(level, message, opts = {})
      message = "#{level.to_s.downcase}: #{message}" unless level == :info
      message << ' (dry-run)' if opts[:dry_run]
      message.gsub!(/\s+\z/, '')
      message = message.send(opts[:color]) if opts[:color]

      job_info = ''

      if opts[:job]
        job_info << opts[:job]
      end

      host_user = [:host, :user].map {|key|
        value = opts[key]
        next unless value
        value = Cronicle::Utils.short_hostname(value) if key == :host
        value
      }.compact

      unless host_user.empty?
        job_info << ' on ' unless job_info.empty?
        job_info << host_user.join('/')
      end

      unless job_info.empty?
        job_info = "#{job_info}>".light_black
        message = "#{job_info} #{message}"
      end

      logger = opts[:logger] || Cronicle::Logger.instance
      logger.send(level, message)
    end
  end # of class methods

  # XXX:
  module Helper
    def log(level, message, opts = {})
      opts = (@options || {}).merge(opts)
      Cronicle::Logger.log(level, message, opts)
    end
  end
end

SSHKit.config.output_verbosity = :warn
