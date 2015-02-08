describe Cronicle::HostList do
  let(:host_list) { described_class.new(source) }

  context 'when csv is passed' do
    let(:source) { "foo,bar" }

    it do
      expect(host_list.all).to match_array ["foo", "bar"]
    end

    it do
      expect(host_list.select(servers: /foo/)).to match_array ["foo"]
    end

    it do
      expect(host_list.select(roles: /web/)).to match_array []
    end
  end

  context 'when list is passed' do
    let(:source) do
      <<-EOS.undent
        foo
        bar
      EOS
    end

    it do
      expect(host_list.all).to match_array ["foo", "bar"]
    end

    it do
      expect(host_list.select(servers: /foo/)).to match_array ["foo"]
    end

    it do
      expect(host_list.select(roles: /web/)).to match_array []
    end
  end

  context 'when JSON(servers) is passed' do
    context 'when single server' do
      let(:source) do
        <<-EOS.undent
          {
            "servers": "foo"
          }
        EOS
      end

      it do
        expect(host_list.all).to match_array ["foo"]
      end

      it do
        expect(host_list.select(servers: /foo/)).to match_array ["foo"]
      end

      it do
        expect(host_list.select(roles: /web/)).to match_array []
      end
    end

    context 'when multiple servers' do
      let(:source) do
        <<-EOS.undent
          {
            "servers": ["foo", "bar"]
          }
        EOS
      end

      it do
        expect(host_list.all).to match_array ["foo", "bar"]
      end

      it do
        expect(host_list.select(servers: /foo/)).to match_array ["foo"]
      end

      it do
        expect(host_list.select(roles: /web/)).to match_array []
      end
    end

    context 'when multiple servers with role' do
      let(:source) do
        <<-EOS.undent
          {
            "servers": {
              "foo": "db",
              "bar": "web"
            }
          }
        EOS
      end

      it do
        expect(host_list.all).to match_array ["foo", "bar"]
      end

      it do
        expect(host_list.select(servers: /foo/)).to match_array ["foo"]
      end

      it do
        expect(host_list.select(roles: /web/)).to match_array ["bar"]
      end
    end
  end

  context 'when JSON(roles) is passed' do
    context 'when single server' do
      let(:source) do
        <<-EOS.undent
          {
            "roles": {
              "web": "bar"
            }
          }
        EOS
      end

      it do
        expect(host_list.all).to match_array ["bar"]
      end

      it do
        expect(host_list.select(servers: /foo/)).to match_array []
      end

      it do
        expect(host_list.select(roles: /web/)).to match_array ["bar"]
      end
    end

    context 'when multiple servers' do
      let(:source) do
        <<-EOS.undent
          {
            "roles": {
              "db": ["foo", "bar"],
              "web": ["zoo", "baz"]
            }
          }
        EOS
      end

      it do
        expect(host_list.all).to match_array ["foo", "bar", "zoo", "baz"]
      end

      it do
        expect(host_list.select(servers: /oo/)).to match_array ["foo", "zoo"]
      end

      it do
        expect(host_list.select(roles: /web/)).to match_array ["zoo", "baz"]
      end
    end
  end
end
