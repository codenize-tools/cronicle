class Net::SSH::Connection::Channel
  alias on_data_orig on_data

  def on_data(&block)
    on_data_orig do |ch, data|
      sudo_password = Thread.current[SSHKit::Backend::Netssh::SUDO_PASSWORD_KEY]

      if sudo_password and data == SSHKit::Backend::Netssh::SUDO_PROMPT
        ch.send_data(sudo_password + "\n")
      else
        block.call(ch, data) if block
      end
    end
  end
end
