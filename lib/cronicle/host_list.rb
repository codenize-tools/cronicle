class Cronicle::HostList
  def initialize(src, options = {})
    @hosts = Set.new
    @host_by_role = Hash.new {|h, k| h[k] = Set.new }

    options.assert_valid_keys(:roles)
    target_roles = Cronicle::Utils.regexp_union(options[:roles])

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

    initialize_servers(servers, target_roles)
    initialize_roles(roles, target_roles)
  end

  def all
    @hosts.to_a
  end

  def select(options = {})
    options.assert_valid_keys(:servers, :roles)
    target_servers, target_roles = options.values_at(:servers, :roles)

    target_servers = Cronicle::Utils.regexp_union(target_servers)
    target_roles = Cronicle::Utils.regexp_union(target_roles)

    host_set = Set.new

    @hosts.each do |host|
      host_set << host if host =~ target_servers
    end

    @host_by_role.each do |role, hosts|
      host_set.merge(hosts) if role =~ target_roles
    end

    host_set.to_a
  end

  private

  def initialize_servers(servers, target_roles)
    unless servers.kind_of?(Hash)
      servers_hash = {}

      Array(servers).each do |host|
        servers_hash[host.to_s] = []
      end

      servers = servers_hash
    end

    servers.each do |host, roles|
      roles = Array(roles).map(&:to_s)

      if target_roles.nil? or roles.any? {|r| r =~ target_servers }
        @hosts << host
        roles.each {|r| @host_by_role[r] << host }
      end
    end
  end

  def initialize_roles(roles, target_roles)
    roles.each do |role, hosts|
      hosts = Array(hosts).map(&:to_s)

      if target_roles.nil? or roles.any? {|r| r =~ target_servers }
        @hosts.merge(hosts)
        @host_by_role[role].merge(hosts)
      end
    end
  end
end
