describe 'Cronicle::Client#apply (update)' do
  before do
    on TARGET_HOSTS do |ssh_options|
      user = ssh_options[:user]

      set_crontab user, <<-CRON.unindent
        FOO=bar
        ZOO=baz
        1 1 1 1 1 echo #{user} > /dev/null
      CRON

      set_crontab :root, <<-CRON.unindent
        FOO=bar
        ZOO=baz
        1 1 1 1 1 echo root > /dev/null
      CRON
    end

    cronicle(:apply) { <<-RUBY.unindent }
      on servers: /.*/ do
        job :foo, user: :root, schedule: '1 2 * * *' do
          puts `uname`
          puts `whoami`
        end
      end

      on servers: /.*/ do
        job :bar, user: :root, schedule: :@hourly, content: <<-SH.unindent
          #!/bin/sh
          echo hello
        SH
      end

      on servers: /amazon_linux/ do
        job :foo, user: 'ec2-user', schedule: '1 * * * *' do
          puts 100
        end
      end

      on servers: /ubuntu/ do
        job :foo, user: :ubuntu, schedule: :@daily do
          puts 200
        end
      end
    RUBY
  end

  let(:amzn_crontab_orig) do
    {
      "/var/spool/cron/ec2-user" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ec2-user > /dev/null
1 * * * *\t/var/lib/cronicle/libexec/ec2-user/foo 2>&1 | logger -t cronicle/ec2-user/foo
",
      "/var/spool/cron/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
"
    }
  end

  let(:ubuntu_crontab_orig) do
    {
      "/var/spool/cron/crontabs/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
",
      "/var/spool/cron/crontabs/ubuntu" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ubuntu > /dev/null
@daily\t/var/lib/cronicle/libexec/ubuntu/foo 2>&1 | logger -t cronicle/ubuntu/foo
"
    }
  end

  let(:jobfile) do
    <<-RUBY.unindent
      on servers: /.*/ do
        job :foo, user: :root, schedule: '1 2 * * *' do
          puts `uname`
          puts `whoami`
        end
      end

      on servers: /amazon_linux/ do
        job :foo, user: 'ec2-user', schedule: '2 * * * *' do
          puts 100
        end
      end
    RUBY
  end

  context 'when cron is deleted' do
    let(:amzn_crontab) do
      {
        "/var/spool/cron/ec2-user" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ec2-user > /dev/null
2 * * * *\t/var/lib/cronicle/libexec/ec2-user/foo 2>&1 | logger -t cronicle/ec2-user/foo
",
        "/var/spool/cron/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
"
      }
    end

    let(:ubuntu_crontab) do
      {
        "/var/spool/cron/crontabs/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
",
        "/var/spool/cron/crontabs/ubuntu" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ubuntu > /dev/null
"
      }
    end

    it do
      on :amazon_linux do
        expect(get_uname).to match /amzn/
        expect(get_crontabs).to eq amzn_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ec2-user/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 100
        EOS
      end

      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        expect(get_crontabs).to eq ubuntu_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ubuntu/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 200
        EOS
      end

      cronicle(:apply) { jobfile }

      on :amazon_linux do
        expect(get_uname).to match /amzn/
        expect(get_crontabs).to eq amzn_crontab

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ec2-user/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 100
        EOS
      end

      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        expect(get_crontabs).to eq ubuntu_crontab

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS
      end
    end
  end

  context 'when cron is deleted (dry-run)' do
    let(:amzn_crontab) do
      {
        "/var/spool/cron/ec2-user" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ec2-user > /dev/null
2 * * * *\t/var/lib/cronicle/libexec/ec2-user/foo 2>&1 | logger -t cronicle/ec2-user/foo
",
        "/var/spool/cron/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
"
      }
    end

    let(:ubuntu_crontab) do
      {
        "/var/spool/cron/crontabs/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
",
        "/var/spool/cron/crontabs/ubuntu" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ubuntu > /dev/null
@daily\t/var/lib/cronicle/libexec/ubuntu/foo2 2>&1 | logger -t cronicle/ubuntu/foo2
"
      }
    end

    it do
      on :amazon_linux do
        expect(get_uname).to match /amzn/
        expect(get_crontabs).to eq amzn_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ec2-user/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 100
        EOS
      end

      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        expect(get_crontabs).to eq ubuntu_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ubuntu/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 200
        EOS
      end

      cronicle(:apply, dry_run: true) { jobfile }

      on :amazon_linux do
        expect(get_uname).to match /amzn/
        expect(get_crontabs).to eq amzn_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ec2-user/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 100
        EOS
      end

      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        expect(get_crontabs).to eq ubuntu_crontab_orig

        expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts `uname`
          puts `whoami`
        EOS

        expect(get_file('/var/lib/cronicle/libexec/root/bar')).to eq <<-EOS.unindent
          #!/bin/sh
          echo hello
        EOS

        expect(get_file('/var/lib/cronicle/libexec/ubuntu/foo')).to eq <<-EOS.unindent
          #!/usr/bin/env ruby
          puts 200
        EOS
      end
    end
  end
end
