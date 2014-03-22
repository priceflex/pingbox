# This will make a 5MB File

#fallocate -l 5M upload.file



require 's3'
require 'yaml'
require 'net/http'
require 'uri'

class SpeedTest

  def initialize
    @s3 = S3::Service.new(
      :access_key_id     => ENV['ec2_access_key_id'], 
      :secret_access_key => ENV['ec2_secret_access_key']
    )

    @bucket = @s3.buckets.find('pingbox-speedtest-us')

    @upload_speed = 0.0
    @donlowad_speed = 0.0

    start_speed_test
    send_results
  end

  def start_speed_test
    start_time = Time.now
    file_size = File.size("./upload.file") / 1024.0 / 1024.0
    file_name = "#{(rand * 100000).to_i}"
    new_object = @bucket.objects.build("#{file_name}")
    new_object.content = File.open("./upload.file")
    new_object.save
    end_time = Time.now

    new_object.destroy

    @upload_speed = (file_size / (end_time - start_time)) * 8



    start_time = Time.now
    system("wget https://s3.amazonaws.com/pingbox-speedtest-us/5mb-download.file")
    end_time = Time.now
    system("rm ./5mb-download.file")


    @download_speed = (file_size / (end_time - start_time)) * 8

  end

  def send_results
    if File.exist?("./machine.yml") && File.exist?("test_case.yml")
      test = YAML.load(File.open("./test_case.yml"))
      machine = YAML.load(File.open("./machine.yml"))


      data = {
        :speed_data  => {
        :upload_speed => @upload_speed,
        :download_speed => @download_speed,
        :test_case_id => test[:test_case_id],
        :machine_id => machine[:machine_id],
        :time => Time.now.to_i * 1000
      }
      }

      postData = Net::HTTP.post_form(URI.parse("http://wc.d.techrockstars.com:3000/machine/#{machine[:machine_id]}/speed_test"),data)

    end

  end


end

SpeedTest.new

#uplaod file

#delete file


# bucket = s3.buckets.find('pingbox-speedtest')
# download_object = bucket.objects.find("5mb-download.file")
