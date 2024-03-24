# frozen_string_literal: true
require 'simple_command'
require 'active_record'
require_relative 'association_finder'

module ActiveRecordMerger
  ##
  # This class performs the merging of two ActiveRecord objects of the same type.
  # It updates associated records to reflect the merge and can optionally destroy the merged record.
  #
  class RecordMerger
    prepend ::SimpleCommand

    attr_reader :primary_record, :secondary_record, :update_counts, :options

    ##
    # Initializes the RecordMerger service object.
    # @param first [ActiveRecord::Base] The record to merge into.
    # @param second [ActiveRecord::Base] The record to merge from.
    # @param options [Hash] The options to customize the merge process.
    # @option options [Proc] :primary_record_resolver (nil) A lambda or Proc that determines which record is considered primary.
    # @option options [Proc] :merge_logic (nil) A lambda or Proc that defines how to merge data from the secondary record into the primary record.
    # @option options [Boolean] :destroy_merged_record (false) Whether to destroy the merged (secondary) record after the merge.
    # @option options [Proc] :filter (->(assoc) { true }) A lambda or Proc that filters which associations should be updated.
    # @option options [Proc] :update_logic (nil) A lambda or Proc that provides custom logic for updating associations.
    #
    def initialize(first, second, **options)
      @_first        = first
      @_second       = second
      @options       = default_options.merge(options)
      @update_counts = {}
    end

    ##
    # Executes the merge operation.
    # Returns a hash containing the counts of updated records for each association, and the destruction status of the merged record.
    # @return [Hash] The result of merge operation with update counts and destruction status.
    #
    def call
      ::ActiveRecord::Base.transaction do
        ensure_same_class
        resolve_primary_and_secondary
        apply_merge_logic
        update_associations
        destroy_secondary_record if options[:destroy_merged_record]
      end
      @update_counts
    rescue => e
      errors.add(:base, "Failed to merge records: #{e.message}")
      nil
    end

    private

    # Provides default options for merging records.
    # @return [Hash] Default options for merge.
    def default_options
      {
        filter:                  ->(assoc) {
          :belongs_to != assoc.type && assoc.through.nil? && !assoc.polymorphic
        },

        destroy_merged_record:   false,
        primary_record_resolver: nil,
        merge_logic:             nil,
        update_logic:            nil,
      }
    end

    def ensure_same_class
      unless @_first.class == @_second.class
        raise ::ArgumentError, 'Records must be of the same class to be merged.'
      end
    end

    # Resolves which record should be considered the primary and which the secondary.
    def resolve_primary_and_secondary
      # Determine the primary record using the custom logic provided by the resolver.
      @primary_record = options[:primary_record_resolver] ? options[:primary_record_resolver].call(@_first, @_second) : @_first

      # The secondary record is the one that is not the primary.
      @secondary_record = @_first == @primary_record ? @_second : @_first
    end

    # Applies custom logic for merging data from the secondary record into the primary record.
    def apply_merge_logic
      options[:merge_logic]&.call(@primary_record, @secondary_record)
    end

    # Updates associations from the secondary record to reference the primary record.
    def update_associations
      associations = AssociationFinder.call(@primary_record.class, options[:filter])
      associations.each do |assoc|
        if options[:update_logic]
          # Here, we're passing the association, the primary record, and the secondary record to the custom logic
          @update_counts[assoc.name] = options[:update_logic].call(assoc, @primary_record, @secondary_record)
        else
          # Default update logic: re-associate records from the secondary to the primary
          associated_class           = assoc.class_name.constantize
          foreign_key                = assoc.foreign_key
          @update_counts[assoc.name] = associated_class.where(foreign_key => @secondary_record.id).update_all(foreign_key => @primary_record.id)
        end
      end
    end

    # Destroys the secondary record if flagged for destruction.
    def destroy_secondary_record
      @secondary_record.destroy
      @update_counts[:destroyed] = @secondary_record.destroyed?
    end

  end
end
