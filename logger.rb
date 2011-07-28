class Logger
  attr_accessor :level

  def initialize(*args); end

  def write msg
    $stderr.puts msg
  end

  def error(*msg)
    write "Error: #{msg.join(' ')}"
  end
  def warn(*msg)
    write "Warn: #{msg.join(' ')}"
  end
  def info(*msg)
    write "Info: #{msg.join(' ')}"
  end
  def debug(*msg)
    write "Debug: #{msg.join(' ')}"
  end
end
