# ActiveRecordMerger

The `ActiveRecordMerger` gem provides functionality for merging ActiveRecord objects along with their associated records. It's designed to simplify the process of combining duplicate records into a single record, while also ensuring that all associated data is correctly updated and maintained.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record_merger'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install active_record_merger
```

## Usage

`ActiveRecordMerger` is designed to assist in merging two ActiveRecord objects and their associated records. This can be especially useful for consolidating duplicate records in your database.

### Basic Setup

Before you begin, you must decide which of the two records will be the 'primary' record (the one to be kept) and which will be the 'secondary' record (the one to be merged and then optionally deleted). By default, without any custom logic, `ActiveRecordMerger` will not alter the attributes of the primary record.

```ruby
primary_record = YourModel.find(primary_id)
secondary_record = YourModel.find(secondary_id)

merger = ActiveRecordMerger::RecordMerger.new(
  primary_record,
  secondary_record,
  options: {} # Additional options can be provided here
)
merge_result = merger.call
```

In this basic example, `merge_result` will contain information about the merge process, such as which associations were updated. Note that without additional configurations, no attributes from the secondary record will be copied to the primary record, and no records will be destroyed.


## Default Options and Customization

The `ActiveRecordMerger` provides several options to customize the merging process. By default, these options are set to perform the most common actions expected during a record merge, but they can be customized to fit specific needs:

1. **primary_record_resolver**: Determines which of the two records is considered the 'primary' record. By default, this is `nil`, meaning the first record provided to the merger is treated as the primary record.

2. **merge_logic**: Defines how attributes from the secondary record should be merged into the primary record. The default is `nil`, indicating that no attribute merging occurs unless explicitly specified.

3. **update_logic**: Provides custom logic for updating associations to re-associate the secondary record's related objects to the primary record. The default is `nil`, which updates foreign keys on direct associations (has_many, has_one) from the secondary to the primary record without additional logic.

4. **destroy_merged_record**: Controls whether the secondary record should be destroyed after the merging process. The default is `false`, meaning the secondary record will remain in the database unless this option is explicitly set to `true`.

5. **filter**: A callable object (like a lambda or Proc) that filters which associations should be updated based on certain criteria. By default, this is `->(assoc) { :belongs_to != assoc.type && assoc.through.nil? && !assoc.polymorphic }`, meaning we filter out all associations that are not direct or that are `:belongs_to`.

### Using Filters

Filters allow you to specify which associations should be updated when merging records. This can be particularly useful if you only want to update certain types of associations or if you want to exclude specific associations based on certain conditions.

For example, if you only want to update `has_many` and `has_one` associations, and ignore `belongs_to` and `has_and_belongs_to_many` associations, you can use the following filter:

```ruby
options = {
  filter: ->(assoc) {
    [:has_many, :has_one].include?(assoc.type) && !assoc.polymorphic
  }
}
```

In this example, the filter is a lambda that checks the type of each association. It returns `true` only for associations that are either `has_many` or `has_one` and not polymorphic, meaning only these associations will be considered for updating during the merge process.

You can customize this filter further to include your business logic, for example, excluding certain associations based on their name or custom options:

```ruby
options = {
  filter: ->(assoc) {
    # Only update associations that are not polymorphic and are not named :account
    !assoc.polymorphic && assoc.name != :account
  }
}
```

In this adjusted example, the filter additionally prevents any association named `:account` from being updated, regardless of its type.


### Customizing Merge Behavior

You can customize the merge behavior by providing lambdas (or any other callable object) for various operations:

1. **Primary Record Resolver (`:primary_record_resolver`):**

   Determines which record should be considered primary. By default, the first record provided is treated as primary.

    ```ruby
    options = {
      primary_record_resolver: lambda { |first, second| [first, second].min_by(&:created_at) }
    }
    ```

   This example chooses the older record as the primary record.

2. **Merge Logic (`:merge_logic`):**

   Defines how to merge attributes from the secondary record into the primary record. By default, attributes are not merged.

    ```ruby
    options = {
      merge_logic: lambda { |primary, secondary| 
        primary.update(name: secondary.name) if primary.name.blank?
      }
    }
    ```

   In this example, the primary record’s name is updated with the secondary's name if it was originally blank.

3. **Update Logic (`:update_logic`):**

   Custom logic for how associated records should be updated. This is important for re-associating related records from the secondary record to the primary record.

    ```ruby
    options = {
      update_logic: lambda { |association, primary, secondary|
        # Custom association update logic here
      }
    }
    ```

   Define how each association should handle transferring related records from the secondary to the primary record.

4. **Destroy Merged Record (`:destroy_merged_record`):**

   Determines whether the secondary record should be destroyed after merging.

    ```ruby
    options = {
      destroy_merged_record: true
    }
    ```

   If set to `true`, the secondary record will be deleted from the database after the merge process is complete.

### Comprehensive Example

Combining all the options for a full-fledged merge process:

```ruby
options = {
  primary_record_resolver: lambda { |first, second| [first, second].min_by(&:created_at) },
  merge_logic: lambda { |primary, secondary| 
    primary.update(name: secondary.name) if primary.name.blank?
  },
  update_logic: lambda { |association, primary, secondary| 
    # Update association references from secondary to primary
  },
  destroy_merged_record: true
}

merger = ActiveRecordMerger::RecordMerger.call(primary_record, secondary_record, options)
merge_result = merger.result
```

This comprehensive example sets up a merger that chooses the oldest record as the primary, updates the primary record's name if it was blank, re-associates related records, and then deletes the secondary record after the merge.



## Return Values and Error Handling

The `ActiveRecordMerger` utilizes `SimpleCommand` for executing the merge process, providing structured outcomes and error handling.

### Result of Merge Operation

After the merge operation is completed using the `.call` method, the result can be accessed via the `@result` instance variable of the `RecordMerger` object. This result contains information about the merge process, typically including updated records count or other relevant data depending on the provided options and the merge logic:

```ruby
merger = ActiveRecordMerger::RecordMerger.call(primary_record, secondary_record, options)

if merger.success?
  puts "Merge successful!"
  merge_details = merger.result
  # Access detailed result information from merge_details
else
  puts "Merge failed: #{merger.errors.full_messages.join(', ')}"
end
```

In this example, `merger.result` will contain the outcome of the merge operation if it was successful. The exact structure of this result depends on how you've implemented your merge logic and what information you've chosen to include.

### Handling Errors

If there are any issues during the merge process, such as validation failures or conflicts in the custom logic, the errors will be accumulated in the `.errors` method of the `RecordMerger` object. This method returns an instance of `SimpleCommand::Errors`, which provides a list of error messages:

```ruby
unless merger.success?
  puts "Merge failed due to the following errors:"
  merger.errors.full_messages.each { |error_message| puts "- #{error_message}" }
end
```

These errors can be used to understand what went wrong during the merge process and to inform users of the specific issues that need resolution. The `success?` method, provided by `SimpleCommand`, is a convenient way to check whether the operation completed successfully or if there were errors that prevented a successful merge.


## Configuration

No additional configuration is required. However, you can customize the behavior by providing different options as shown above.

## Contributing

Contributions are welcome! Feel free to open a pull request or an issue to propose changes or additions.

## License

The gem is available as open source under the terms of the MIT License.

## Code of Conduct

Everyone interacting in the ActiveRecordMerger project's codebase, issue trackers, chat rooms, and mailing lists is expected to follow the code of conduct.
