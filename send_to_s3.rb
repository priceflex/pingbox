require 's3'

class SendToS3
  def self.send_files
    s3_service = S3::Service.new(
      :access_key_id     => ENV['ec2_access_key_id'],
      :secret_access_key => ENV['ec2_secret_access_key']
    )
    begin

      if Ping.env? == :production
        @bucket = "pingbox-data"
      else
        @bucket = "pingbox-data-dev"
      end

      bucket = s3_service.buckets.find("#{@bucket}")
      # Copy to S3
      puts "Uploading file to s3"
      # found_object.destroy
      Dir.glob("#{@@current_path}/data/*.gz") do |file|
        new_object = bucket.objects.build("#{File.basename(file)}")
        new_object.content = open("#{file}")
        new_object.save
        if new_object.exists?
          FileUtils.rm(file)
        end
      end
      puts "Sent all data to s3"
    rescue
      puts "Error Sending to S3"
    end

  end
end
