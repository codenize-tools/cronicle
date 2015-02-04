describe Cronicle do
  before do
    on TARGET_HOSTS do
      set_crontab :root, <<-CRON.undent
        FOO=bar
        ZOO=baz
        1 1 1 1 1 echo root > /dev/null
      CRON
    end
  end

  it do
    on :amazon_linux do
      puts get_crontab(:root)
    end
  end

  it do
    on :ubuntu do
      puts get_crontab(:root)
    end
  end
end
