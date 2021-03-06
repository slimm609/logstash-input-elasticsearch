# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/plugin"
require "logstash/inputs/elasticsearch"
require_relative "../../../spec/es_helper"

describe LogStash::Inputs::Elasticsearch do

  let(:config)   { { 'hosts' => [ESHelper.get_host_port],
                     'index' => 'logs',
                     'query' => '{ "query": { "match": { "message": "Not found"} }}' } }
  let(:plugin) { described_class.new(config) }
  let(:event)  { LogStash::Event.new({}) }
  let(:client_options) {{}}

  before(:each) do
    @es = ESHelper.get_client(client_options)
    # Delete all templates first.
    # Clean ES of data before we start.
    @es.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    @es.indices.delete(:index => "*") rescue nil
    10.times do
      ESHelper.index_doc(@es, :index => 'logs', :body => { :response => 404, :message=> 'Not Found'})
    end
    @es.indices.refresh
    plugin.register
  end

  after(:each) do
    @es.indices.delete_template(:name => "*")
    @es.indices.delete(:index => "*") rescue nil
  end

  shared_examples 'an elasticsearch index plugin' do
    it 'should retrieve json event from elasticsearch' do
      queue = []
      plugin.run(queue)
      event = queue.pop
      expect(event).to be_a(LogStash::Event)
      expect(event.get("response")).to eql(404)
    end
  end

  describe 'against an unsecured elasticsearch', :integration => true do
    it_behaves_like 'an elasticsearch index plugin'
  end

  describe 'against a secured elasticsearch', :secure_integration => true do
    let(:user) { 'simpleuser' }
    let(:password) { 'abc123' }
    let(:ca_file) { "spec/fixtures/test_certs/test.crt" }
    let(:client_options) {{:ca_file => ca_file, :user => user, :password => password}}
    let(:config)   { super.merge({
                       'user' => user,
                       'password' => password,
                       'ssl' => true,
                       'ca_file' => ca_file })
    }
    it_behaves_like 'an elasticsearch index plugin'
  end
end

