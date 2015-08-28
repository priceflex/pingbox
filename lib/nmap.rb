$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

require "#{$pingbox_root}/lib/test_case"
require "#{$pingbox_root}/lib/pingbox/event_logger"

begin
  test_case = TestCase.new

rescue Exception => e
  EventLogger.process_exception("Test case", e)
end
