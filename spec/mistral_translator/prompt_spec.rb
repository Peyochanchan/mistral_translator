# frozen_string_literal: true

RSpec.describe MistralTranslator::Prompt do
  subject(:prompt) { described_class.for_text("Consignes", "Texte") }

  it "sends the instructions as system and the text as user" do
    expect(prompt.messages).to eq([
                                    { role: "system", content: "Consignes" },
                                    { role: "user", content: "<<<TEXTE>>>\nTexte\n<<<FIN_TEXTE>>>" }
                                  ])
  end

  it "keeps a single-text form for callers expecting a String" do
    expect(prompt.to_s).to eq("Consignes\n<<<TEXTE>>>\nTexte\n<<<FIN_TEXTE>>>")
    expect(prompt.length).to eq(prompt.to_s.length)
  end

  it "is immutable" do
    expect(prompt).to be_frozen
  end
end
