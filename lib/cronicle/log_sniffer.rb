class Cronicle::LogSniffer
  def initialize(original_output, &block)
    @original_output = original_output
    @block = block
  end

  def write(obj)
    @block.call(obj)
    @original_output << obj
  end
  alias :<< :write
end
