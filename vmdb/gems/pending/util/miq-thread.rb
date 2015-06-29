require 'thread'

#
# This class provides a way to synchronize communication between threads.
#
# Example:
#
#   require 'thread'
#   
#   stack = Stack.new
#   
#   producer = Thread.new do
#     5.times do |i|
#       sleep rand(i) # simulate expense
#       stack << i
#       puts "#{i} produced"
#     end
#   end
#   
#   consumer = Thread.new do
#     5.times do |i|
#       value = stack.pop
#       sleep rand(i/2) # simulate expense
#       puts "consumed #{value}"
#     end
#   end
#   
#   consumer.join
#
class Stack
  #
  # Creates a new stack.
  #
  def initialize
    @que = []
    @waiting = []
    @que.taint		# enable tainted comunication
    @waiting.taint
    self.taint
  end

  #
  # Pushes +obj+ to the stack.
  #
  def push(obj)
    Thread.critical = true
    @que.unshift obj
    begin
      t = @waiting.shift
      t.wakeup if t
    rescue ThreadError
      retry
    ensure
      Thread.critical = false
    end
    begin
      t.run if t
    rescue ThreadError
    end
  end

  #
  # Alias of push
  #
  alias << push

  #
  # Alias of push
  #
  alias enq push

  #
  # Retrieves data from the stack.  If the stack is empty, the calling thread is
  # suspended until data is pushed onto the stack.  If +non_block+ is true, the
  # thread isn't suspended, and an exception is raised.
  #
  def pop(non_block=false)
    while (Thread.critical = true; @que.empty?)
      raise ThreadError, "queue empty" if non_block
      @waiting.push Thread.current
      Thread.stop
    end
    @que.shift
  ensure
    Thread.critical = false
  end

  #
  # Alias of pop
  #
  alias shift pop

  #
  # Alias of pop
  #
  alias deq pop

  #
  # Returns +true+ is the stack is empty.
  #
  def empty?
    @que.empty?
  end

  #
  # Removes all objects from the stack.
  #
  def clear
    @que.clear
  end

  #
  # Returns the length of the stack.
  #
  def length
    @que.length
  end

  #
  # Alias of length.
  #
  alias size length

  #
  # Returns the number of threads waiting on the stack.
  #
  def num_waiting
    @waiting.size
  end
end

#
# This class represents stacks of specified size capacity.  The push operation
# may be blocked if the capacity is full.
#
# See Stack for an example of how a SizedStack works.
#
class SizedStack < Stack
  #
  # Creates a fixed-length stack with a maximum size of +max+.
  #
  def initialize(max)
    raise ArgumentError, "queue size must be positive" unless max > 0
    @max = max
    @queue_wait = []
    @queue_wait.taint		# enable tainted comunication
    super()
  end

  #
  # Returns the maximum size of the stack.
  #
  def max
    @max
  end

  #
  # Sets the maximum size of the stack.
  #
  def max=(max)
    Thread.critical = true
    if max <= @max
      @max = max
      Thread.critical = false
    else
      diff = max - @max
      @max = max
      Thread.critical = false
      diff.times do
	begin
	  t = @queue_wait.shift
	  t.run if t
	rescue ThreadError
	  retry
	end
      end
    end
    max
  end

  #
  # Pushes +obj+ to the stack.  If there is no space left in the stack, waits
  # until space becomes available.
  #
  def push(obj)
    Thread.critical = true
    while @que.length >= @max
      @queue_wait.push Thread.current
      Thread.stop
      Thread.critical = true
    end
    super
  end

  #
  # Alias of push
  #
  alias << push

  #
  # Alias of push
  #
  alias enq push

  #
  # Retrieves data from the stack and runs a waiting thread, if any.
  #
  def pop(*args)
    retval = super
    Thread.critical = true
    if @que.length < @max
      begin
	t = @queue_wait.shift
	t.wakeup if t
      rescue ThreadError
	retry
      ensure
	Thread.critical = false
      end
      begin
	t.run if t
      rescue ThreadError
      end
    end
    retval
  end

  #
  # Alias of pop
  #
  alias shift pop

  #
  # Alias of pop
  #
  alias deq pop

  #
  # Returns the number of threads waiting on the stack.
  #
  def num_waiting
    @waiting.size + @queue_wait.size
  end
end
