describe 'Cronicle::Client#apply (create)' do
  context 'when empty cron' do
    let(:jobfile) do
      <<-RUBY.unindent
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

    let(:amzn_crontab) do
      {
        "/var/spool/cron/ec2-user" =>
"1 * * * *\t/var/lib/cronicle/libexec/ec2-user/foo 2>&1 | logger -t cronicle/ec2-user/foo
",
        "/var/spool/cron/root" =>
"1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
"
      }
    end

    let(:ubuntu_crontab) do
      {
        "/var/spool/cron/crontabs/root" =>
"1 2 * * *\t/var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
@hourly\t/var/lib/cronicle/libexec/root/bar 2>&1 | logger -t cronicle/root/bar
",
        "/var/spool/cron/crontabs/ubuntu" =>
"@daily\t/var/lib/cronicle/libexec/ubuntu/foo 2>&1 | logger -t cronicle/ubuntu/foo
"
      }
    end

    before do
      cronicle(:apply) { jobfile }
    end

    it do
      on :amazon_linux do
        expect(get_uname).to match /amzn/
        expect(get_crontabs).to eq amzn_crontab

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
    end

    it do
      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        expect(get_crontabs).to eq ubuntu_crontab

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

  context 'when default cron' do
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
    end

    let(:jobfile) do
      <<-RUBY.unindent
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

    context 'when apply' do
      let(:amzn_crontab) do
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

      let(:ubuntu_crontab) do
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

      before do
        cronicle(:apply) { jobfile }
      end

      it do
        on :amazon_linux do
          expect(get_uname).to match /amzn/
          expect(get_crontabs).to eq amzn_crontab

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
      end

      it do
        on :ubuntu do
          expect(get_uname).to match /Ubuntu/
          expect(get_crontabs).to eq ubuntu_crontab

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

    context 'when apply with bundle' do
      let(:jobfile) do
        <<-RUBY.unindent
          on servers: /.*/ do
            job :foo, user: :root, schedule: '1 2 * * *', bundle: 'ruby-mysql' do
              require 'mysql'
              p Mysql
            end
          end
        RUBY
      end

      let(:amzn_crontab) do
        {
          "/var/spool/cron/ec2-user" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ec2-user > /dev/null
",
          "/var/spool/cron/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\tcd /var/lib/cronicle/run/root/foo && /usr/local/bin/bundle exec /var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
"
        }
      end

      let(:amzn_gemfile) do
        {
          "/var/lib/cronicle/run/root/foo/Gemfile" =>
"source 'https://rubygems.org'
gem 'ruby-mysql'
"
        }
      end

      let(:ubuntu_crontab) do
        {
          "/var/spool/cron/crontabs/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
1 2 * * *\tcd /var/lib/cronicle/run/root/foo && /usr/local/bin/bundle exec /var/lib/cronicle/libexec/root/foo 2>&1 | logger -t cronicle/root/foo
",
          "/var/spool/cron/crontabs/ubuntu" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ubuntu > /dev/null
"
        }
      end

      let(:ubuntu_gemfile) do
        {
          "/var/lib/cronicle/run/root/foo/Gemfile" =>
"source 'https://rubygems.org'
gem 'ruby-mysql'
"
        }
      end

      before do
        cronicle(:apply) { jobfile }
      end

      it do
        on :amazon_linux do
          expect(get_uname).to match /amzn/
          expect(get_crontabs).to eq amzn_crontab

          expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
            #!/usr/bin/env ruby
            require 'mysql'
            p Mysql
          EOS

          expect(get_gemfiles).to eq amzn_gemfile
        end
      end

      it do
        on :ubuntu do
          expect(get_uname).to match /Ubuntu/
          expect(get_crontabs).to eq ubuntu_crontab

          expect(get_file('/var/lib/cronicle/libexec/root/foo')).to eq <<-EOS.unindent
            #!/usr/bin/env ruby
            require 'mysql'
            p Mysql
          EOS

          expect(get_gemfiles).to eq ubuntu_gemfile
        end
      end
    end

    context 'when apply (dry-run)' do
      let(:amzn_crontab) do
        {
          "/var/spool/cron/ec2-user" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ec2-user > /dev/null
",
        "/var/spool/cron/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
"
        }
      end

      let(:ubuntu_crontab) do
        {
          "/var/spool/cron/crontabs/root" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo root > /dev/null
",
        "/var/spool/cron/crontabs/ubuntu" =>
"FOO=bar
ZOO=baz
1 1 1 1 1 echo ubuntu > /dev/null
"
        }
      end

      before do
        cronicle(:apply, dry_run: true) { jobfile }
      end

      it do
        on :amazon_linux do
          expect(get_uname).to match /amzn/
          expect(get_crontabs).to eq amzn_crontab
        end
      end

      it do
        on :ubuntu do
          expect(get_uname).to match /Ubuntu/
          expect(get_crontabs).to eq ubuntu_crontab
        end
      end
    end
  end
end
