require 'fileutils'
require 'tempfile'

require 'micro/service_status'

describe VCAP::Micro::ServiceStatus do

  describe '#read' do

    subject {

      yaml = <<-eos
---
group1:
  - job1
  - job2
group2:
  - job3
eos

      Tempfile.open('service_status') do |temp|
        temp.write(yaml)
        temp.flush

        service_status = VCAP::Micro::ServiceStatus.new(
          :groups_path => temp.path)
        service_status.read
      end
    }

    its(:job_groups) { should include({
        'group1' => [ 'job1', 'job2'],
        'group2' => ['job3']
      })
    }

  end

  describe '#.group_enabled' do

    it 'determines that the group is enabled' do
      Tempfile.open('service_status') do |temp|
        temp_dir = File.dirname(temp)

        FileUtils.touch(File.join(temp_dir, 'group1'))

        service_status = VCAP::Micro::ServiceStatus.new(
          :monitrc_template => "#{temp_dir}/<%=name%>")

        service_status.group_enabled?('group1').should be_true
      end

    end

    it 'determines that the group is disabled' do
      service_status = VCAP::Micro::ServiceStatus.new
      service_status.group_enabled?('group3').should be_false
    end

  end

end
