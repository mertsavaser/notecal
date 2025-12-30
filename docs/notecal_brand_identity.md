# NoteCal Brand Identity

## 1. Brand Summary

### Product Description
NoteCal is a minimalist calorie tracking application that strips away complexity to deliver what matters most: quick meal logging and clear daily insights. Built for people who want to stay mindful of their nutrition without the overwhelm of traditional tracking apps.

### Mission Statement
To make calorie awareness effortless and accessible for everyone, removing barriers between intention and action.

### Vision Statement
To become the most frictionless tool for daily nutrition awareness, empowering millions to make informed choices without sacrificing their time or mental energy.

### Value Proposition
NoteCal gets out of your way. No lengthy food databases to search, no complicated macro calculations, no guilt-inducing interfaces. Just simple logging, clear numbers, and the freedom to stay aware without obsessing.

---

## 2. Target Audience

### Primary Personas

**The Mindful Professional (Sarah, 29)**
- Works full-time in demanding role
- Wants to maintain healthy weight without dieting
- Pain points: No time for complex apps, frustrated by feature bloat
- Motivation: Stay aware without stress, build sustainable habits
- Why NoteCal: Quick logging during busy workdays, no learning curve

**The Fitness Beginner (Marcus, 24)**
- Recently started gym routine
- Needs basic calorie awareness to support fitness goals
- Pain points: Intimidated by technical nutrition apps, gives up quickly
- Motivation: Simple progress tracking, want to "just start somewhere"
- Why NoteCal: Non-intimidating entry point, focuses on consistency over perfection

**The Comeback User (Jenny, 35)**
- Tried multiple tracking apps before, quit each time
- Wants to try again with something simpler
- Pain points: App fatigue, decision paralysis from too many features
- Motivation: Find a sustainable approach this time
- Why NoteCal: Stripped-down experience that respects their past struggles

---

## 3. Core Brand Principles

### Tone & Voice
**Supportive, not prescriptive.** NoteCal speaks like a helpful friend, never a judgmental nutritionist. We use clear, direct language without jargon. Our communication assumes intelligence and respects autonomy.

### Personality Traits
- **Calm** – No urgency, no pressure, no alarmist language
- **Honest** – Transparent about what we do and don't offer
- **Efficient** – Respect users' time in every interaction
- **Encouraging** – Celebrate progress without manufacturing achievement
- **Neutral** – No moral judgment about food choices

### Brand Keywords
Minimal • Clear • Quick • Aware • Honest • Calm • Effortless • Uncluttered

---

## 4. Naming Rationale

### Why "NoteCal"
The name fuses two core actions: **Note** (quick logging) + **Cal** (calories). It suggests simplicity and speed—like jotting a note rather than completing a form.

### Emotional + Functional Meaning
- **Functional**: Directly describes what the app does
- **Emotional**: Feels light and approachable, not clinical or intimidating
- **Memorable**: Short, pronounceable, works as a verb ("I'll NoteCal that")

### Long-term Scaling
The name remains relevant as we expand beyond basic calorie tracking. "Cal" can evolve to represent broader nutrition awareness while "Note" always centers on the quick-capture experience that defines us.

---

## 5. Brand Story

NoteCal was born from a simple frustration: why is tracking calories so complicated?

After trying countless apps filled with barcode scanners, social feeds, achievement badges, and endless food databases, we realized the problem wasn't that these features existed—it was that they got in the way of the actual goal. Most people just want to stay aware of what they're eating without turning it into a second job.

So we built NoteCal around a single principle: **remove everything that isn't essential**. No lengthy onboarding quizzes. No guilt-inducing red numbers. No pressure to log every micronutrient. Just you, your daily goal, and a frictionless way to stay mindful.

Because awareness shouldn't require effort. It should just happen.

---

## 6. Visual Identity

### Primary Color Palette
**Logo-Derived Colors:**
- **Mint Green**: `#7EDAD4` – Primary brand color, start of gradient
- **Sky Blue**: `#8FC9E8` – Mid-gradient transition, trust and calm
- **Soft Pink**: `#E8A8C8` – Gradient endpoint, warmth and approachability
- **Neutral Dark**: `#3A4556` – Text and primary UI elements
- **Neutral Light**: `#F5F7FA` – Background, breathing room
- **Pure White**: `#FFFFFF` – Cards, elevated surfaces

**Primary Gradient Token:**
```css
background: linear-gradient(135deg, #7EDAD4 0%, #8FC9E8 50%, #E8A8C8 100%);
```

### Secondary Palette
**Pastel Support Colors:**
- **Soft Green**: `#A8E6CF` – Under goal, positive feedback (pastel tone)
- **Soft Amber**: `#FFD8A8` – Approaching limit, gentle alert
- **Soft Coral**: `#FFABAB` – Over goal (used sparingly, stays gentle)
- **Mist Gray**: `#E8ECEF` – Subtle backgrounds, dividers
- **Cloud Gray**: `#B8C5D0` – Placeholders, disabled states
- **Slate Text**: `#6B7B8C` – Secondary text, captions

### Typography
**Primary Font**: **Quicksand** (Google Fonts)
- Usage: Headings (H1-H3), buttons, navigation
- Weights: Regular (400), Medium (500), SemiBold (600)
- Rounded, friendly, matches logo's soft aesthetic

**Secondary Font**: **Inter** (Google Fonts)
- Usage: Body text, descriptions, captions, input fields
- Weights: Regular (400), Medium (500)
- Clean readability for extended reading

**Typography Rules:**
- **H1**: Quicksand SemiBold, 28px, letter-spacing -0.5px
- **H2**: Quicksand SemiBold, 22px, letter-spacing -0.3px
- **H3**: Quicksand Medium, 18px
- **Body**: Inter Regular, 16px, line-height 1.5
- **Caption**: Inter Regular, 14px, color: Slate Text
- **Button Text**: Quicksand Medium, 16px

### Iconography Style
- **Style**: Soft rounded icons with 2.5px stroke weight
- **Line caps**: Rounded for continuity with logo
- **Fill**: None (outlined only), except for active states
- **Active states**: Subtle pastel fill with gradient overlay option
- **Icon library**: Use Lucide icons with custom rounding
- **Examples**: Rounded plate, soft plus sign, gentle checkmark

### Component Style Guidelines

**Button Styles:**
- **Primary Button**: 
  - Background: Primary gradient (mint → blue → pink)
  - Text: White, Quicksand Medium
  - Border radius: 16px (softer than before)
  - Padding: 16px horizontal, 14px vertical
  - Shadow: `0px 4px 12px rgba(126, 218, 212, 0.25)`
  
- **Secondary Button**:
  - Background: White
  - Border: 2px solid Mint Green
  - Text: Mint Green, Quicksand Medium
  - Border radius: 16px
  - Shadow: `0px 2px 8px rgba(0, 0, 0, 0.04)`

- **Tertiary/Ghost Button**:
  - Background: Transparent
  - Text: Sky Blue
  - No border, no shadow
  - Hover: Mist Gray background

**Card Styles:**
- Border radius: 20px (increased for softer feel)
- Background: White
- Shadow: `0px 4px 16px rgba(0, 0, 0, 0.06)`
- Padding: 20px
- Optional: Subtle gradient border overlay

**Input Fields:**
- Border radius: 12px
- Background: Mist Gray
- Border: None (focus state: 2px Sky Blue)
- Height: 52px
- Padding: 16px
- Placeholder: Cloud Gray

**Spacing & Layout:**
- **Base unit**: 8px (unchanged)
- **Corner radius standard**: 20px (cards), 16px (buttons), 12px (inputs)
- **Shadow system**: 
  - Light: `0px 2px 8px rgba(0, 0, 0, 0.04)`
  - Medium: `0px 4px 16px rgba(0, 0, 0, 0.06)`
  - Heavy: `0px 8px 24px rgba(0, 0, 0, 0.08)`

### Gradient Tokens

**1. Primary App Gradient** (Hero sections, premium features)
```css
background: linear-gradient(135deg, #7EDAD4 0%, #8FC9E8 50%, #E8A8C8 100%);
```

**2. Background Gradient** (Onboarding, empty states)
```css
background: linear-gradient(180deg, #F5F7FA 0%, #E8F4F8 100%);
```

**3. Accent Gradient** (Progress bars, highlights)
```css
background: linear-gradient(90deg, #7EDAD4 0%, #8FC9E8 100%);
```

**4. Subtle Overlay Gradient** (Card borders, glass effects)
```css
background: linear-gradient(135deg, rgba(126, 218, 212, 0.1) 0%, rgba(232, 168, 200, 0.1) 100%);
```

### Illustration & Iconography Guidelines

**Visual Style:**
- **Illustration tone**: Soft, pastel, minimal
- **Line weight**: 2-3px, rounded caps and joins
- **Color usage**: 2-3 colors max per illustration, drawn from primary palette
- **Shading**: Subtle gradient fills, avoid hard shadows
- **Composition**: Lots of negative space, floating elements

**Onboarding Illustrations:**
- Use Mint Green and Sky Blue as primary colors
- Add Soft Pink as accent sparingly
- Style: Line art with optional pastel fills
- Examples: Simple plate outlines, floating food items, gentle progress indicators

**Icon Treatment:**
- Default: Outlined in Neutral Dark
- Active: Filled with Accent Gradient or solid Mint Green
- Hover: Scale 1.05x with subtle glow effect

**Micro-interactions:**
- Success states: Gentle bounce + Soft Green tint
- Completion: Confetti particles in pastel palette
- Loading: Rotating gradient arc, not harsh spinner

### Usage Examples

**Onboarding Screens:**
- Background: Background Gradient (light blue wash)
- Illustration: Mint Green + Sky Blue line art
- Heading: Neutral Dark, Quicksand SemiBold
- Body: Slate Text, Inter Regular
- Primary CTA: Primary App Gradient button

**Authentication:**
- Background: Pure White
- Input fields: Mist Gray background, 12px radius
- Primary button: Gradient with soft shadow
- Links: Sky Blue, Quicksand Medium

**Home Dashboard:**
- Background: Neutral Light
- Cards: White with 20px radius, medium shadow
- Progress ring: Accent Gradient
- Add button: Floating, gradient background, heavy shadow

**Daily Summary Card:**
- Background: White
- Header: Gradient text effect (optional) or Neutral Dark
- Progress bar: Accent Gradient fill
- Stats: Slate Text for labels, Neutral Dark for numbers

**Empty States:**
- Background: Background Gradient
- Illustration: Pastel line art
- Message: Slate Text
- CTA: Primary gradient button

**Success/Feedback:**
- Toast background: Soft Green with subtle glow
- Icon: Checkmark with gentle bounce
- Text: Neutral Dark

### App Logo Implementation
**Current Logo**: 
- Rounded square icon (20px corner radius)
- Gradient background: Mint → Blue → Pink
- White monoline "N" with circular dot accent
- Soft shadow: `0px 8px 24px rgba(126, 218, 212, 0.3)`

**Wordmark Usage**:
- "NoteCal" in Quicksand SemiBold
- Optional: "Note" in Mint Green, "Cal" in Sky Blue
- Can be used with or without icon
- Minimum clear space: 16px all sides

---

## 7. Onboarding Messaging

### Slide 1
**Welcome to Simple Tracking**  
NoteCal helps you stay aware of your calories without the complexity.

### Slide 2
**Log in Seconds**  
Add meals with just a name and calorie count—that's it.

### Slide 3
**See Your Day Clearly**  
Your daily total updates instantly, with zero judgment.

### Slide 4
**Stay Consistent, Not Perfect**  
Track what you can, when you can—we'll handle the rest.

---

## 8. UI/UX Guidelines

### Button Styles
- **Primary Action**: Solid Primary Blue background, white text, 12px radius
- **Secondary Action**: White background, Primary Blue border (2px), Primary Blue text
- **Destructive Action**: Soft Red background, white text (use sparingly)
- **Height**: 48px minimum for touch targets
- **Padding**: 16px horizontal, 12px vertical

### Spacing Rules
- **Base unit**: 8px
- **Micro spacing**: 8px (between related elements)
- **Small spacing**: 16px (between UI groups)
- **Medium spacing**: 24px (between sections)
- **Large spacing**: 40px (between major content blocks)

### Component Radius
- **Buttons**: 12px
- **Input fields**: 8px
- **Cards**: 16px
- **Modals**: 20px (top corners only on mobile)

### Layout Do's and Don'ts

**Do:**
- Use cards to group related information
- Maintain consistent margins (16px screen edge)
- Stack vertically on mobile (single column)
- Let content breathe with adequate spacing
- Use clear visual hierarchy through size and weight

**Don't:**
- Use more than 2 typeface weights per screen
- Place interactive elements closer than 8px apart
- Use pure black (`#000000`) for text
- Create boxes within boxes (avoid nested borders)
- Center-align body text or long-form content

### Accessibility Considerations
- **Contrast ratio**: 4.5:1 minimum for all text
- **Touch targets**: 48x48px minimum
- **Font size**: 16px minimum for body text
- **Color independence**: Never rely solely on color to convey meaning
- **VoiceOver support**: All interactive elements properly labeled

---

## 9. Feature Scope (MVP)

### Included in v1.0
- Quick meal logging (name + calories)
- Custom daily calorie goal setting
- Real-time daily total with visual progress
- Simple history view (last 7 days)
- Edit/delete logged meals
- Local data persistence
- Basic app settings (goal adjustment, theme toggle)

### Explicitly NOT Included in v1
- Barcode scanning
- Food database/search
- Macro tracking (protein, carbs, fat)
- Exercise logging
- Social features or sharing
- Meal photos
- Recipe storage
- Streak tracking or gamification
- Multiple users/accounts
- Cloud sync (coming in v1.1)

---

## 10. Future Expansion Possibilities

### Phase 2 (Post-MVP)
- **Cloud Sync**: Data backup and cross-device access
- **Quick Add Presets**: Save frequently logged meals for one-tap entry
- **Weekly Insights**: Average daily intake, consistency trends

### Phase 3 (Growth)
- **AI Meal Recognition**: Photo-to-calorie estimation
- **Macro Breakdown**: Optional protein/carb/fat tracking for interested users
- **Meal Templates**: Pre-built common meals for faster logging

### Phase 4 (Maturity)
- **Social Features**: Optional meal sharing with friends
- **Streaks & Gamification**: Gentle encouragement for consistency
- **Integration**: HealthKit, Apple Watch, wearables
- **Premium Features**: Advanced analytics, custom reports, nutrition coaching

---

## 11. Brand Taglines (5 Options)

1. **Note it. Know it.**
2. **Calorie awareness, simplified.**
3. **Track less. Know more.**
4. **Simple logging. Clear insights.**
5. **Your calories, made clear.**

---

## 12. App Store Description

### Short Version (100 characters)
Track your daily calories in seconds. No complexity, no judgment—just simple, clear nutrition awareness.

### Long Version (350 characters)
NoteCal strips calorie tracking down to what matters: quick meal logging and clear daily totals. No food databases to search, no macros to calculate, no guilt-inducing interfaces. Just enter what you ate, see your progress, and stay aware without the overwhelm. Perfect for anyone who wants to be mindful of their nutrition without turning tracking into a full-time job. Simple. Honest. Effective.

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Owner**: Brand Strategy & Product Design