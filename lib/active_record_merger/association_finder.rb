# frozen_string_literal: true

module AssociationFinder
  extend self

  AssociationInfo = Struct.new(:name, :type, :class_name, :foreign_key, :through, :polymorphic,
                               :foreign_type, keyword_init: true)

  # Finds and returns associations for a given ActiveRecord model.
  def call(model_class, filter = ->(_assoc) { true })
    model_class.reflect_on_all_associations.map do |assoc|
      AssociationInfo.new(
        name:         assoc.name,
        type:         assoc.macro,
        class_name:   assoc.class_name,
        foreign_key:  assoc.foreign_key,
        foreign_type: assoc.foreign_type,
        through:      assoc.options[:through],
        polymorphic:  assoc.options[:polymorphic],
      )
    end.select { |assoc| filter.call(assoc) }
  end

end

