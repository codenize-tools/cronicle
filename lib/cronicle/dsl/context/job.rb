class Cronicle::DSL::Context::Job
  def initialize(target, &block)
    @result = {
      :servers => target[:servers],
      :roles => target[:roles],
      :job => {},
    }

    instance_eval(&block)
  end

  def result
    job = @result[:job]
    raise %!Job `#{job[:name]}`: :context or block is required! unless job[:context]
    @result
  end

  def job(name, opts = {}, &block)
    raise ArgumentError, %!Job name is required! if (name || '').strip.empty?

    name = name.to_s

    unless opts.kind_of?(Hash)
      raise TypeError, "Job `#{name}`: wrong argument type #{opts.class} (expected Hash)"
    end

    opts.assert_valid_keys(:schedule, :content)

    if opts[:content] and block
      raise ArgumentError, 'Can not pass :content and block to `job` method'
    end

    job = @result[:job]

    if block
      job[:content] = <<-RUBY.undent
        #!/usr/bin/env ruby
        #{block.to_source}.call
      RUBY
    else
      job[:content] = opts[:content].to_s.undent
    end

    job[:schedule] = opts[:schedule] if opts[:schedule]
  end
end
