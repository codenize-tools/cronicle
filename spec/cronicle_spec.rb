describe Cronicle do
  context 'when default cron' do
    before do
      on TARGET_HOSTS do |ssh_options|
        user = ssh_options[:user]

        set_crontab user, <<-CRON.undent
          FOO=bar
          ZOO=baz
          1 1 1 1 1 echo #{user} > /dev/null
        CRON

        set_crontab :root, <<-CRON.undent
          FOO=bar
          ZOO=baz
          1 1 1 1 1 echo root > /dev/null
        CRON
      end
    end

    it do
      on :amazon_linux do
        expect(get_uname).to match /amzn/
        puts get_crontab('root')
        puts get_crontab('ec2-user')
      end
    end

    it do
      on :ubuntu do
        expect(get_uname).to match /Ubuntu/
        puts get_crontab('root')
        puts get_crontab('ubuntu')
      end
    end
  end
end
