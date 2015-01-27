class Cronicle::HostList
  def initialize(src)
    begin
      host_list = JSON.parse(src)
    rescue JSON::ParserError
      host_list = {'servers' => {}}

      src.split(/[,\s]+/).each do |host|
        host.strip!
        host_list['servers'][host] = [] unless host.empty?
      end
    end

    host_list.assert_valid_keys('servers', 'roles')
    servers = host_list['servers'] || {}
    roles = host_list['roles'] || {}

    unless roles.kind_of?(Hash)
      raise TypeError, "wrong roles type #{roles.class} (expected Hash)"
    end

    @servers = normalize_servers(servers)
    @roles = normalize_roles(roles)
  end

  def select(target_servers = nil, target_roles = nil)
    unless target_servers or target_roles
      return all
    end

    target_servers = Cronicle::Utils.regexp_union(target_servers)
    target_roles = Cronicle::Utils.regexp_union(target_roles)

    hosts = []

    @servers.each do |host, roles|
      if host =~ target_servers or roles.any? {|r| r =~ target_roles }
        hosts << host
      end
    end

    @roles.each do |role, hs|
      if role =~ target_roles
        hosts.concat(hs)
      end
    end

    hosts.uniq
  end

  def all
    hosts = @servers.keys + @roles.map {|r, hs| hs }.flatten
    hosts.uniq
  end

  private

  def normalize_servers(servers)
    unless servers.kind_of?(Hash)
      servers_hash = {}

      [servers].flatten.each do |host|
        host = host.to_s.strip
        servers_hash[host] = {}
      end

      servers = servers_hash
    end

    servers.keys.each do |host|
      roles = servers[host]
      servers[host] = [roles].flatten.map {|r| r.to_s }
    end

    servers
  end

  def normalize_roles(roles)
    roles.keys.each do |role|
      hosts = roles[role]
      roles[role] = [hosts].flatten.map {|h| h.to_s }
    end

    roles
  end
end
