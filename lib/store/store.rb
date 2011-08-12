# This is NOT to transport messages between hosts but instead to save persistent meta 
# information for each host in case something crashes or becomes temporarily unavailable
class Store

  def initialize(file); end
  def getsession(block); end
  def dump(); end
  def get(key); end
  def hashget(key, value); end
  def set(key, value); end
  def del(key); end
  def decr(key); end
  def incr(key); end
  def hashdel(key, value); end
  def hashset(key, value1, value2); end

  # append a value to an array
  def append(key, value); end

  # remove a value from an array
  def unappend(key, value); end
end
