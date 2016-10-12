require 'dogeify/version'
require 'engtagger'

class Dogeify
  ADJECTIVES = %w{so such very much many how}.freeze
  ADJECTIVE_MAP = {:adjective => %w{such many},
                   :singular_noun => %w{so such very much many how},
                   :plural_noun => %w{so such very much many how},
                   :infinitive_verb => %w{so such very much many how},
                   :adverb => %w{such very much many how}}.freeze
  EMOTIONS = %w{wow amaze excite}.freeze
  IGNORE_PATTERNS = %w{i im be do have} + ADJECTIVES + EMOTIONS
  TAGS = {:jj => :adjective,
    :jjr => :adjective,
    :jjs => :adjective,
    :nn => :singular_noun,
    :nnp => :singular_noun,
    :nnps => :plural_noun,
    :nns => :plural_noun,
    :rbr => :adverb,
    :rbs => :adverb,
    :vb => :infinitive_verb}.freeze

  def initialize
    @tagger = EngTagger.new
    @adjectives = ADJECTIVES.dup
    @pos_adjectives = {}
    @emotions = []
  end

  def process(str, options = {})
    # Remove punctuation and extra whitespace.
    str = str.strip.gsub(/\s+/, " ").gsub(/[\:"\(\)\{\}]+/, " ").gsub("'", "")
    # Parse sentences.
    sentences = str.downcase.split(/[\.!?]+/).map(&:strip)
    ignore = IGNORE_PATTERNS | (Array(options[:ignore]) || [])
    sentences = sentences.map do |sentence|
      sentence = ignore_patterns(sentence, ignore)
      tagged_sentence = tagger.add_tags(sentence) || next
      translated_phrases = []
      tagged_sentence.scan(/<.+?>.+?<\/.+?>/).each do |phrase|
        tag = phrase.scan(/<(.+?)>.+$/).flatten.first
        if (pos = part_of_speech(tag))
          word = phrase.scan(/<.+?>(.+?)<\/.+?>/).flatten.first
          translated_phrases << "#{adjective(pos)} #{correct_spelling(word)}."
        end
      end

      # Add emotion words.
      translated_phrases_with_emotions = []
      translated_phrases.each_slice(3) do |slice|
        translated_phrases_with_emotions << slice << emotional_summary
      end

      translated_phrases_with_emotions.flatten.join(' ')
    end

    output = sentences.delete_if {|s| s.nil? || s.empty?}.join(' ')
    output.empty? ? emotional_summary : output
  end

  private

  attr_accessor :adjectives, :emotions, :pos_adjectives, :tagger

  def adjective(part_of_speech)
    @pos_adjectives[part_of_speech] ||= []
    @pos_adjectives[part_of_speech] += ADJECTIVE_MAP[part_of_speech] if @pos_adjectives[part_of_speech].empty?
    @adjectives += ADJECTIVES if @adjectives.empty?
    determine_unused_adjective(@adjectives, @pos_adjectives[part_of_speech]) || @pos_adjectives[part_of_speech].sample
  end

  def determine_unused_adjective(overall_adjs, part_of_speech_adjs)
    return nil if part_of_speech_adjs.empty?
    shared_adjs = overall_adjs & part_of_speech_adjs
    random_adj = shared_adjs.sample
    if random_adj.nil?
      nil
    elsif overall_adjs.delete(random_adj)
      part_of_speech_adjs.delete(random_adj)
    else
      determine_unused_adjective(overall_adjs, part_of_speech_adjs  - [random_adj])
    end
  end

  def correct_spelling(word)
    word.dup.tap do |word|
      word.gsub!(/er$/, 'ar')                    # super => supar
      word.gsub!(/ph/, 'f')                      # phone => fone
      word.gsub!(/cious/, 'shus')                # delicious => delishus, deliciousness => delishusness
      word.gsub!(/([^s])tion(s$)?/, '\1shun\2')  # emotion => emoshun, emotions => emoshuns, emotionless => emoshunless, question (unchanged)
      word.gsub!(/stion$/, 'schun')              # question => queschun, potion (unchanged)
      word.gsub!(/dog([^e]|\b)/, 'doge\1')       # dog => doge, dogs => doges, underdog => underdoge, doge (unchanged)
    end
  end

  def emotion
    @emotions += EMOTIONS if @emotions.empty?
    @emotions.delete(@emotions.sample)
  end 

  def emotional_summary
    "#{emotion}."
  end

  def ignore_patterns(sentence, patterns)
    string_patterns = patterns.find_all {|pattern| pattern.is_a?(String)}
    regex_patterns = patterns.find_all {|pattern| pattern.is_a?(Regexp)}
    string_replaced_sentence = sentence.scan(/['\-\w]+/).delete_if {|word| string_patterns.include?(word.downcase)}.join(" ")
    string_replaced_sentence.tap do |string_replaced_sentence|
      regex_patterns.map {|pattern| string_replaced_sentence.gsub!(pattern, '')}
    end
  end

  def part_of_speech(tag)
    TAGS[tag.to_sym]
  end
end
