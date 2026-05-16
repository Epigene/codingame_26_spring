require "set"
require "benchmark"

STDOUT.sync = true # DO NOT REMOVE

def debug(message)
  STDERR.puts message
end

# Monkeypatching String '1 -1' to behave like a Point, have x, y
class String
  def x
    split.first.to_i
  end

  def y
    split[1].to_i
  end
end

module QuickMaxBy
  def quick_max_by(&block)
    if one?
      first
    else
      max_by(&block)
    end
  end
  def quick_min_by(&block)
    if one?
      first
    else
      min_by(&block)
    end
  end
end

Array.include QuickMaxBy
Set.include QuickMaxBy
