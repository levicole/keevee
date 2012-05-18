require 'rubygems'
require 'eventmachine'

module KeeVee
  class Config
    attr_accessor :adapter, :adapter_options

    def adapter=(adapter)
      @adapter = classify_adapter(adapter).new(adapter_options)
    end

    def classify_adapter(adapter)
      camel_list = adapter.to_s.split("_").map(&:capitalize)
      camel_list << 'Adapter' unless camel_list.last == 'Adapter'
      Object.const_get(camel_list.join)
    end

    private :classify_adapter
  end

  def self.config
    @config ||= KeeVee::Config.new
  end

  def self.configure(&block)
    block.call(config)
  end

  def self.adapter
    self.config.adapter
  end

  def self.get(key)
    self.adapter.get(key)
  end

  def self.set(key, value)
    self.adapter.set(key, value)
  end

  def self.delete(key)
    self.adapter.delete(key)
  end

  def self.keys(key)
    self.adapter.keys
  end

  class Server < EventMachine::Connection
    def receive_data data
      data.scan(/^(set|get|delete|keys)\s([^\s]*)(?:\s"([^\"]*)")?$/) do |command, key, value|
        case command
        when "SET", "set"
          do_set(key, value)
        when "GET", "get"
          do_get(key)
        when "DELETE", "delete"
        else
          send_data "I don't know that comand"
        end
      end
    end

    def do_set(key, value)
      if value
        KeeVee.set(key, value)
        send_data "OK"
      else
        send_data "Missing value"
      end
    end

    def do_get(key)
      value = KeeVee.get(key)
      send_data value || "Not found"
    end

    def do_delete(key)
      puts "deleting #{key}"
      KeeVee.delete(key)
      send_data "OK"
    end
  end
end

class PstoreAdapter
  require 'pstore'

  def initialize(options)
    @store = PStore.new(options[:file], options[:thread_safe])
  end

  def get(key)
    @store.transaction do
      @store[key]
    end
  end

  def set(key, value)
    @store.transaction do
      @store[key.to_s] = value
      @store.commit
    end
  end

  def delete
    @store.transaction do
      @store.delete(key.to_s)
      @store.commit
    end
  end

  def keys
    @store.transaction do
      @store.roots
    end
  end
end


KeeVee.configure do |config|
  config.adapter_options = {:file => 'test.store', :thread_safe => false }
  config.adapter = :pstore
end

EventMachine::run {
  EventMachine::start_server "127.0.0.1", 8081, KeeVee::Server
}
