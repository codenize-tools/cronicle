class Cronicle::DSL
  class << self
    def parse(dsl, path, opts = {})
      Cronicle::DSL::Context.eval(dsl, path, opts).result
    end
  end # of class methods
end
