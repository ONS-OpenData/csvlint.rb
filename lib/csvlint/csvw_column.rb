module Csvlint

  class CsvwColumn

    include Csvlint::ErrorCollector

    attr_reader :id, :about_url, :datatype, :default, :lang, :name, :null, :number, :ordered, :property_url, :required, :separator, :source_number, :suppress_output, :text_direction, :titles, :value_url, :virtual, :annotations

    def initialize(number, name, id: nil, about_url: nil, datatype: "xsd:string", default: "", lang: "und", null: "", ordered: false, property_url: nil, required: false, separator: nil, source_number: nil, suppress_output: false, text_direction: :inherit, titles: {}, value_url: nil, virtual: false, annotations: [], warnings: [])
      @number = number
      @name = name
      @id = id
      @about_url = about_url
      @datatype = datatype
      @default = default
      @lang = lang
      @null = null
      @ordered = ordered
      @property_url = property_url
      @required = required
      @separator = separator
      @source_number = source_number || number
      @suppress_output = suppress_output
      @text_direction = text_direction
      @titles = titles
      @value_url = value_url
      @virtual = virtual
      @annotations = annotations
      reset
      @warnings += warnings
    end

    def validate_header(header)
      reset
      valid_headers = @titles ? @titles.map{ |l,v| v}.flatten : []
      build_errors(:invalid_header, :schema, 1, @number, header, @titles) unless valid_headers.include? header
      return valid?
    end

    def validate(string_value, row=nil)
      reset
      values = parse(string_value, row)
      values.each do |value|
        validate_length(value, row)
      end
      return valid?
    end

    def parse(string_value, row=nil)
      return [string_value]
    end

    def CsvwColumn.from_json(number, column_desc, base_url=nil, lang="und", inherited_properties={})
      annotations = {}
      warnings = []
      column_properties = {}

      column_desc.each do |property,value|
        if property == "@type"
          raise Csvlint::CsvwMetadataError.new("columns[#{number}].@type"), "@type of column is not 'Column'" if value != 'Column'
        else
          v, warning, type = CsvwPropertyChecker.check_property(property, value, base_url, lang)
          warnings += Array(warning).map{ |w| Csvlint::ErrorMessage.new(w, :metadata, nil, nil, "#{property}: #{value}", nil) } unless warning.nil? || warning.empty?
          if type == :annotation
            annotations[property] = v
          elsif type == :common || type == :column
            column_properties[property] = v
          elsif type == :inherited
            inherited_properties[property] = v
          else
            warnings << Csvlint::ErrorMessage.new(:invalid_property, :metadata, nil, nil, "column: #{property}", nil)
          end
        end
      end

      id = column_properties["@id"]
      name = column_properties["name"]
      titles = column_properties["titles"]

      datatype = inherited_properties.include?("datatype") ? inherited_properties["datatype"] : { "@id" => "http://www.w3.org/2001/XMLSchema#string" }

      return CsvwColumn.new(number, name, id: id, datatype: datatype, titles: titles, property_url: column_desc["propertyUrl"], required: column_desc["required"] == true, annotations: annotations, warnings: warnings)
    end

    private
      def validate_length(value, row)
        if datatype["minLength"]
          build_errors(:min_length, :schema, row, number, value, { "minLength" => datatype["minLength"] }) if value.length < datatype["minLength"]
        end
      end

  end
end
