# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe "Emitter" do
  describe "#emit_yaml" do
    describe "Output with comments" do
      Dir.glob("emitter/**/*-in.yml", base: __dir__) do |input|
        output = input.sub(/-in\.yml$/, "-out.yml")
        it "#{input}" do
          ast = Psych::Comments.parse_stream(File.read(File.join(__dir__, input)))
          out = Psych::Comments.emit_yaml(ast)
          if ENV["UPDATE_SNAPSHOTS"] == "true"
            File.write(File.join(__dir__, output), out)
          else
            expect(out).to eq(File.read(File.join(__dir__, output)))
          end
        end
      end
    end

    describe "Comment-less output" do
      Dir.glob("emitter/**/*-in.yml", base: __dir__) do |input|
        output = input.sub(/-in\.yml$/, "-out-wc.yml")
        it "#{input}" do
          ast = Psych.parse_stream(File.read(File.join(__dir__, input)))
          out = Psych::Comments.emit_yaml(ast)
          if ENV["UPDATE_SNAPSHOTS"] == "true"
            File.write(File.join(__dir__, output), out)
          else
            expect(out).to eq(File.read(File.join(__dir__, output)))
          end
        end
      end
    end

    describe "Comparison with Psych" do
      Dir.glob("emitter/**/*-in.yml", base: __dir__) do |input|
        it "#{input}" do
          ast = Psych.parse_stream(File.read(File.join(__dir__, input)))
          expect(Psych::Comments.emit_yaml(ast)).to eq(ast.to_yaml)
        end
      end
    end
  end
end
