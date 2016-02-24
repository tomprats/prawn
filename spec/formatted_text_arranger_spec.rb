# encoding: utf-8

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper")

describe Prawn::Text::Formatted::Arranger do
  let(:document) { create_pdf }
  subject { Prawn::Text::Formatted::Arranger.new document }

  describe '#format_array' do
    it 'populates the unconsumed array' do
      array = [
        { text: 'hello ' },
        { text: 'world how ', styles: [:bold] },
        { text: 'are', styles: [:bold, :italic] },
        { text: ' you?' }
      ]

      subject.format_array = array

      expect(subject.unconsumed[0]).to eq(text: 'hello ')
      expect(subject.unconsumed[1]).to eq(text: 'world how ', styles: [:bold])
      expect(subject.unconsumed[2]).to eq(text: 'are', styles: [:bold, :italic])
      expect(subject.unconsumed[3]).to eq(text: ' you?')
    end

    it 'splits newlins into their own elements' do
      array = [
        { text: "\nhello\nworld" }
      ]

      subject.format_array = array

      expect(subject.unconsumed[0]).to eq(text: "\n")
      expect(subject.unconsumed[1]).to eq(text: "hello")
      expect(subject.unconsumed[2]).to eq(text: "\n")
      expect(subject.unconsumed[3]).to eq(text: "world")
    end
  end

  describe '#preview_next_string' do
    context 'with a formatted array' do
      let(:array) { [{ text: 'hello' }] }

      before do
        subject.format_array = array
      end

      it 'does not populate the consumed array' do
        subject.preview_next_string
        expect(subject.consumed).to eq([])
      end

      it 'returns the text of the next unconsumed hash' do
        expect(subject.preview_next_string).to eq("hello")
      end

      it 'returns nil if there is no more unconsumed text' do
        subject.next_string
        expect(subject.preview_next_string).to be_nil
      end
    end
  end

  describe '#next_string' do
    let(:array) {
      [
        { text: 'hello ' },
        { text: 'world how ', styles: [:bold] },
        { text: 'are', styles: [:bold, :italic] },
        { text: ' you?' }
      ]
    }

    before do
      subject.format_array = array
    end

    it 'raises RuntimeError if called after a line was finalized' do
      subject.finalize_line
      expect { subject.next_string }.to raise_error(RuntimeError)
    end

    it 'populates the conumed array' do
      while string = subject.next_string
      end

      expect(subject.consumed[0]).to eq(text: 'hello ')
      expect(subject.consumed[1]).to eq(text: 'world how ', styles: [:bold])
      expect(subject.consumed[2]).to eq(text: 'are', styles: [:bold, :italic])
      expect(subject.consumed[3]).to eq(text: ' you?')
    end

    it 'populates the current_format_state array' do
      string = subject.next_string
      expect(subject.current_format_state).to eq({})

      string = subject.next_string
      expect(subject.current_format_state).to eq(:styles => [:bold])

      string = subject.next_string
      expect(subject.current_format_state).to eq(:styles => [:bold, :italic])

      string = subject.next_string
      expect(subject.current_format_state).to eq({})
    end

    it 'returns the text of the newly consumed hash' do
      expect(subject.next_string).to eq('hello ')
    end

    it 'returns nil when there are no more unconsumed hashes' do
      4.times do
        subject.next_string
      end

      expect(subject.next_string).to be_nil
    end
  end
end

describe "Core::Text::Formatted::Arranger#retrieve_fragment" do
  it "should raise_error an error if called before finalize_line was called" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    expect do
      arranger.retrieve_fragment
    end.to raise_error(RuntimeError)
  end
  it "should return the consumed fragments in order of consumption" \
     " and update" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    expect(arranger.retrieve_fragment.text).to eq("hello ")
    expect(arranger.retrieve_fragment.text).to eq("world how ")
    expect(arranger.retrieve_fragment.text).to eq("are")
    expect(arranger.retrieve_fragment.text).to eq(" you?")
  end
  it "should never return a fragment whose text is an empty string" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello\nworld\n\n\nhow are you?" },
             { :text => "\n" },
             { :text => "\n" },
             { :text => "\n" },
             { :text => "" },
             { :text => "fine, thanks." },
             { :text => "" },
             { :text => "\n" },
             { :text => "" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    while fragment = arranger.retrieve_fragment
      expect(fragment.text).not_to be_empty
    end
  end
  it "should not alter the current font style" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    arranger.retrieve_fragment
    expect(arranger.current_format_state[:styles]).to be_nil
  end
end

describe "Core::Text::Formatted::Arranger#update_last_string" do
  it "should update the last retrieved string with what actually fit on" \
     "the line and the list of unconsumed with what did not" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?", :styles => [:bold, :italic] }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.update_last_string(" you", " now?", nil)
    expect(arranger.consumed[3]).to eq(:text => " you",
                                       :styles => [:bold, :italic])
    expect(arranger.unconsumed).to eq([{ :text => " now?",
                                         :styles => [:bold, :italic] }])
  end
  it "should set the format state to the previously processed fragment" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    3.times { arranger.next_string }
    expect(arranger.current_format_state).to eq(:styles => [:bold, :italic])
    arranger.update_last_string("", "are", "-")
    expect(arranger.current_format_state).to eq(:styles => [:bold])
  end

  context "when the entire string was used" do
    it "should not push empty string onto unconsumed" do
      create_pdf
      arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
      array = [
        { :text => "hello " },
        { :text => "world how ", :styles => [:bold] },
        { :text => "are", :styles => [:bold, :italic] },
        { :text => " you now?" }
      ]
      arranger.format_array = array
      while string = arranger.next_string
      end
      arranger.update_last_string(" you now?", "", nil)
      expect(arranger.unconsumed).to eq([])
    end
  end
end
describe "Core::Text::Formatted::Arranger#space_count" do
  before(:each) do
    create_pdf
    @arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you?" }]
    @arranger.format_array = array
    while string = @arranger.next_string
    end
  end
  it "should raise_error an error if called before finalize_line was called" do
    expect do
      @arranger.space_count
    end.to raise_error(RuntimeError)
  end
  it "should return the total number of spaces in all fragments" do
    @arranger.finalize_line
    expect(@arranger.space_count).to eq(4)
  end
end
describe "Core::Text::Formatted::Arranger#finalize_line" do
  it "should make it so that all trailing white space fragments " \
     "exclude trailing white space" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "   ", :styles => [:bold, :italic] }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    expect(arranger.fragments.length).to eq(3)

    fragment = arranger.retrieve_fragment
    expect(fragment.text).to eq("hello ")

    fragment = arranger.retrieve_fragment
    expect(fragment.text).to eq("world how")

    fragment = arranger.retrieve_fragment
    expect(fragment.text).to eq("")
  end
end

describe "Core::Text::Formatted::Arranger#line_width" do
  before(:each) do
    create_pdf
    @arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world", :styles => [:bold] }]
    @arranger.format_array = array
    while string = @arranger.next_string
    end
  end
  it "should raise_error an error if called before finalize_line was called" do
    expect do
      @arranger.line_width
    end.to raise_error(RuntimeError)
  end
  it "should return the width of the complete line" do
    @arranger.finalize_line
    expect(@arranger.line_width).to be > 0
  end
end

describe "Core::Text::Formatted::Arranger#line_width with character_spacing > 0" do
  it "should return a width greater than a line without a character_spacing" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)

    array = [{ :text => "hello " },
             { :text => "world", :styles => [:bold] }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line

    base_line_width = arranger.line_width

    array = [{ :text => "hello " },
             { :text => "world", :styles => [:bold],
               :character_spacing => 7 }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    expect(arranger.line_width).to be > base_line_width
  end
end

describe "Core::Text::Formatted::Arranger#line" do
  before(:each) do
    create_pdf
    @arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world", :styles => [:bold] }]
    @arranger.format_array = array
    while string = @arranger.next_string
    end
  end
  it "should raise_error an error if called before finalize_line was called" do
    expect do
      @arranger.line
    end.to raise_error(RuntimeError)
  end
  it "should return the complete line" do
    @arranger.finalize_line
    expect(@arranger.line).to eq("hello world")
  end
end

describe "Core::Text::Formatted::Arranger#unconsumed" do
  it "should return the original array if nothing was consumed" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    expect(arranger.unconsumed).to eq(array)
  end
  it "should return an empty array if everything was consumed" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    expect(arranger.unconsumed).to eq([])
  end
end

describe "Core::Text::Formatted::Arranger#finished" do
  it "should be_false if anything was not printed" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.update_last_string(" you", "now?", nil)
    expect(arranger).not_to be_finished
  end
  it "should be_false if everything was printed" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    expect(arranger).to be_finished
  end
end

describe "Core::Text::Formatted::Arranger.max_line_height" do
  it "should be the height of the maximum consumed fragment" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic],
               :size => 28 },
             { :text => " you now?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    expect(arranger.max_line_height).to be_within(0.0001).of(33.32)
  end
end

describe "Core::Text::Formatted::Arranger#repack_unretrieved" do
  it "should restore part of the original string" do
    create_pdf
    arranger = Prawn::Text::Formatted::Arranger.new(@pdf)
    array = [{ :text => "hello " },
             { :text => "world how ", :styles => [:bold] },
             { :text => "are", :styles => [:bold, :italic] },
             { :text => " you now?" }]
    arranger.format_array = array
    while string = arranger.next_string
    end
    arranger.finalize_line
    arranger.retrieve_fragment
    arranger.retrieve_fragment
    arranger.repack_unretrieved
    expect(arranger.unconsumed).to eq([
      { :text => "are", :styles => [:bold, :italic] },
      { :text => " you now?" }
    ])
  end
end
