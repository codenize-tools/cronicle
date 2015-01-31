class Cronicle::DSL::Context::Job
  def initialize(target, &block)
    @result = {
      :servers => Array(target[:servers]),
      :roles => Array(target[:roles]),
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
      raise ArgumentError, "Job `#{name}`: :context or block is required"
    end

    job_hash = @result[:job]
    job_hash[:name] = name

    if block
      job_hash[:content] = <<-RUBY
#!/usr/bin/env ruby
#{block.to_raw_source(:strip_enclosure => true)}
      RUBY
    else
      job_hash[:content] = opts[:content].to_s.undent
    end

    if opts[:schedule]
      job_hash[:schedule] = opts[:schedule]
      job_hash[:user] = opts.fetch(:user).to_s
    end
  end
end
