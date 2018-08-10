require 'singleton'

module Versioneye


  class Log

    include Singleton

    def initialize
      p "initialize"

      environment = ENV['RAILS_ENV']
      environment = 'development' if environment.to_s.empty?
      filename = "log/#{environment}_tasks.log"

      @logger = ActiveSupport::Logger.new(STDOUT) # 10485760 = 10 MB
      @logger.formatter = Versioneye::Formatter.new
    end

    def log
      @logger
    end

  end


  class DynLog

    def initialize filename = nil, count = 10, size = 10485760 # 10485760 = 10 MB
      p "initialize"

      if filename.to_s.empty?
        environment = ENV['RAILS_ENV']
        environment = 'development' if environment.to_s.empty?
        filename = "log/#{environment}_tasks.log"
      end
      @logger = ActiveSupport::Logger.new(STDOUT)
      @logger.formatter = Versioneye::Formatter.new
    end

    def log
      @logger
    end

  end


  class Formatter

    SEVERITY_TO_TAG_MAP     = {'DEBUG'=>'meh', 'INFO'=>'fyi', 'WARN'=>'hmm', 'ERROR'=>'wtf', 'FATAL'=>'omg', 'UNKNOWN'=>'???'}
    SEVERITY_TO_COLOR_MAP   = {'DEBUG'=>'0;37', 'INFO'=>'32', 'WARN'=>'33', 'ERROR'=>'31', 'FATAL'=>'31', 'UNKNOWN'=>'37'}

    def call(severity, time, progname, msg)
      formatted_severity = sprintf("%-3s","#{SEVERITY_TO_TAG_MAP[severity]}")
      formatted_time     = time.strftime("%Y-%m-%d %H:%M:%S.") << time.usec.to_s[0..2].rjust(3)
      color              = SEVERITY_TO_COLOR_MAP[severity]

      message = msg
      message = msg.strip if msg.is_a?( String.class )

      "\033[0;37m#{formatted_time}\033[0m [\033[#{color}m#{formatted_severity}\033[0m] #{message} (pid:#{$$})\n"
    end
  end


end
