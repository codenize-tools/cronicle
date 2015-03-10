class Cronicle::DSL::Context::Job
  def initialize(target, &block)
    @result = Hash.new {|hash, key|
      hash[key] = {
        :servers => Array(target[:servers]),
        :roles => Array(target[:roles]),
        :job => {}
      }
    }

    instance_eval(&block)
  end

  attr_reader :result

  def job(name, opts = {}, &block)
    name = name.to_s

    raise ArgumentError, %!Job name is required! if (name || '').strip.empty?

    if @result.has_key?(name)
      raise "Job `#{name}`: already defined"
    end

    unless opts.kind_of?(Hash)
      raise TypeError, "Job `#{name}`: wrong argument type #{opts.class} (expected Hash)"
    end

    unless opts[:user]
      raise ArgumentError, "Job `#{name}`: :user is required"
    end

    opts.assert_valid_keys(:schedule, :user, :content, :bundle, :locals, :header)

    if opts[:content] and block
      raise ArgumentError, 'Can not pass :content and block to `job` method'
    elsif not opts[:content] and not block
      raise ArgumentError, "Job `#{name}`: :context or block is required"
    end

    unless opts[:locals].nil? or opts[:locals].kind_of?(Hash)
      raise TypeError, "Job `#{name}`: :locals is wrong argument type (expected Hash)"
    end

    job_hash = @result[name][:job]
    job_hash[:name] = name
    job_hash[:user] = opts.fetch(:user).to_s
    job_hash[:schedule] = opts[:schedule].to_s if opts[:schedule]
    bundle = opts[:bundle]

    if bundle
      job_hash[:bundle] = bundle.kind_of?(Hash) ? bundle : Array(bundle).map(&:to_s)
    end

    if block
      source = block.to_raw_source(:strip_enclosure => true).each_line.to_a
      source = (source.shift || '') + source.join.unindent

      job_hash[:content] = "#!/usr/bin/env ruby\n"

      opts.fetch(:locals, {}).each do |name, value|
        job_hash[:content] << "#{name} = #{value.inspect}\n"
      end

      job_hash[:content] << "#{source}\n"
    else
      job_hash[:content] = opts[:content].to_s.unindent
    end

    if opts[:header]
      index = (job_hash[:content] =~ /^[^#]/) || 0
      job_hash[:content].insert(index, "#{opts[:header]}\n")
    end
  end
end
