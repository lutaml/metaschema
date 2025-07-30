# frozen_string_literal: true

module ModelHelper
  private

  def a_model(name = nil, **attrs)
    matcher = be_a(Class).and(include(Lutaml::Model::Serialize))
    attrs[:to_s] = name if name
    matcher = matcher.and(have_attributes(attrs)) if attrs.any?
    matcher
  end
  alias be_a_model a_model

  def an_attribute(name, type, **opts)
    type = lookup_type(type) if type.is_a?(Symbol)
    have_attributes(
      name: name,
      type: type,
      raw?: false,
      options: {},
      validations: nil,
      **opts
    )
  end
  alias be_an_attribute an_attribute

  def lookup_type(type_name)
    Lutaml::Model::Type.lookup(type_name)
  end
end
