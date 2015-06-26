require 'spec_helper'
describe 'elasticsearch_report' do

  context 'with defaults for all parameters' do
    it { should contain_class('elasticsearch_report') }
  end
end
