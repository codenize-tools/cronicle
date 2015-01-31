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
    unless block
      raise ArgumentError, "Block is required for `on` method"
    end

    unless target.kind_of?(Hash)
      raise TypeError, "wrong argument type #{target.class} (expected Hash)"
    end

    if target.empty?
      raise ArgumentError, ':servers or :roles is not passed to `on` method'
    end

    target.assert_valid_keys(:servers, :roles)

    @result << Cronicle::DSL::Context::Job.new(target, &block).result
  end
end
