require 'puppet/property'
require 'puppet_x/encore/ipa'

module PuppetX::Encore::Ipa
  class ListProperty < Puppet::Property

    def membership
      :membership
    end
    
    def inclusive?
      @resource[membership] == :inclusive
    end
    
    # sort the array so we can compute the difference correct and order doesn't matter
    def sort_array(a)
      (a.nil?) ? [] : make_array(a).sort
    end

    def make_array(a)
      a.is_a?(Array) ? a : [a]
    end
    
    def should
      members = make_array(super)

      # inclusive means we are managing everything so if it isn't in should, its gone
      unless inclusive?
        current = retrieve
        members += make_array(current) if current && current != :absent
        members.uniq!
      end

      sort_array(members)
    end

    def should=(values)
      super(sort_array(values))
    end

    def insync?(is)
      return true unless is
      sort_array(is) == should
    end
  end
end
