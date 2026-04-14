# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Ruby gem implementing a parser and generator for the [NIST Metaschema Information Modeling Framework](https://pages.nist.gov/metaschema). It parses Metaschema XML files and can round-trip them (parse to Ruby objects and back to XML).

## Common Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake spec

# Run a single test file
bundle exec rspec spec/metaschema_spec.rb

# Run tests with specific format
bundle exec rspec spec/metaschema_spec.rb --format documentation

# Run linting
bundle exec rake rubocop

# Auto-correct linting issues
bundle exec rake rubocop:autocorrect_all

# Build the gem
bundle exec rake build
```

## Architecture

The gem uses **lutaml-model** with **Nokogiri** for XML serialization/deserialization. All model classes inherit from `Lutaml::Model::Serializable`.

### Entry Point

`lib/metaschema/root.rb` - The `Metaschema::Root` class is the top-level model representing a complete Metaschema XML document. It contains:
- `schema_name`, `schema_version`, `short_name`, `namespace`, `json_base_uri`
- Top-level definitions: `define_assembly`, `define_field`, `define_flag`
- Imports and namespace bindings

### Type System

The `lib/metaschema/` directory contains ~74 type classes. Key patterns:

- **Definition types** (e.g., `GlobalAssemblyDefinitionType`, `GlobalFieldDefinitionType`) - Define schema structures with `name`, `formal_name`, `description`, `model`, `constraint`
- **Reference types** (e.g., `AssemblyReferenceType`, `FieldReferenceType`) - Reference definitions by name
- **Inline definition types** (e.g., `InlineAssemblyDefinitionType`) - Definitions nested within other definitions
- **Constraint types** (e.g., `DefineAssemblyConstraintsType`, `AllowedValuesType`) - Validation constraints
- **Value types** (e.g., `MarkupLineDatatype`, `FormalName`) - Simple value wrappers

Each type class uses the lutaml-model XML DSL:
```ruby
xml do
  element "ElementName"
  ordered  # children must appear in defined order
  namespace ::Metaschema::Namespace
  map_attribute "attr", to: :attr_name
  map_element "child-element", to: :child_attr
end
```

### Test Fixtures

- `spec/fixtures/metaschema/` - Submoduled NIST Metaschema project containing test schemas
- `spec/fixtures/metaschema/examples/` - Example Metaschema XML files (e.g., `computer-example.xml`)
- `spec/fixtures/metaschema/test-suite/schema-generation/` - Feature-specific test cases

### Loading a Metaschema File

```ruby
require 'metaschema'
ms = Metaschema::Root.from_file("path/to/metaschema.xml")
ms.to_xml  # Returns XML string
```
