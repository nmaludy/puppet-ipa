require 'puppet_x'
require 'singleton'

module PuppetX
  module Encore
    module Ipa
      class Cache
        include Singleton
        attr_accessor :cached_clients

        def initialize
          @cached_clients = {}
        end
      end
    end
  end
end
