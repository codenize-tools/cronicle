class Cronicle::Utils
  class << self
    def regexp_union(list)
      return nil if list.nil?
      return list if list.kind_of?(Regexp)

      list = Array(list)
      return nil if list.empty?

      Regexp.union(list.map {|str_or_reg|
        if str_or_reg.kind_of?(Regexp)
          str_or_reg
        else
          /\A#{str_or_reg}\z/
        end
      })
    end

    def sed_escape(cmd)
      cmd.gsub('/', '\\/')
    end

    def sh_quote(str)
      "'" + str.gsub("'", %!'"'"'!) + "'"
    end
  end # of class methods
end
