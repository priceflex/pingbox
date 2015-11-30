require 'yaml'

$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

class Machine

  class << self

    def personal_info
      {
        system_id: system_id,
        test_case: test_case_info
      }
    rescue => e
      return "Can't load machine info - #{e.message}"
    end

    def html_info
      info = personal_info

      if info[:system_id] && info[:test_case]
        return <<-MSG
        <strong>Name:</strong> <a href=#{info[:test_case][:trsla_url]}>#{info[:test_case][:name]}</a><br />
        <strong>System ID:</strong> #{info[:system_id][:machine_id]}<br />
        <strong>Test Case ID:</strong> #{info[:test_case][:test_case_id]}<br />
        MSG
      else
        return "<strong>#{info}</strong>"
      end
    end

    private

    def system_id
      YAML.load(File.open("#{$pingbox_root}/config/machine.yml"))
    end

    def test_case_info
      YAML.load(File.open("#{$pingbox_root}/config/test_case.yml"))
    end

  end

end
