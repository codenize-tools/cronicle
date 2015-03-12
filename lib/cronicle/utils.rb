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

    IPADDR_REGEXP = /\A\d+(?:\.\d+){3}\z/

    def short_hostname(hostname)
      if hostname =~ IPADDR_REGEXP
        hostname
      else
        hostname.split('.').first
      end
    end

    def sed_escape(cmd)
      cmd.gsub('/', '\\/')
    end

    def remove_prompt!(str)
      str.sub!(/\A[^:]*:\s*/, '')
    end

    def diff(file1, file2)
      file1 = file1.chomp + "\n"
      file2 = file2.chomp + "\n"
      Diffy::Diff.new(file1, file2, :context => 3, :include_diff_info => true).to_s(:text)
    end
  end # of class methods
end
