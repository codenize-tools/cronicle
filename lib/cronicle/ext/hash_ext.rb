class Hash
  def assert_valid_keys(*valid_keys)
    each_key do |k|
      next if valid_keys.include?(k)
      raise ArgumentError, "unknown key: #{k.inspect}. valid keys are: #{valid_keys.map(&:inspect).join(', ')}"
    end
  end
end
