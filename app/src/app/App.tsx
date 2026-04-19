import { useState } from 'react';
import FeatureCard from './components/FeatureCard';
import BoostVocab from './components/BoostVocab';

export default function App() {
  const [selectedFeature, setSelectedFeature] = useState<string | null>(null);

  const features = [
    {
      id: 'boost-vocab',
      name: 'BoostVocab',
      image: 'https://images.unsplash.com/photo-1588912914017-923900a34710?w=800'
    }
  ];

  if (selectedFeature === 'boost-vocab') {
    return (
      <div className="min-h-screen bg-background">
        <div className="border-b-4 border-primary bg-card p-6">
          <button
            onClick={() => setSelectedFeature(null)}
            className="border-4 border-primary bg-primary text-primary-foreground px-6 py-3 hover:bg-secondary hover:border-secondary transition-all hover:scale-105"
          >
            ← Back to Home
          </button>
          <h1 className="mt-4">BoostVocab - Boost your vocabulary now!</h1>
        </div>
        <BoostVocab />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="max-w-7xl mx-auto">
        <div className="border-4 border-primary bg-card p-8 mb-8">
          <h1 className="text-center mb-4">Anki Data Importer</h1>
          <p className="text-center opacity-90">Choose a feature to get started!</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature) => (
            <FeatureCard
              key={feature.id}
              name={feature.name}
              image={feature.image}
              onClick={() => setSelectedFeature(feature.id)}
            />
          ))}
        </div>
      </div>
    </div>
  );
}