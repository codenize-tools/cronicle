describe Cronicle do
  describe_host :amazon_linux do
    describe package('httpd') do
      it { should_not be_installed }
    end
  end

  describe_host :ubuntu do
    describe package('apache2') do
      it { should_not be_installed }
    end
  end
end
