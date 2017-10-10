$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

require "#{$pingbox_root}/lib/pingbox/send_to_s3"
require "#{$pingbox_root}/lib/pingbox/event_logger"

begin
  amazon_s3 = SendToS3.new
  amazon_s3.upload_ping_files
rescue Exception => e
  EventLogger.process_exception("Upload to S3", e)
  exit 1
end
