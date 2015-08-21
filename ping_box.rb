require 'pry'

module Pingbox
  class Cleanup
    class << self
      def reset_cron_log
        print "Removing cron log... "
        FileUtils.rm("#{Dir.pwd}/cron_log.log")
        puts "done."
      end
    end
  end
end

