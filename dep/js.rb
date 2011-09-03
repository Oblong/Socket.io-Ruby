# JS-ruby
# Copyright(c) 2011 Oblong <chris@oblong.com>
# MIT Licensed
module JS
  def setTimeout(interval, &block)
    startTime = Time.new.to_f

    Thread.new {
      threadTime = Time.new.to_f
      sleep (interval / 1000) - (threadTime - startTime)

      if block.arity == 1
        realoffset = (Time.new.to_f - interval / 1000 - startTime) * 1000

        block.call realoffset.to_i
      else
        block.call
      end
    }
  end

  def setInterval(interval, &block)
    startTime = Time.new.to_f
    times = 0

    Thread.new {
      loop {
        times += 1

        # The number of times we have run
        # multiplied by the interval specified
        # by the caller, then put into a float
        # representing the number of seconds
        # since the initial caller
        expectedoffset = (times * interval) / 1000
        realoffset = (Time.new.to_f - expectedoffset - startTime)

        sleep -realoffset

        if block.arity == 1
          realoffset = (Time.new.to_f - expectedoffset - startTime) * 1000

          # if that fails, then call with the offset
          block.call realoffset.to_i
        else
          # try to call with no arguments first
          block.call
        end
      }
    }
  end

  def clearTimeout threadId
    Thread.kill threadId
  end

  def clearInterval threadId
    Thread.kill threadId
  end

end

# @http://stackoverflow.com/questions/7237578/js-style-object-referencing-in-ruby
class Hash
  def method_missing(symbol, opts = nil)
    string = symbol.to_s
    self[string[0..-2].to_sym] = opts if string[-1..-1] == '=' 
    self[symbol]
  end
end
