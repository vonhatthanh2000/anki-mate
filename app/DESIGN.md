## Design Tokens and Foundations

- **Visual Style**: Bold, geometric, vibrant with thick borders.
- **Typography**:
  - Primary Font: Limelight
  - Scales: 12pt, 14pt, 16pt, 20pt, 24pt, 32pt, 48pt
- **Color Palette**:
  - Primary: #EA580B
  - Secondary: #F59E0B
  - Background: #FFEDD5
  - Surface: #FDBA74
  - Text: #EA580C
- **Spacing Scale**: 4, 8, 12, 16, 24, 32, 48, 64
- **Borders**: Use a thick 4px border for all containers and elements.

## Component-Level Rules

### Anatomy

1. **Feature Display**:
   - Each feature (e.g., "BoostVocab") is displayed in a bold box.
   - To the left, include input boxes for "Word" and "Meaning."
   - Below, add a "+" button for adding new words.
   - On the right, add a large box for writing paragraphs with highlighted words from the left.

2. **Spacing and Alignment**:
   - Maintain consistent spacing between feature sections using the spacing scale.
   - Use thick borders to differentiate sections.

### States

- **Default**: All elements in their primary state.
- **Hover**: Slightly scale up the feature box on hover (spring animation).
- **Focus-visible**: Highlight borders with a secondary color.
- **Active**: Slightly darker background on button clicks.
- **Disabled**: Use neutral tones with reduced opacity.

### Responsive Behavior

- Ensure the layout adjusts seamlessly on different screens; input boxes should stack vertically on narrow screens.

## Accessibility Requirements and Testable Acceptance Criteria

- Ensure a minimum contrast ratio of 4.5:1 for text elements.
- All interactive elements must be keyboard navigable.
- Provide visible focus states for all focusable components.

## Content and Tone Standards

- Use punchy, dynamic, and motivating language.
- Example: "Boost your vocabulary now!" or "Add new words with a click!"

## Anti-Patterns and Prohibited Implementations

- **Do's**:
  - Use consistent thick borders (4px).
  - Maintain high contrast for text and backgrounds.
- **Don'ts**:
  - Avoid using low contrast colors.
  - Don't use thin borders or low-opacity text.

## QA Checklist

- Verify that all states (default, hover, active, disabled, focus-visible) are implemented.
- Check spacing consistency based on the spacing scale.
- Validate color usage against design tokens.
- Test accessibility criteria to ensure compliance with WCAG 2.2 AA.
