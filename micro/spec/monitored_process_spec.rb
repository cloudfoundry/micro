require 'micro/monitored_process'

describe VCAP::Micro::MonitoredProcess do

  describe '#stop' do

    it 'stops the process' do
      VCAP::Micro.should_receive(:shell_raiser).with('monit stop process')
      VCAP::Micro::MonitoredProcess.new('process').stop
    end

  end

  describe '#running' do

    context 'running' do

      it 'is running' do
        VCAP::Micro::MonitoredProcess.new('process').running?({
          'process' => { :status => { :message => 'running' } } }
          ).should be_true
      end

    end

    context 'not running' do

      it 'is not running' do
        VCAP::Micro::MonitoredProcess.new('process').running?({
          'process' => { :status => { :message => 'not running' } } }
          ).should be_false
      end

    end

  end

end
