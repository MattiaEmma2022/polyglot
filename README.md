# Seam

A code-switching trainer for multilinguals. You pick between two and six languages —
French, Italian, German, Spanish, English, Romanian — and the game generates sentences
that mix them, then asks you to read, tag, complete, or repair them.

No build step, no dependencies, no network. `index.html` is the whole app.

---

## Run it

**On a phone, right now:** open `index.html` from any static host and use *Add to home
screen*. It installs as a standalone app and works offline after the first load.

**Locally:**

```bash
npm run dev          # serves at http://localhost:5173
```

A service worker is registered over `http`/`https` only, so opening the file directly
with `file://` still works — it just skips offline caching.

**GitHub Pages:** the workflow in `.github/workflows/pages.yml` deploys on every push to
`main`. Turn it on under *Settings → Pages → Source: GitHub Actions*.

---

## Turning it into an Android APK

The app is already structured for a Capacitor wrap — no code changes needed.

```bash
npm install
npx cap add android
npx cap sync android
npx cap open android      # opens Android Studio; build or run from there
```

`capacitor.config.json` sets `webDir` to the repo root, the app id to
`app.seam.polyglot`, and the splash background to match the app's ink colour. For a Play
Store release you generate a signed AAB from Android Studio (*Build → Generate Signed
Bundle*); keep the keystore out of the repo — `.gitignore` already excludes `*.keystore`.

---

## How the content engine works

Hand-writing mixed sentences does not scale: six languages taken two-to-six at a time is
57 different language sets, and each needs its own material. So the game generates
instead.

**A concept lexicon.** 31 nouns, 15 verbs, 8 adverbs, each carrying its form in all six
languages with the definite article already attached. Attaching the article at authoring
time means gender and agreement can never come out wrong, because the generator never
assembles a noun phrase itself. German objects carry an optional `acc` field so
`der Hund` becomes `den Hund` when it lands in object position.

**Semantic constraints.** Verbs declare which objects they accept (`drink` takes water,
wine, coffee) and subjects are drawn only from nouns tagged animate. That yields 539
valid subject–verb–object frames — nonsense is excluded by construction rather than
filtered afterwards.

**Language dealing.** Each slot is assigned a language from your selected set, capped by
difficulty, with a guarantee that at least two distinct languages appear. So the material
scales with the number of language sets rather than being written per set.

## The five challenge types

| Type | What it trains |
|---|---|
| **Frankensentence** | Fill gaps that each accept only one specific language. Active production under a language constraint. |
| **Tag the tongue** | Assign a language to every word in a mixed sentence. Passive recognition. |
| **Decode** | Pick the meaning of a hybrid sentence. Distractors swap exactly one element, so guessing does not survive. |
| **False friends** | 30 real traps — Italian *burro* against Spanish *burro*, Romanian *prost* against German *Prost*, German *Gift* against English *gift*. |
| **Relay** | Carry one meaning through a chain of three or four languages, one hop at a time. |

Scoring is 110–150 base points by type, plus a time bonus and a streak multiplier that
caps at ×2. The results screen breaks accuracy down per language, which is the number
that actually matters: it shows you which of your languages is quietly weakest.

## Design notes

The six language colours are the entire visual identity, so everything else stays quiet —
a deep ink background, one warm off-white, no other accent. Colour is used consistently
for the same language everywhere: in the word bank, in the sentence, in the stats bars.

The **seam ribbon** under the top bar is the signature element. One segment per word,
coloured by that word's language, so the code-switching structure of the current sentence
is legible before you read a single word.

Type is Bricolage Grotesque for display, Newsreader for the sentence content — a serif,
because the content is text to be read rather than UI to be scanned — and IBM Plex Mono
for labels and scores. Fonts load from Google Fonts and degrade to system faces offline.

## Known simplifications

Worth knowing if you extend the lexicon:

- Sentences are third person singular present, subject–verb–object, with an optional
  trailing adverb. That order stays grammatical in all six languages; adverb-initial does
  not, because German requires verb-second inversion, so it is excluded.
- German case is handled for direct objects only. Prepositional phrases would need real
  case logic.
- Romanian direct objects skip the `pe` marker, which is defensible for animals and
  inanimates but would need adding before human objects are introduced.
- No audio. Browser text-to-speech quality is too uneven across these six languages to
  ship.

## Adding a language

Add an entry to `LANGS` with a colour, add a matching `--l-xx` custom property in the CSS
token block, then add that language's form to every entry in `NOUNS`, `VERBS`, and `ADVS`.
The generator, the challenge types, and the stats screen all read from `LANGS` and need no
changes. Raising the six-language cap means editing the check in `buildSetup`.

## Layout

```
index.html                    the entire app
manifest.json                 PWA metadata
sw.js                         offline cache
capacitor.config.json         Android wrap settings
icons/                        192 / 512 / maskable
.github/workflows/pages.yml   deploy on push to main
```

## License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**.

You are free to:

- use the software for noncommercial purposes,
- study and modify the source code,
- redistribute it under the license terms.

Commercial use is **not permitted** without a separate written agreement from the copyright holder.

See the `LICENSE` file for the complete license text.

For commercial licensing, contact: mattiroma.98@gmail.com
