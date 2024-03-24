# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/active_record_merger/association_finder'

require 'ostruct'
RSpec.describe ActiveRecordMerger::AssociationFinder do
  # Dummy classes to mimic ActiveRecord models
  before do
    class User < Struct.new(:name); end

    class Profile < Struct.new(:user_id); end
  end

  describe '.call' do
    context 'when filtering associations without any conditions' do
      it 'returns all associations of the model' do
        allow(User).to receive(:reflect_on_all_associations).and_return([
                                                                          OpenStruct.new(name: :profile, macro: :has_one, class_name: 'Profile', foreign_key: 'user_id', foreign_type: nil, through: nil, polymorphic: false, options: {}),
                                                                        # Add more mock associations as needed
                                                                        ])

        associations = described_class.call(User)
        expect(associations.size).to eq(1)
        expect(associations.first.name).to eq(:profile)
        expect(associations.first.type).to eq(:has_one)
      end
    end

    context 'when using a custom filter' do
      it 'returns only associations that meet the filter criteria' do
        allow(User).to receive(:reflect_on_all_associations).and_return([
                                                                          OpenStruct.new(name: :profile, macro: :has_one, class_name: 'Profile', foreign_key: 'user_id', foreign_type: nil, through: nil, polymorphic: false, options: {}),
                                                                          OpenStruct.new(name: :posts, macro: :has_many, class_name: 'Post', foreign_key: 'user_id', foreign_type: nil, through: nil, polymorphic: false, options: {}),
                                                                        ])

        filter       = ->(assoc) { assoc.type == :has_many }
        associations = described_class.call(User, filter)
        expect(associations.size).to eq(1)
        expect(associations.first.name).to eq(:posts)
      end
    end
  end

  # Cleanup after tests
  after do
    Object.send(:remove_const, :User) if defined?(User)
    Object.send(:remove_const, :Profile) if defined?(Profile)
  end
end