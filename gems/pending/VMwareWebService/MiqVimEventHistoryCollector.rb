class MiqVimEventHistoryCollector
  attr_reader :invObj

  def initialize(invObj, eventFilterSpec = nil, pgSize = 20)
    @invObj                 = invObj
    @sic                    = invObj.sic
    @pgSize                 = pgSize

    @eventFilterSpec = eventFilterSpec || VimHash.new("EventFilterSpec")

    @eventHistoryCollector = @invObj.createCollectorForEvents(@sic.eventManager, @eventFilterSpec)
    @invObj.setCollectorPageSize(@eventHistoryCollector, @pgSize)
  end

  def release
    return unless @eventHistoryCollector
    $vim_log.info "MiqVimEventHistoryCollector.release: destroying #{@eventHistoryCollector}"
    @invObj.destroyCollector(@eventHistoryCollector)
    @eventHistoryCollector = nil
  end

  def readNext(maxCount = @pgSize)
    raise "MiqVimEventHistoryCollector.readNext: collector instance has been released" unless @eventHistoryCollector
    @invObj.readNextEvents(@eventHistoryCollector, maxCount)
  end

  def readPrevious(maxCount = @pgSize)
    raise "MiqVimEventHistoryCollector.readPrevious: collector instance has been released" unless @eventHistoryCollector
    @invObj.readPreviousEvents(@eventHistoryCollector, maxCount)
  end

  def reset
    raise "MiqVimEventHistoryCollector.reset: collector instance has been released" unless @eventHistoryCollector
    @invObj.resetCollector(@eventHistoryCollector)
  end

  def rewind
    raise "MiqVimEventHistoryCollector.rewind: collector instance has been released" unless @eventHistoryCollector
    @invObj.rewindCollector(@eventHistoryCollector)
  end

  def pageSize
    @pgSize
  end

  def pageSize=(val)
    raise "MiqVimEventHistoryCollector.pageSize=: collector instance has been released" unless @eventHistoryCollector
    @invObj.setCollectorPageSize(@eventHistoryCollector, val)
    @pgSize = val
  end

  # Helper method that yields all requested events
  def events(direction = :forward, maxCount = @pgSize)
    set_method, next_method = (direction == :forward) ? [:rewind, :readNext] : [:reset, :readPrevious]
    send(set_method)

    readNext if direction == :reverse   # Hack to fix issue with VC setting to first page of events

    while (events_page = send(next_method, maxCount))
      events_page.each { |event| yield(event) }
    end
  end
end # class MiqVimEventHistoryCollector
