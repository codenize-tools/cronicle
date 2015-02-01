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
      message = "[#{level.to_s.upcase}] #{message}" unless level == :info
      message << ' (dry-run)' if opts[:dry_run]
      message = message.send(opts[:color]) if opts[:color]

      logger = opts[:logger] || Cronicle::Logger.instance
      logger.send(level, message)
    end
  end # of class methods

  class SSHKitIO
    def initialize(io = $stdout)
      @io = io
    end

    def <<(obj)
      @io << mask_password(obj)
    end

    private

    MASK_REGEXP = /\becho\s+([^|]+)\s+\|\s+sudo\s+-S\s+/
    MASK = 'XXXXXXXX'

    def mask_password(obj)
      if obj.kind_of?(String) and obj =~ MASK_REGEXP
        password = $1
        obj.sub(password, MASK)
      else
        obj
      end
    end
  end
end

SSHKit.config.output = SSHKit::Formatter::Pretty.new(Cronicle::Logger::SSHKitIO.new)
SSHKit.config.output_verbosity = :warn