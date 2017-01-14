require 'bundler'
require 'yaml'
require 'json_schema'
require 'singleton'

class LoadableConfig
  class << self
    attr_reader :_attributes, :_config_file
  end

  def self.inherited(subclass)
    subclass.send(:include, Singleton)
  end

  def self.config_file(path)
    @_config_file = File.join(Bundler.root, path)
  end

  def self.attribute(attr, type: :string)
    @_attributes ||= {}
    _attributes[attr.to_s] = type.to_s
    attr_accessor attr

    singleton_class.instance_eval do
      define_method(attr){ instance.send(attr) }
    end
  end

  def self.attributes(*attrs, type: :string)
    attrs.each do |attr|
      attribute(attr, type: type)
    end
  end

  def initialize
    unless File.exist?(self.class._config_file)
      raise RuntimeError.new("Cannot configure #{self.class.name}: configuration file '#{self.class._config_file}' missing")
    end

    config = YAML.load(File.open(self.class._config_file, "r"))

    valid, errors = _schema.validate(config)
    unless valid
      raise ArgumentError.new("Errors parsing #{self.class.name}:\n" +
                              errors.map { |e| "#{e.pointer}: #{e.message}" }.join("\n"))
    end

    self.class._attributes.each_key do |attr|
      self.public_send(:"#{attr}=", config[attr])
    end

    self.freeze
  end

  private

  def _schema
    JsonSchema.parse!(
      'type'                 => 'object',
      'description'          => "#{self.class.name} Configuration",
      'properties'           => self.class._attributes.each_with_object({}) do |(attr, type), h|
        h[attr] = { 'type' => type }
      end,
      'required'             => self.class._attributes.keys,
      'additionalProperties' => false
    )
  end
end
