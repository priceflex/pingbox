$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'aws-sdk'
#require "../ping/ping" 

class SendToS3

  class << self
    def connect_s3
      @s3_service ||= Aws::S3::Client.new(
        :access_key_id     => ENV['ec2_access_key_id'],
        :secret_access_key => ENV['ec2_secret_access_key'],
        :region            => ENV['AWS_REGION']
      )
    end

    def send_files
      connect_s3

      begin
        Ping.env? == :production ? bucket_name = "pingbox-data" : bucket_name = "pingbox-data-dev"

        puts "Uploading file(s) to S3... \n"

        Dir.glob("#{$pingbox_root}/data/*.gz") do |file|
          print "#{File.basename(file)[0...20]}... "
          if send_file(bucket_name, File.basename(file), file)
            puts "OK."
            FileUtils.rm(file) 
          end
        end
      rescue Exception => e
        puts "\nError transmitting data to S3: #{e.message}"
        e.backtrace.each { |m| puts "\tfrom #{m}" }
      end
    end

    def upload_speed_test
      connect_s3
      bucket_name = "pingbox-speedtest-us"
      file_name = "#{(rand * 100000).to_i}"
      send_file(bucket_name, file_name, "#{$pingbox_root}/upload.file")
    end

    def send_file(bucket, file_name, file)
      bucket_obj = Aws::S3::Object.new(bucket, "#{file_name}", client: @s3_service)
      bucket_obj.upload_file(file)
      return bucket_obj
    end
  end
end

