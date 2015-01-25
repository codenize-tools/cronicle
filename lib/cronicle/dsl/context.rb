class Cronicle::DSL::Context
  class << self
    def eval(dsl, path, opts = {})
      self.new(path, opts) {
        Kernel.eval(dsl, binding, path)
      }
    end
  end # of class methods

  attr_reader :result

  def initialize(path, options = {}, &block)
    @path = path
    @options = options
    @result = []
    instance_eval(&block)
  end

  def require(file)
    cronfile = (file =~ %r|\A/|) ? file : File.expand_path(File.join(File.dirname(@path), file))

    if File.exist?(cronfile)
      instance_eval(File.read(cronfile), cronfile)
    elsif File.exist?(cronfile + '.rb')
      instance_eval(File.read(cronfile + '.rb'), cronfile + '.rb')
    else
      Kernel.require(file)
    end
  end

  def on(target, &block)
    unless target.kind_of?(Hash)
      raise TypeError, "wrong argument type #{target.class} (expected Hash)"
    end

    if target.empty?
      raise ArgumentError, ':servers or :roles is not passed to `on` method'
    end

    target.assert_valid_keys(:servers, :roles)

    regexp_conv = proc do |key|
      if target[key]
        Regexp.union([target[key]].flatten.map {|str_or_reg|
          if str_or_reg.kind_of?(Regexp)
            str_or_reg
          else
            /\A#{str_or_reg}\z/
          end
        })
      else
        nil
      end
    end

    servers = regexp_conv.call(:servers)
    roles = regexp_conv.call(:roles)

    @result << Cronicle::DSL::Context::Job.new(:servers => servers, :roles => roles, &block)
  end
end
