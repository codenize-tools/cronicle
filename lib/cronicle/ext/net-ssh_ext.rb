class Net::SSH::Connection::Channel
  PROMPT_REGEXP = Regexp.compile('^' + Regexp.escape(SSHKit::Backend::Netssh::SUDO_PROMPT) + '\b')

  alias on_data_orig on_data

  def on_data(&block)
    on_data_orig do |ch, data|
      sudo_password = Thread.current[SSHKit::Backend::Netssh::SUDO_PASSWORD_KEY]

      if sudo_password and data =~ PROMPT_REGEXP
        ch.send_data(sudo_password + "\n")
      else
        block.call(ch, data) if block
      end
    end
  end
end
