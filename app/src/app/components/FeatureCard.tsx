interface FeatureCardProps {
  name: string;
  image: string;
  onClick: () => void;
}

export default function FeatureCard({ name, image, onClick }: FeatureCardProps) {
  return (
    <button
      onClick={onClick}
      className="border-4 border-primary bg-card p-8 transition-all hover:scale-105 active:scale-95 focus-visible:border-secondary w-full"
    >
      <div className="mb-6">
        <img
          src={image}
          alt={name}
          className="w-full h-48 object-cover border-4 border-primary"
        />
      </div>
      <h2 className="text-center">{name}</h2>
    </button>
  );
}
