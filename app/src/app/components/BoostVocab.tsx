import { useState } from 'react';

interface WordPair {
  id: string;
  word: string;
  meaning: string;
}

export default function BoostVocab() {
  const [wordPairs, setWordPairs] = useState<WordPair[]>([]);
  const [currentWord, setCurrentWord] = useState('');
  const [currentMeaning, setCurrentMeaning] = useState('');
  const [paragraph, setParagraph] = useState('');

  const addWordPair = () => {
    if (currentWord.trim() && currentMeaning.trim()) {
      setWordPairs([
        ...wordPairs,
        { id: Date.now().toString(), word: currentWord.trim(), meaning: currentMeaning.trim() }
      ]);
      setCurrentWord('');
      setCurrentMeaning('');
    }
  };

  const removeWordPair = (id: string) => {
    setWordPairs(wordPairs.filter(pair => pair.id !== id));
  };

  const highlightWords = (text: string) => {
    if (wordPairs.length === 0) return text;

    const words = wordPairs.map(pair => pair.word.toLowerCase());
    const regex = new RegExp(`\\b(${words.join('|')})\\b`, 'gi');

    const parts: JSX.Element[] = [];
    let lastIndex = 0;
    let match;
    let key = 0;

    const tempRegex = new RegExp(regex);
    while ((match = tempRegex.exec(text)) !== null) {
      if (match.index > lastIndex) {
        parts.push(<span key={`text-${key++}`}>{text.substring(lastIndex, match.index)}</span>);
      }
      parts.push(
        <mark
          key={`highlight-${key++}`}
          className="bg-secondary px-1 rounded-none"
          style={{ border: '2px solid #EA580B' }}
        >
          {match[0]}
        </mark>
      );
      lastIndex = match.index + match[0].length;
    }

    if (lastIndex < text.length) {
      parts.push(<span key={`text-${key++}`}>{text.substring(lastIndex)}</span>);
    }

    return parts.length > 0 ? parts : text;
  };

  return (
    <div className="w-full p-8">
      <div className="flex flex-col lg:flex-row gap-8">
        {/* Left Side - Word Entry */}
        <div className="flex-1 flex flex-col gap-6">
          <div className="border-4 border-primary bg-card p-6 transition-transform hover:scale-105">
            <div className="flex gap-4">
              <div className="flex-1">
                <label className="block mb-3">Word</label>
                <input
                  type="text"
                  value={currentWord}
                  onChange={(e) => setCurrentWord(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && addWordPair()}
                  className="w-full border-4 border-primary bg-input-background p-4 focus:outline-none focus:border-secondary"
                  style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}
                  placeholder="Enter a word..."
                />
              </div>
              <div className="flex-1">
                <label className="block mb-3">Meaning</label>
                <input
                  type="text"
                  value={currentMeaning}
                  onChange={(e) => setCurrentMeaning(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && addWordPair()}
                  className="w-full border-4 border-primary bg-input-background p-4 focus:outline-none focus:border-secondary"
                  style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}
                  placeholder="Enter meaning..."
                />
              </div>
            </div>
          </div>

          <button
            onClick={addWordPair}
            className="border-4 border-primary bg-primary text-primary-foreground p-4 hover:bg-secondary hover:border-secondary active:bg-accent transition-all hover:scale-105"
          >
            + Add Word
          </button>

          {/* Word List */}
          {wordPairs.length > 0 && (
            <div className="border-4 border-primary bg-card p-6">
              <h3 className="mb-4">Your Vocabulary</h3>
              <div className="space-y-3">
                {wordPairs.map((pair) => (
                  <div
                    key={pair.id}
                    className="border-2 border-primary bg-input-background p-3 flex justify-between items-start gap-3"
                  >
                    <div className="flex-1">
                      <div className="break-words">
                        <strong>{pair.word}</strong>
                      </div>
                      <div className="opacity-80">{pair.meaning}</div>
                    </div>
                    <button
                      onClick={() => removeWordPair(pair.id)}
                      className="border-2 border-primary bg-destructive text-destructive-foreground px-3 py-1 hover:scale-110 transition-transform"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Right Side - Paragraph Editor */}
        <div className="flex-1">
          <div className="border-4 border-primary bg-card p-6 h-full min-h-[600px] transition-transform hover:scale-105">
            <label className="block mb-3">Write Your Paragraph</label>
            <textarea
              value={paragraph}
              onChange={(e) => setParagraph(e.target.value)}
              className="w-full h-32 border-4 border-primary bg-input-background p-4 focus:outline-none focus:border-secondary mb-6 resize-none"
              style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}
              placeholder="Start writing... Words from your vocabulary will be highlighted!"
            />

            <div className="border-4 border-secondary bg-input-background p-6 min-h-[400px]">
              <h4 className="mb-4">Preview with Highlights</h4>
              <div className="whitespace-pre-wrap break-words leading-relaxed" style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}>
                {paragraph ? highlightWords(paragraph) : (
                  <span className="opacity-50">Your highlighted text will appear here...</span>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
