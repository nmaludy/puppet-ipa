require 'puppet_x/encore/ipa'
require 'singleton'

module PuppetX::Encore::Ipa
  # Class for caching HTTP clients
  class Cache
    include Singleton
    attr_accessor :cached_clients
    attr_accessor :cached_instances

    def initialize
      @cached_clients = {}
      @cached_instances = {}
    end
  end
end
