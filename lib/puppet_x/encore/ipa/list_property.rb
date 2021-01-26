require 'puppet/property'
require 'puppet_x/encore/ipa'

module PuppetX::Encore::Ipa
  # This class implements an array/list property and handles things like sorting
  # for you so we can properly compute the difference between the requested list in
  # PuppetDSL and the "actual" list read in from the provider.
  #
  # This class also helps by implementing the "membership" concept meaning
  # whether specified members should be considered the **complete list**.
  #  :inclusive = the list given in PuppetDSL should be the complete list
  #  :minimum = the list given in PuppetDSL should be contained in the list, but is allowed to have extras
  #
  # To determine what type of "membership" we read from another type's property
  # defined by the membership() method, default is :membership. If you want to use
  # a different property name for your membership determination just override this
  # method in your newproperty() definition block.
  class ListProperty < Puppet::Property
    def membership
      :membership
    end

    def inclusive?
      @resource[membership] == :inclusive
    end

    def sort_array(a)
      # sort the array so we can compute the difference correct and order doesn't matter
      a.nil? ? [] : make_array(a).sort
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
