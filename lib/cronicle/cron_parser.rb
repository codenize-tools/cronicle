class Cronicle::CronParser
  class << self
    def parse(source, libexec)
      parser = self.new(source, libexec)
      parser.parse

      {
        :commands => parser.commands,
        :others => parser.others,
      }
    end
  end # of class methods

  def initialize(source, libexec)
    @source = source
    @libexec = libexec
    @commands = {}
    @others = ''
  end

  attr_reader :commands
  attr_reader :others

  def parse
    @source.each_line do |line|
      if line =~ /\A\s*#/
        others << line
        next
      end

      md = line.strip.match(/\A(@\w+|\S+(?:\s+\S+){4})\s+(.\S+)(.*)\z/)
      schedule, command, extra = md.captures if md

      if %r|\A#{Regexp.escape(@libexec)}/(.+)| =~ command
        name = $1
        @commands[name] = {:schedule => schedule, :command => command}
      else
        @others << line
      end
    end
  end
end
