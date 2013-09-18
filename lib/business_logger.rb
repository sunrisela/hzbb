class BusinessLogger < Logger
  
  def initialize(*args)
    super(*args)
    original_formatter = Formatter.new
    @formatter = proc {|*args| original_formatter.call(*args) }
    @logdev
  end
  
  class Formatter < Logger::Formatter
    Format = "[%s: %s #%d] -- %s: %s\n"
    
    def initialize
      @datetime_format = "%Y-%m-%d %H:%M:%S"
    end
    
    def call(severity, time, progname, msg)
      Format % [severity, format_datetime(time), $$, progname, msg2str(msg)]
    end
  end
end