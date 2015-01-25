class Cronicle::Client
  def initialize(host_list, options = {})
    @host_list = host_list
    @options = options
  end

  def apply(file)
    walk(file)
  end

  private

  def walk(file)
    expected = load_file(file)
  end

  def load_file(file)
    if file.kind_of?(String)
      open(file) do |f|
        Cronicle::DSL.parse(f.read, file, @options)
      end
    elsif [File, Tempfile].any? {|i| file.kind_of?(i) }
      Cronicle::DSL.parse(file.read, file.path, @options)
    else
      raise TypeError, "Can not convert #{file} into File"
    end
  end
end
