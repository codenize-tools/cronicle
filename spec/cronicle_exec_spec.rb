describe 'Cronicle::Client#exec' do
  let(:logger_out) { StringIO.new }

  let(:logger) do
    logger = Logger.new(logger_out)

    logger.formatter = proc {|severity, datetime, progname, msg|
      "#{msg}\n"
    }

    logger
  end

  let(:amzn_out) { logger_out.string.each_line.select {|i| i =~ /amazon_linux/ }.join }
  let(:ubuntu_out) {logger_out.string.each_line.select {|i| i =~ /ubuntu/ }.join }

  context 'run as root' do
    let(:jobfile) do
      <<-RUBY.unindent
        on servers: /.*/ do
          job :foo, user: :root do
            puts `uname`
            puts `whoami`
          end
        end

        on servers: /.*/ do
          job :bar, user: :root, content: <<-SH.unindent
            #!/bin/sh
            echo hello
          SH
        end
      RUBY
    end

    before do
      cronicle(:exec, :foo, logger: logger) { jobfile }
      cronicle(:exec, :bar, logger: logger) { jobfile }
    end

    it do
      expect(amzn_out).to eq <<-EOS.unindent
        foo on amazon_linux/root> Execute job
        foo on amazon_linux/root>\s
        foo on amazon_linux/root> Linux
        foo on amazon_linux/root> root
        bar on amazon_linux/root> Execute job
        bar on amazon_linux/root>\s
        bar on amazon_linux/root> hello
      EOS
    end

    it do
      expect(ubuntu_out).to eq <<-EOS.unindent
        foo on ubuntu/root> Execute job
        foo on ubuntu/root>\s
        foo on ubuntu/root> Linux
        foo on ubuntu/root> root
        bar on ubuntu/root> Execute job
        bar on ubuntu/root>\s
        bar on ubuntu/root> hello
      EOS
    end
  end

  context 'run as root (dry-run)' do
    let(:jobfile) do
      <<-RUBY.unindent
        on servers: /.*/ do
          job :foo, user: :root do
            puts `uname`
            puts `whoami`
          end
        end

        on servers: /.*/ do
          job :bar, user: :root, content: <<-SH.unindent
            #!/bin/sh
            echo hello
          SH
        end
      RUBY
    end

    before do
      cronicle(:exec, :foo, logger: logger, dry_run: true) { jobfile }
      cronicle(:exec, :bar, logger: logger, dry_run: true) { jobfile }
    end

    it do
      expect(amzn_out).to eq <<-EOS.unindent
        foo on amazon_linux/root> Execute job (dry-run)
        bar on amazon_linux/root> Execute job (dry-run)
      EOS
    end

    it do
      expect(ubuntu_out).to eq <<-EOS.unindent
        foo on ubuntu/root> Execute job (dry-run)
        bar on ubuntu/root> Execute job (dry-run)
      EOS
    end
  end

  context 'run as non-root user' do
    let(:jobfile) do
      <<-RUBY.unindent
        on servers: /amazon_linux/ do
          job :foo, user: 'ec2-user' do
            puts `uname`
            puts `whoami`
          end
        end

        on servers: /ubuntu/ do
          job :foo, user: :ubuntu do
            puts `uname`
            puts `whoami`
          end
        end
      RUBY
    end

    before do
      cronicle(:exec, :foo, logger: logger) { jobfile }
    end

    it do
      expect(amzn_out).to eq <<-EOS.unindent
        foo on amazon_linux/ec2-user> Execute job
        foo on amazon_linux/ec2-user> Linux
        foo on amazon_linux/ec2-user> ec2-user
      EOS
    end

    it do
      expect(ubuntu_out).to eq <<-EOS.unindent
        foo on ubuntu/ubuntu> Execute job
        foo on ubuntu/ubuntu> Linux
        foo on ubuntu/ubuntu> ubuntu
      EOS
    end
  end

  context 'jon is not defined' do
    let(:jobfile) do
      <<-RUBY.unindent
        on servers: /.*/ do
          job :foo, user: :root do
            puts `uname`
            puts `whoami`
          end
        end
      RUBY
    end

    it do
      expect {
        cronicle(:exec, :bar, logger: logger) { jobfile }
      }.to raise_error('Definition cannot be found: Job `bar`')
    end
  end
end
