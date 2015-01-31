class Cronicle::DSL::Context::Job
  def initialize(target, &block)
    @result = {
      :servers => target[:servers],
      :roles => target[:roles],
      :job => {},
    }

    instance_eval(&block)
  end

  attr_reader :result

  def job(name, opts = {}, &block)
    name = name.to_s

    raise ArgumentError, %!Job name is required! if (name || '').strip.empty?

    unless opts.kind_of?(Hash)
      raise TypeError, "Job `#{name}`: wrong argument type #{opts.class} (expected Hash)"
    end

    if opts[:schedule] and not opts[:user]
      raise ArgumentError, "Job `#{name}`: :user is required when :schedule is passed"
    elsif not opts[:schedule] and opts[:user]
      raise ArgumentError, "Job `#{name}`: :schedule is required when :user is passed"
    end

    opts.assert_valid_keys(:schedule, :user, :content)

    if opts[:content] and block
      raise ArgumentError, 'Can not pass :content and block to `job` method'
    elsif not opts[:content] and not block
      raise ArgumentError, "Job `#{job[:name]}`: :context or block is required"
    end

    job = @result[:job]

    if block
      job[:content] = <<-RUBY
#!/usr/bin/env ruby
#{block.to_source}.call
      RUBY
    else
      job[:content] = opts[:content].to_s.undent
    end

    job[:schedule] = opts[:schedule] if opts[:schedule]
  end
end
