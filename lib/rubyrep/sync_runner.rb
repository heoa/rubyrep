$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

module RR
  # This class implements the functionality of the rrsync.rb command.
  class SyncRunner < BaseRunner

    # Returns summary description string for the scan command.
    def summary_description
      "Syncs the differences of the specified tables between both databases."
    end

    # Add SyncRunner specific options to the provided OptionParser object.
    def add_specific_options(opts)
      opts.on("--no-table-ordering", "Disable automatic table ordering") do
        options[:no_table_ordering] = true
      end
    end

    # Creates the correct scan class.
    # Parameters as defined under BaseRunner#create_processor
    def create_processor(left_table, right_table)
      TableSync.new session, left_table, right_table
    end

    def table_ordering?
      session.configuration.options[:table_ordering] and not options[:no_table_ordering]
    end

    # Reorders the table pairs to avoid foreign key conflicts.
    # More information on this methods at BaseRunner#prepare_table_pairs.
    def prepare_table_pairs(table_pairs)
      sorted_table_pairs = table_pairs
      if table_ordering?
        left_tables = table_pairs.map {|table_pair| table_pair[:left_table]}
        sorted_left_tables = TableSorter.new(session, left_tables).sort
        sorted_table_pairs = sorted_left_tables.map do |left_table|
          table_pairs.find do |table_pair|
            table_pair[:left_table] == left_table
          end
        end
      end
      sorted_table_pairs
    end
  end
end


