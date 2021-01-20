require 'puppet_x'
require 'singleton'

# Encore module
module PuppetX::Encore
end

module PuppetX::Encore::Ipa
  # Class for caching HTTP clients
  class Cache
    include Singleton
    attr_accessor :cached_clients

    def initialize
      @cached_clients = {}
    end
  end
end
