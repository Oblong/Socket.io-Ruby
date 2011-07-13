module Logger
  def self.write msg
    $stderr.puts msg
  end

  def self.info msg
    Logger.write "Info: #{msg}"
  end

  def self.debug msg
    Logger.write "Debug: #{msg}"
  end
end
