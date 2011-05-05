require 'slither'
class RemoteTable
  class Format
    class FixedWidth < Format
      include Textual
      def each(&blk)
        remove_useless_characters!
        crop_rows!
        skip_rows!
        cut_columns!
        parser.parse[:rows].each do |row|
          row.reject! { |k, v| k.blank? }
          row.each do |k, v|
            row[k] = utf8 v
          end
          yield row if t.properties.keep_blank_rows or row.any? { |k, v| v.present? }
        end
      ensure
        t.local_file.delete
      end
      
      private
      
      def parser
        @parser ||= ::Slither::Parser.new definition, t.local_file.path
      end
      
      def definition
        @definition ||= if t.properties.schema_name.is_a?(::String) or t.properties.schema_name.is_a?(::Symbol)
          ::Slither.send :definition, t.properties.schema_name
        elsif t.properties.schema.is_a?(::Array)
          everything = lambda { |_| true }
          srand # in case this was forked by resque
          ::Slither.define(rand.to_s) do |d|
            d.rows do |row|
              row.trap(&everything)
              t.properties.schema.each do |name, width, options|
                if name == 'spacer'
                  row.spacer width
                else
                  row.column name, width, options
                end
              end
            end
          end
        else
          raise "expecting schema_name to be a String or Symbol, or schema to be an Array"
        end
      end
    end
  end
end
